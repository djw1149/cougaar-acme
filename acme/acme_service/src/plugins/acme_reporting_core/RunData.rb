require "parsedate"

module ACME
  module Plugins

    class StageTime
      attr_accessor :start_time, :end_time
      attr_reader :name
      
      def initialize(name)
        @start_time = Time.at(0).gmtime
        @end_time = Time.at(0).gmtime
        @name = name
        @total = nil
      end
      
      def include?(time)
        return (@start_time..@end_time).include?(time)
      end
      
      def append_name(name)
        @name += name
      end
      
      def total
        return @end_time - @start_time
      end

    end
  
    class RunTime
      attr_accessor :run_start_time, :run_end_time, :type, :interrupted, :killed_nodes
      attr_reader :load_time, :start_time, :stages, :advances, :name
      
      def initialize(run_log, name)
        pattern_table = {:start_run => /Run:(.*)started/,
                         :load_time_start => /Starting: LoadSocietyFrom(Persistence|XML|Script)/,
                         :load_time_end => /Finished: LoadSociety/,
                         :start_time_start =>  /Starting: StartSociety/,
                         :start_time_end => /^xyz/, #match nothing
                         :stage_time_start => /Starting: PublishNextStage/,
                         :stage_time_publish => /INFO: Published stage.*([0-9]+)/,
                         :stage_time_end => /Done: SocietyQuiesced/,
                         :advance_time_start => /Advancing time to .* \((C[-+][0-9]+)\)/,
                         :advance_time_end => /Finished: AdvanceTime/,
                         :kill_nodes => /Starting: KillNodes\((.*)\)/}
        current_stage = nil
        start = nil
        reset
        @name = name
        File.new(run_log).each do |line|
          ts = get_timestamp(line)
          if (md = pattern_table[:start_run].match(line)) then
            reset
            @run_start_time = ts
            surrent_stage = nil
          elsif (start.nil? && md = pattern_table[:load_time_start].match(line)) then            
            @type = md[1]
            if md[1] == "Persistence" then
              pattern_table[:start_time_end] = /Done: SocietyQuiesced/
            else
              pattern_table[:start_time_end] = /Waiting for: NextOPlanStage/
            end
            @load_time.start_time = ts
            current_stage = "Start Time"
          elsif (start.nil? && md = pattern_table[:load_time_end].match(line)) then            
            @load_time.end_time = ts
            current_stage = nil
          elsif (start.nil? && md = pattern_table[:start_time_start].match(line)) then            
            @start_time.start_time = ts
            current_stage = "Start Time"
          elsif (start.nil? && md = pattern_table[:start_time_end].match(line)) then            
            @start_time.end_time = ts
            current_stage = nil
          elsif (md = pattern_table[:stage_time_start].match(line))
            start = ts
          elsif (md = pattern_table[:stage_time_publish].match(line))
            if (current_stage.nil?) then
              current_stage = "Stage#{md[1]}"
              @stages << StageTime.new(current_stage)
              self[current_stage].start_time = start
            else #need to append this stage
              self[current_stage].append_name("_#{md[1]}")
              current_stage += "_#{md[1]}"
            end
          elsif (md = pattern_table[:stage_time_end].match(line) && !self[current_stage].nil?)
            self[current_stage].end_time = ts
            current_stage = nil
          elsif (md = pattern_table[:advance_time_start].match(line))
            current_stage = "Advance to #{md[1]}"
            @advances << StageTime.new(current_stage)
            self[current_stage].start_time = ts
          elsif (md = pattern_table[:advance_time_end].match(line))
            self[current_stage].end_time = ts
            current_stage = nil
          elsif (md = pattern_table[:kill_nodes].match(line)) then
            @killed_nodes << md[1].split(",").collect{|x| x.strip}
            @killed_nodes.flatten!
          elsif (line =~ /INTERRUPT/) then 
            @interrupted = true
            @run_end_time = ts
            self[current_stage].end_time = ts unless current_stage.nil?
          end
          #set end time to timestamp incase log ends unexpectedly
          @run_end_time = ts unless @name == ""
        end
      end

      def reset
        @run_start_time = Time.at(0).gmtime
        @run_end_time = Time.at(0).gmtime
        @load_time = StageTime.new("Load Time")
        @start_time = StageTime.new("Start Time")
        @stages = []
        @advances = []
        @interrupted = false
        @killed_nodes = []
      end

      def get_timestamp(line)
        line =~ /\](.*)::/ #extract the date from the line
        return Time.at(0) if $1.nil?
        pd = ParseDate.parsedate($1)
        time = Time.mktime(*pd)
        return time
      end
      
      def total
        return @run_end_time - @run_start_time
      end

      def has_header?(header)
        return headers.include?(header)
      end
      
      def headers
        headers = []
        headers << "Load Time"
        headers << "Start Time"
        @stages.each do |stage|
          headers << stage.name
        end
        @advances.each do |adv|
          headers << adv.name
        end
        return headers
      end

      def get_stage(time)
        return @load_time.name if @load_time.include?(time)
        return @start_time.name if @start_time.include?(time)
        @stages.each do |stage|
          return stage.name if stage.include?(time)
        end
        @advances.each do |adv|
          return adv.name if adv.include?(time)
        end
        return nil
      end

 
      def[](header)
        return @load_time if header == "Load Time"
        return @start_time if header == "Start Time"
        @stages.each do |stage|
          return stage if stage.name == header
        end
        @advances.each do |adv|
          return adv if adv.name == header
        end
        return nil
      end
    end
  end
end

