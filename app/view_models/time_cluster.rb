class TimeCluster

  attr_reader :drop_display

  def initialize(finish, split_times_data, prior_time, start_time, drop_display = false)
    @finish = finish
    @split_times_data = split_times_data
    @prior_time = prior_time
    @start_time = start_time
    @drop_display = drop_display
  end

  def finish?
    @finish
  end

  def aid_time_recordable?
    times_from_start.count > 1
  end

  def segment_time
    @segment_time ||=
        times_from_start.compact.first - prior_time if (prior_time && (times_from_start.compact.present?))
  end

  def time_in_aid
    @time_in_aid ||=
        times_from_start.compact.last - times_from_start.compact.first if times_from_start.compact.size > 1
  end

  def times_from_start
    @times_from_start ||= split_times_data.map { |st| st && st[:time_from_start] }
  end

  def days_and_times
    @days_and_times ||= times_from_start.map { |time| time && (start_time + time.seconds) }
  end

  def time_data_statuses
    @time_data_statuses ||= split_times_data.map { |st| st && SplitTime.data_statuses.key(st[:data_status]) }
  end

  def split_time_ids
    @split_time_ids ||= split_times_data.map { |st| st && st[:id] }
  end

  def stopped_here_flags
    @stopped_here_flags ||= split_times_data.map { |st| st && st[:stopped_here] }
  end

  private

  attr_reader :split, :split_times_data, :start_time, :prior_time
end