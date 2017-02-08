class EffortAnalysisView

  attr_reader :effort, :analysis_rows
  delegate :full_name, :event_name, :participant, :bib_number, :finish_status, :gender,
           :overall_place, :gender_place, to: :effort

  def initialize(args_effort)
    @effort = args_effort.enriched || args_effort
    @analysis_rows = []
    create_analysis_rows
  end

  def total_segment_time
    analysis_rows.sum(&:segment_time)
  end

  def total_segment_time_typical
    typical_effort.total_segment_time
  end

  def total_segment_time_over_under
    analysis_rows.sum(&:segment_time_over_under)
  end

  def total_time_in_aid
    analysis_rows.sum(&:time_in_aid)
  end

  def total_time_in_aid_typical
    typical_effort.total_time_in_aid
  end

  def total_time_in_aid_over_under
    analysis_rows.sum(&:time_in_aid_over_under)
  end

  def total_time_combined
    (total_segment_time && total_time_in_aid) ? total_segment_time + total_time_in_aid : nil
  end

  def total_combined_time_over_under
    total_segment_time_over_under + total_time_in_aid_over_under
  end

  def typical_finish_tfs
    typical_effort.finish_time_from_start
  end

  def best_segments
    segment_count = [((sorted_analysis_rows.size / 2.0)).round(0), 3].min
    sorted_analysis_rows.first(segment_count).map(&:segment_name).join(', ')
  end

  def worst_segments
    segment_count = [(sorted_analysis_rows.size / 2), 3].min
    sorted_analysis_rows.reverse.first(segment_count).map(&:segment_name).join(', ')
  end

  def farthest_recorded_time
    effort.final_time
  end

  def farthest_recorded_split_name
    effort.final_split_name
  end

  def event
    @event ||= effort.event
  end

  private

  attr_accessor :indexed_analysis_rows

  def typical_effort
    @typical_effort ||= mock_finish_time && MockEffort.new(lap_splits: lap_splits,
                                                           expected_time: mock_finish_time,
                                                           start_time: effort_start_time,
                                                           show_laps: event.multiple_laps?)
  end

  def indexed_typical_rows
    @indexed_typical_rows ||= typical_effort.lap_split_rows.index_by(&:key)
  end

  def mock_finish_time
    effort_finish_tfs || focused_predicted_time || stats_predicted_time
  end

  def focused_predicted_time
    TimePredictor.segment_time(segment: start_to_finish, effort: effort, lap_splits: lap_splits,
                               calc_model: :focused, similar_effort_ids: similar_effort_ids)
  end

  def stats_predicted_time
    TimePredictor.segment_time(segment: start_to_finish, effort: effort, lap_splits: lap_splits,
                               calc_model: :stats)
  end

  def similar_effort_ids
    @similar_effort_ids ||= SimilarEffortFinder.new(split_time: ordered_split_times.last).effort_ids
  end

  def create_analysis_rows
    return unless typical_effort.lap_split_rows.present?
    prior_split_time = related_split_times(lap_splits.first).first
    prior_lap_split = lap_splits.first
    lap_splits.each do |lap_split|
      next if lap_split.start?
      analysis_row = EffortAnalysisRow.new(lap_split: lap_split,
                                           split_times: related_split_times(lap_split),
                                           prior_lap_split: prior_lap_split,
                                           prior_split_time: prior_split_time,
                                           start_time: effort_start_time,
                                           typical_row: indexed_typical_rows[lap_split.key],
                                           show_laps: event.multiple_laps?)
      analysis_rows << analysis_row
      prior_split_time = analysis_row.split_times.compact.last if analysis_row.split_times.compact.present?
      prior_lap_split = lap_splits.find { |lap_split| lap_split.key == prior_split_time.lap_split_key }
    end
    self.indexed_analysis_rows = analysis_rows.index_by(&:key)
  end

  def related_split_times(lap_split)
    lap_split.time_points.map { |time_point| indexed_split_times[time_point] }
  end

  def effort_start_time
    effort.event_start_time + effort.start_offset
  end

  def effort_finish_tfs
    indexed_split_times[finish_time_point].try(:time_from_start)
  end

  def finish_time_point
    lap_splits.last.time_point_in
  end

  def start_time_point
    lap_splits.first.time_point_in
  end

  def start_to_finish
    Segment.new(begin_point: start_time_point, end_point: finish_time_point)
  end

  def sorted_analysis_rows
    analysis_rows.select(&:segment_over_under_percent).sort_by(&:segment_over_under_percent)
  end

  def course
    @course ||= event.course
  end

  def ordered_split_times
    @ordered_split_times ||= effort.ordered_split_times.to_a
  end

  def indexed_split_times
    @indexed_split_times ||= ordered_split_times.index_by(&:time_point)
  end

  def lap_splits
    @lap_splits ||= event.required_lap_splits.presence || event.lap_splits_through(last_lap)
  end

  def last_lap
    ordered_split_times.last.lap
  end
end