require 'ice_cube'
require 'active_support'
require 'active_support/time_with_zone'
require 'ostruct'
require 'time'

module ScheduleAtts
  
  attr_accessor :schedule_data
  
  DAY_NAMES = Date::DAYNAMES.map(&:downcase).map(&:to_sym)
  def schedule
    @schedule ||= begin
      if schedule_data.blank?
        IceCube::Schedule.new(Date.today.to_time).tap{|sched| sched.add_recurrence_rule(IceCube::Rule.daily) }
      else
        Marshal::load(schedule_data)
      end
    end
  end

  def schedule_attributes=(options)
    options = options.dup
    options[:interval] = options[:interval].to_i
    options[:duration] = options[:duration].to_i if options.has_key?(:duration)
    options[:start_date] = ScheduleAttributes.parse_in_timezone(options[:start_date]) unless options[:start_date].is_a?(Time) 
    options[:end_date]   = ScheduleAttributes.parse_in_timezone(options[:end_date]) unless options[:end_date].is_a?(Time) 
    
    @schedule = IceCube::Schedule.new(options[:start_date])
    @schedule.end_time = options[:end_date]
    if options[:repeat].to_i == 0
      @schedule.add_recurrence_date(options[:start_date])
    else
      rule = case options[:interval_unit]
        when 'day'
          IceCube::Rule.daily options[:interval]
        when 'week'
          IceCube::Rule.weekly(options[:interval]).day( *IceCube::DAYS.keys.select{|day| options[day].to_i == 1 } )
      end

      @schedule.add_recurrence_rule(rule)
    end

    self.schedule_data = Marshal::dump(@schedule)
  end

  def schedule_attributes
    atts = {}

    if rule = schedule.rrules.first
      atts[:repeat]       = 1
      atts[:start_date]   = schedule.start_date
      atts[:end_date]     = schedule.end_date
      atts[:duration]     = schedule.duration

      rule_hash = rule.to_hash
      atts[:interval] = rule_hash[:interval]

      case rule
      when IceCube::DailyRule
        atts[:interval_unit] = 'day'
      when IceCube::WeeklyRule
        atts[:interval_unit] = 'week'
        rule_hash[:validations][:day].each do |day_idx|
          atts[ DAY_NAMES[day_idx] ] = 1
        end
      end

    else
      atts[:repeat]     = 0
      atts[:start_date] = schedule.start_date # for populating the other part of the form
      atts[:duration]     = schedule.duration
    end

    OpenStruct.new(atts)
  end

  # TODO: test this
  def self.parse_in_timezone(str)
    if Time.respond_to? :zone
      Time.zone.parse(str)
    else
      Time.parse(str)
    end
  end
end

# TODO: we shouldn't need this
ScheduleAttributes = ScheduleAtts

#TODO: this should be merged into ice_cube, or at least, make a pull request or something.
class IceCube::Rule
  def ==(other)
    to_hash == other.to_hash
  end
end

class IceCube::Schedule
  def ==(other)
    to_hash == other.to_hash
  end
end

