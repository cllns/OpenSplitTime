# frozen_string_literal: true

module Interactors
  class MatchAndUnmatchRawTimes
    include Interactors::Errors
    include Discrepancy

    def self.perform!(args)
      new(args).perform!
    end

    def initialize(args)
      ArgsValidator.validate(params: args, required: [:split_time, :raw_time], exclusive: [:split_time, :raw_time], class: self.class)
      @split_time = args[:split_time]
      @raw_time = args[:raw_time]
      @errors = []
      validate_setup
    end

    def perform!
      if errors.present?
        Interactors::Response.new(errors, "Raw times could not be matched. ", {})
      else
        match_raw_time
        unmatch_conflicting_raw_times
      end
    end

    private

    attr_reader :split_time, :raw_time, :errors

    def match_raw_time
      raw_time.update(split_time_id: split_time.id)
    end

    def unmatch_conflicting_raw_times
      other_raw_times = RawTime.where(split_time_id: split_time.id).where.not(id: raw_time.id)
      conflicting_raw_times = other_raw_times.select do |rt|
        if rt.absolute_time.present?
          (rt.absolute_time - split_absolute_time).abs > DISCREPANCY_THRESHOLD
        else
          TimeConversion.hms_to_seconds(rt.military_time) - TimeConversion.hms_to_seconds(split_time.military_time)
        end
      end

      conflicting_raw_times.each { |rt| rt.update(split_time_id: nil) }
    end

    def split_absolute_time
      split_time.absolute_time
    end

    def split_military_time
      @split_military_time ||= split_time.military_time
    end

    def validate_setup
      errors << event_group_mismatch_error(split_time, raw_time) unless split_time.effort.event.event_group_id == raw_time.event_group_id
    end
  end
end
