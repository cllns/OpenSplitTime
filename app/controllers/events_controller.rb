# frozen_string_literal: true

class EventsController < ApplicationController
  before_action :authenticate_user!, except: [:show, :spread, :summary, :podium]
  before_action :set_event, except: [:new, :edit, :create, :update, :destroy]
  before_action :set_event_group, only: [:new, :create]
  before_action :set_event_group_and_event, only: [:edit, :update, :destroy]
  before_action :redirect_to_friendly, only: [:podium, :spread, :summary]
  after_action :verify_authorized, except: [:show, :spread, :summary, :podium]

  MAX_SUMMARY_EFFORTS = 1000
  FINISHERS_ONLY_EXPORT_FORMATS = [:finishers, :itra].freeze

  def show
    redirect_to :spread_event
  end

  def new
    course = params[:course_id].present? ? @event_group.organization.courses.friendly.find(params[:course_id]) : nil
    @event = @event_group.events.new(
      course: course,
      laps_required: 1,
      results_template: ::ResultsTemplate.default
    )
    # Scheduled start time has to be set separately otherwise home_time_zone
    # delegation does not work
    @event.scheduled_start_time_local = @event_group.scheduled_start_time_local || (7.days.from_now.in_time_zone(@event.home_time_zone).midnight + 6.hours)
    authorize @event

    @presenter = ::EventSetupPresenter.new(@event, params, current_user)
  end

  def edit
    authorize @event
    @presenter = ::EventSetupPresenter.new(@event, params, current_user)
  end

  def create
    @event = @event_group.events.new
    @event.assign_attributes(permitted_params)
    authorize @event

    if @event.save
      redirect_to setup_event_group_path(@event_group)
    else
      @presenter = ::EventSetupPresenter.new(@event, params, current_user)
      render "new"
    end
  end

  def update
    authorize @event

    if @event.update(permitted_params)
      redirect_to setup_event_group_path(@event_group)
    else
      @presenter = ::EventSetupPresenter.new(@event, params, current_user)
      render "edit"
    end
  end

  def destroy
    authorize @event
    @event.destroy

    redirect_to setup_event_group_path(@event_group)
  end

  def reassign
    authorize @event
    @event.assign_attributes(params.require(:event).permit(:event_group_id))
    redirect_id = @event.event_group_id || @event.changed_attributes["event_group_id"]

    response = Interactors::UpdateEventAndGrouping.perform!(@event)
    set_flash_message(response) unless response.successful?

    redirect_to setup_event_group_path(redirect_id)
  end

  # Special views with results

  def spread
    @presenter = EventSpreadDisplay.new(event: @event, params: prepared_params, current_user: current_user)
    respond_to do |format|
      format.html
      format.csv do
        authorize @event
        csv_stream = render_to_string(partial: "spread", formats: :csv)
        send_data(csv_stream, type: "text/csv",
                              filename: "#{@event.name}-#{@presenter.display_style}-#{Date.today}.csv")
      end
    end
  end

  def summary
    event = Event.where(id: @event.id).includes(:course, :splits, event_group: :organization).references(:course, :splits, event_group: :organization).first
    params[:per_page] ||= MAX_SUMMARY_EFFORTS
    @presenter = SummaryPresenter.new(event: event, params: prepared_params, current_user: current_user)
  end

  def podium
    template = Results::FillEventTemplate.perform(@event)
    @presenter = PodiumPresenter.new(@event, template, prepared_params, current_user)
  end

  # Event admin actions

  def delete_all_efforts
    authorize @event
    response = Interactors::BulkDestroyEfforts.perform!(@event.efforts)
    set_flash_message(response) unless response.successful?
    redirect_to case request.referrer
                when nil
                  event_staging_app_path(@event)
                when event_staging_app_url(@event)
                  request.referrer + "#/entrants"
                else
                  request.referrer
                end
  end

  # Actions related to the event/effort/split_time relationship

  def set_stops
    authorize @event
    event = Event.where(id: @event.id).includes(efforts: {split_times: :split}).first
    stop_status = params[:stop_status].blank? ? true : params[:stop_status].to_boolean
    response = Interactors::UpdateEffortsStop.perform!(event.efforts, stop_status: stop_status)
    set_flash_message(response)
    redirect_to setup_event_group_path(@event.event_group)
  end

  # This action updates the event scheduled start time and adjusts absolute time on all
  # existing split_times to keep elapsed times consistent.
  def edit_start_time
    authorize @event
  end

  def update_start_time
    authorize @event

    @event.assign_attributes(permitted_params)

    if @event.valid?
      new_start_time = @event.scheduled_start_time_local.to_s
      @event.reload
      response = EventUpdateStartTimeJob.perform_now(@event, new_start_time: new_start_time, current_user: current_user)
      set_flash_message(response)
      redirect_to setup_event_group_path(@event.event_group)
    else
      render :edit_start_time
    end
  end

  def export
    authorize @event
    params[:per_page] = @event.efforts.size # Get all efforts without pagination
    @presenter = ::EventWithEffortsPresenter.new(event: @event, params: prepared_params)
    respond_to do |format|
      format.csv do
        options = {}
        options[:event_finished] = @presenter.event_finished?

        export_format = params[:export_format].to_sym
        current_time = Time.current.in_time_zone(@event.home_time_zone)
        records = @presenter.ranked_effort_rows
        records = records.select(&:finished?) if export_format.in?(FINISHERS_ONLY_EXPORT_FORMATS)
        filename = "#{@presenter.name}-#{export_format}-#{current_time.iso8601}.csv"
        partial = lookup_context.exists?(export_format, :events, true) ? export_format.to_s : "not_found"

        csv_stream = render_to_string(
          partial: partial,
          formats: :csv,
          locals: {current_time: current_time, records: records, options: options}
        )

        send_data(csv_stream, type: "text/csv", filename: filename)
      end
    end
  end

  private

  def reconcile_redirect_path
    "#{event_staging_app_path(@event)}#/entrants"
  end

  def set_event
    @event = policy_scope(Event).friendly.find(params[:id])
  end

  def set_event_group
    @event_group = EventGroup.friendly.find(params[:event_group_id])
  end

  def set_event_group_and_event
    @event_group = ::EventGroup.friendly.find(params[:event_group_id])
    @event = @event_group.events.friendly.find(params[:id])
  end

  def redirect_to_friendly
    redirect_numeric_to_friendly(@event, params[:id])
  end
end
