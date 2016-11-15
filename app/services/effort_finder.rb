class EffortFinder

  def initialize(sub_split, time_from_start, options = {})
    @sub_split = sub_split
    @time_from_start = time_from_start
    @split = options[:split] || Split.find(sub_split.split_id)
    @course = options[:course] || split.course
    @minimum_efforts = options[:minimum_efforts] || 20
    @maximum_efforts = options[:maximum_efforts] || 200
    validate_finder
  end

  def efforts
    @efforts ||= Effort.where(id: effort_ids).limit(maximum_efforts)
  end

  def events
    @events ||= Event.where(id: efforts.pluck(:event_id).uniq)
  end

  private

  attr_reader :sub_split, :time_from_start, :split, :course, :minimum_efforts, :maximum_efforts

  FACTOR_PAIRS = [0.05, 0.10, 0.15, 0.20, 0.25, 0.30].map { |step| [1 - step, 1 + step] }

  def time_ranges
    FACTOR_PAIRS.map { |low_factor, high_factor| [time_from_start * low_factor, time_from_start * high_factor] }
  end

  def effort_ids
    relevant_split_times.map(&:effort_id)
  end

  def relevant_split_times
    split_time_groups.find { |group| group.count > minimum_efforts } || split_time_groups.last
  end

  def split_time_groups
    time_ranges.map { |low_time, high_time| times_within_range(high_time, low_time) }
  end

  def times_within_range(high_time, low_time)
    possible_split_times.select { |split_time| (low_time..high_time).include? split_time.time_from_start }
  end

  def possible_split_times
    @possible_split_times ||= SplitTime.valid_status.where(split: split, bitkey: sub_split.bitkey).within_time_range(low_time, high_time).to_a
  end

  def low_time
    time_from_start * FACTOR_PAIRS.last.first
  end

  def high_time
    time_from_start * FACTOR_PAIRS.last.last
  end

  def validate_finder
    raise 'Provided sub_split is not contained within the provided split' if split.id != sub_split.split_id
    raise 'Provided split is not on the provided course' if split.course_id != course.id
  end
end