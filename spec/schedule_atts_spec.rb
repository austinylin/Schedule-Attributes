require 'spec_helper'

require 'support/scheduled_model'
require 'facets/date'

describe ScheduledModel do
  describe "#schedule" do
    context "when initialized" do
      subject{ ScheduledModel.new.schedule }
      it "the schedule should be for every day" do
        subject.should be_a(IceCube::Schedule)
        subject.rdates.should == []
        subject.start_date.should == Date.today.to_time
        subject.start_date.should be_a(Time)
        subject.end_date.should == nil
        subject.rrules.should == [IceCube::Rule.daily]
      end
    end
  end

  describe "#schedule_attributes" do
    describe "=" do
      describe "setting the correct schedule" do
        let(:scheduled_model){ ScheduledModel.new.tap{|m| m.schedule_attributes = schedule_attributes} }
        subject{ scheduled_model.schedule }
        context "given :interval_unit=>none" do
          let(:schedule_attributes){ { :repeat => '0', :start_date => '1-1-1985', :interval => '5 (ignore this)' } }
          its(:start_date){ should == Date.new(1985, 1, 1).to_time }
          its(:all_occurrences){ should == [Date.new(1985, 1, 1).to_time] }
          its(:rrules){ should be_blank }
        end

        context "given :interval_unit=>day" do
          let(:schedule_attributes){ { :repeat => '1', :start_date => '1-1-1985', :interval_unit => 'day', :interval => '3' } }
          its(:start_date){ should == Date.new(1985, 1, 1).to_time }
          its(:rrules){ should == [IceCube::Rule.daily(3)] }
          it{ subject.first(3).should == [Date.civil(1985, 1, 1), Date.civil(1985, 1, 4), Date.civil(1985, 1, 7)].map(&:to_time) }
        end

        context "given :interval_unit=>day & :end_date" do
          let(:schedule_attributes){ { :repeat => '1', :start_date => '1-1-1985', :interval_unit => 'day', :interval => '3', :end_date => '29-12-1985'} }
          its(:start_date){ should == Date.new(1985, 1, 1).to_time }
          its(:end_date){ should == Date.new(1985, 12, 29).to_time}
          its(:rrules){ should == [ IceCube::Rule.daily(3) ] }
          it{ subject.first(3).should == [Date.civil(1985, 1, 1), Date.civil(1985, 1, 4), Date.civil(1985, 1, 7)].map(&:to_time) }
        end

        context "given :interval_unit=>day" do
          let(:schedule_attributes){ { :repeat => '1', :start_date => '1-1-1985', :interval_unit => 'day', :interval => '3'} }
          its(:start_date){ should == Date.new(1985, 1, 1).to_time }
          its(:rrules){ should == [IceCube::Rule.daily(3)] }
          it{ subject.first(3).should == [Date.civil(1985, 1, 1), Date.civil(1985, 1, 4), Date.civil(1985, 1, 7)].map(&:to_time) }
        end

        context "given :interval_unit=>week & :mon,:wed,:fri" do
          let(:schedule_attributes){ { :repeat => '1', :start_date => '1-1-1985', :interval_unit => 'week', :interval => '3', :monday => '1', :wednesday => '1', :friday => '1' } }
          its(:start_date){ should == Date.new(1985, 1, 1).to_time }
          its(:rrules){ should == [IceCube::Rule.weekly(3).day(:monday, :wednesday, :friday)] }
          it { subject.occurs_at?(ScheduleAttributes.parse_in_timezone('1985-1-2')).should be_true }
          it { subject.occurs_at?(ScheduleAttributes.parse_in_timezone('1985-1-4')).should be_true }
          it { subject.occurs_at?(ScheduleAttributes.parse_in_timezone('1985-1-7')).should be_false }
          it { subject.occurs_at?(ScheduleAttributes.parse_in_timezone('1985-1-21')).should be_true }
        end
      end

      context "setting the schedule_data column" do
        let(:scheduled_model){ ScheduledModel.new.tap{|m| m.schedule_attributes = { :repeat => '1', :start_date => '1-1-1985', :interval_unit => 'day', :interval => '3' }} }
        subject{ scheduled_model }
        let(:expected_schedule){ Marshal::load(scheduled_model.schedule_data) }
        its(:schedule_data){ should == Marshal::dump(scheduled_model.schedule) }
        its(:schedule){ should == expected_schedule }
      end
    end


    describe "providing the correct attributes" do
      require 'ostruct'

      let(:scheduled_model){ ScheduledModel.new }
      subject{ scheduled_model.schedule_attributes }
      before{ scheduled_model.stub(:schedule => schedule) }
      let(:schedule){ IceCube::Schedule.new(Date.tomorrow.to_time) }

      context "when it's a 1-time thing" do
        before{ schedule.add_recurrence_date(Date.tomorrow.to_time) }
        it{ should == OpenStruct.new(:repeat => 0, :start_date => Date.tomorrow.to_time, :duration => nil) }
        its(:start_date){ should be_a(Time) }
      end

      context "when it repeats daily" do
        before do
          schedule.add_recurrence_rule(IceCube::Rule.daily(4))
        end
        it{ should == OpenStruct.new(:repeat => 1, :start_date => Date.tomorrow.to_time, :interval_unit => 'day', :interval => 4, :end_date => nil, :duration => nil) }
        its(:start_date){ should be_a(Time) }
      end

      context "when it repeats with an end date" do
        before do
          schedule.add_recurrence_rule(IceCube::Rule.daily(4))
          schedule.end_time = (Date.today+10).to_time
        end
        it{ should == OpenStruct.new(:repeat => 1, :start_date => Date.tomorrow.to_time, :interval_unit => 'day', :interval => 4, :end_date => (Date.today+10).to_time, :duration => nil) }
        its(:start_date){ should be_a(Time) }
        its(:end_date){ should be_a(Time)}
      end

      context "when it repeats weekly" do
        before do
          schedule.add_recurrence_date(Date.tomorrow)
          schedule.add_recurrence_rule(IceCube::Rule.weekly(4).day(:monday, :wednesday, :friday))
        end
        it do
          should == OpenStruct.new(
            :repeat        => 1,
            :start_date    => Date.tomorrow.to_time,
            :interval_unit => 'week',
            :interval      => 4,
            :monday        => 1,
            :wednesday     => 1,
            :friday        => 1,
            :end_date => nil,
            :duration => nil
          )
        end
      end
    end
  end
end
