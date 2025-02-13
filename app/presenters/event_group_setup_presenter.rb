# frozen_string_literal: true

class EventGroupSetupPresenter < BasePresenter
  CANDIDATE_SEPARATION_LIMIT = 7.days

  attr_reader :event_group
  delegate :available_live?,
           :concealed?,
           :first_event,
           :multiple_events?,
           :name,
           :organization,
           :partners,
           :to_param,
           :unreconciled_efforts,
           to: :event_group

  def initialize(event_group, params, current_user)
    @event_group = event_group
    @params = params
    @current_user = current_user
  end

  def authorized_fully?
    @authorized_fully ||= current_user.authorized_fully?(event_group)
  end

  def available_courses
    organization.courses
  end

  def candidate_events
    return [] unless events.present?

    (organization.events.select_with_params("").order(scheduled_start_time: :desc) - events)
      .select { |event| (event.scheduled_start_time - events.first.scheduled_start_time).abs < CANDIDATE_SEPARATION_LIMIT }
  end

  def courses
    events.map(&:course).uniq
  end

  def display_style
    params[:display_style].presence || default_display_style
  end

  def event_group_efforts
    event_group.efforts.includes(:event)
  end

  def event_group_efforts_count
    @event_group_efforts_count ||= event_group_efforts.count
  end

  def filtered_efforts
    @filtered_efforts ||= event_group_efforts
                            .where(filter_hash)
                            .search(search_text)
                            .order(sort_hash.presence || {bib_number: :asc})
                            .paginate(page: page, per_page: per_page)
  end

  def event_group_name
    event_group.name
  end

  def event_group_names
    events.map(&:name).to_sentence(two_words_connector: " and ", last_word_connector: ", and ")
  end

  def events
    @events ||= event_group.events.order(:scheduled_start_time)
  end

  def organization_name
    organization.name
  end

  def status
    available_live? ? "live" : "not_live"
  end

  private

  attr_reader :params, :current_user

  def default_display_style
    "events"
  end
end
