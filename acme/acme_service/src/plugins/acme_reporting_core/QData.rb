#! /usr/bin/ruby --

module ACME
  module Plugins
    QuiescenceData = Struct.new("QuiescenceData", :node, :stage_data, :goodnode)
    StageTime = Struct.new("StageTime", :start_time, :end_time, :range)

    class StageData
      attr_reader :stage, :times, :total, :quiesced
      def initialize(stage, starttime, initial_state)
        @stage = stage
        @times = []
        @total = 0
        @quiesced = true
        add(starttime, initial_state)
      end
      
      def add(time, quiesced)
        #only add time if it is a transition
        return if quiesced == @quiesced
        @times << time
        @quiesced = quiesced
        #adjust total on transitions from false to true
        if (@quiesced && @times.size > 1) then
          @total += @times[-1] - @times[-2]
        end
      end
    end

    class QData
      def initialize(archive, plugin, ikko)
        @archive = archive
        @plugin = plugin
        @ikko = ikko
      end
      
      def perform_local(dir)
        Dir.chdir(dir)
        run_log = Dir["run.log"][0]
        if (run_log) then
          @stage_times = get_stage_times(File.new(run_log))
          Dir.chdir("mnt")
          society_shared = Dir["*"][0]
          Dir.chdir(society_shared)
          society_name = Dir["*"][0]
          Dir.chdir("#{society_name}/workspace/log4jlogs")
          quiescence_files = Dir["*"]
          data = get_quiescence_times(quiescence_files)
          puts html_output(data)
        end
      end
          
      
      def perform
        @archive.add_report("Quiescence Data", @plugin.plugin_configuration.name) do |report|
          run_log = @archive.files_with_name(/run\.log/)[0]
          if (run_log) then
            @stage_times = get_stage_times(File.new(run_log.name))
            if (@stage_times.empty?) then #We had no stages because the run dies too soon
              report.failure
            else
              quiescence_files = @archive.files_with_description(/Log4j node log/)
              data = get_quiescence_times(quiescence_files)
              status = analyze(data)
              if (status == 0) then
                report.success
              else
                report.failure
              end
              output = html_output(data)
              report.open_file("qdata.html", "text/html", "Quiescence Time Report") do |file|
                file.puts output
              end
            end
          else
            report.failure
          end
        end
      end

      def get_timestamp(line, gm = true)
        line =~ /([0-9][0-9]):([0-9][0-9]):([0-9][0-9])/
        ts = Time.at($1.to_i*3600 + $2.to_i*60 + $3.to_i).gmtime
        if !gm then
          if (ts.hour < 19) then
            ts += 5*3600 unless gm #convert to gmtime if not already
          else
            ts -= 19*3600 #don't want conversion to change the day
          end
        end
        return ts 
      end

      def adjust_hours(stage_times)
        stage_times.each do |stage_time|
          if !stage_time.nil? then
            stage_time.start_time += 24*60*60 if stage_time.start_time.hour <= 10
            stage_time.end_time += 24*60*60 if (stage_time.end_time.hour <= 10 || stage_time.start_time.hour <= 10)
            stage_time.range = (stage_time.start_time .. stage_time.end_time) 
          end
        end
      end
  
      def get_stage_times(run_log)
        stage_times = []
        @nightrun = false
        curr = nil
        stage = nil
        run_log.each do |line|
          if line =~ /Run.*Started/ then
            stage_times = []
          elsif (stage.nil? && line =~ /Starting: PublishNextStage/) then
            curr = get_timestamp(line, false)
            @nightrun = true if curr.hour >= 22
          elsif line =~ /Published stage Stage ([0-9]+)/ then
            stage = $1.to_i
            stage_times[stage] = StageTime.new
            if !(stage == 4 or stage == 6) then
              stage_times[stage].start_time = curr
            else
              stage -= 1
            end
          elsif (!stage.nil? && line =~ /Done: SocietyQuiesced/) then
            curr = get_timestamp(line, false)
            @nightrun = true if curr.hour >= 22
            stage_times[stage].end_time = curr
            stage_times[stage].range = (stage_times[stage].start_time .. stage_times[stage].end_time) 
            stage = nil 
          end
        end
        stage_times.collect!{|x| (x.nil? || x.range.nil?) ? nil : x}
        adjust_hours(stage_times) if @nightrun
        stage_times[4] = stage_times[3] unless stage_times[3].nil?
        stage_times[6] = stage_times[5] unless stage_times[5].nil?
        return stage_times
      end

      def get_stage(time)
        stage = 0
        while (stage < @stage_times.size)
          break if (!@stage_times[stage].nil? && @stage_times[stage].range === time)
          stage += 1
        end

        stage = 3 if stage == 4
        stage = 5 if stage == 6
        return stage
      end
      
      def create_new_stage(new_node, stage)
        start_time = nil
        if  (@stage_times[stage].nil?) then
          start_time = Time.at(0).gmtime if start_time.nil?
        else
          start_time = @stage_times[stage].start_time
        end
        initial = false
        last = stage - 1
        last -= 1 while (last >= 0 && new_node.stage_data[last].nil?)
        if (last >= 0) then
          initial = new_node.stage_data[last].quiesced
        end
        new_node.stage_data[stage] = StageData.new(stage, start_time, initial)
      end

      def get_quiescence_times(qfiles)
        data = []
        qfiles.each do |qfile|
          file_name = nil
          if qfile.class.to_s == "String" then
            file_name = qfile
          else
            file_name = qfile.name
          end

          new_node = QuiescenceData.new(file_name.split(/\//).last.split(/\./)[0], [], true)

          quiescent = false
          File.new(file_name).each do |line|
            next unless line =~ /quiescent="(false|true)"/
            quiescent = ($1 == "true")
            ts = get_timestamp(line, true)
            ts += 24*60*60 if (@nightrun && ts.hour <= 10)
            stage = get_stage(ts)
            if (new_node.stage_data[stage].nil?)
              create_new_stage(new_node, stage)
            end
            new_node.stage_data[stage].add(ts, quiescent)
          end
          data << new_node
        end
        return data
      end

      def get_run_stages
        stages = []
        @stage_times.each_index do |i|
          next if (i == 4 or i == 6)
          stages << i unless @stage_times[i].nil?
        end
        return stages
      end

      def analyze(data)
        status = 0
        stages = get_run_stages
        data.each do |node|
          stages.each do |stage|
            if (!node.stage_data[stage].nil? && !node.stage_data[stage].quiesced) then
              node.goodnode = false
              status = 1
            end
          end
        end
        return status
      end

      def format_time(t)
	return Time.at(t).gmtime.strftime("%H:%M:%S")
      end
      
      def html_output(data)
        run_stages = get_run_stages
        str = ""
        str << "<HTML>\n"
        str << "<TABLE border=\"1\">\n"
        str << "<CAPTION>Total time unquiesced by stage</CAPTION>\n"
        str << "<TR><TH>Node"
        run_stages.each do |s|
          stage = ((s == 3) || (s == 5) ? "#{s}#{s+1}" : s.to_s)
          str << "<TH>Stage #{stage}"
        end
        str << "\n"
        data.each do |node|
          if node.goodnode then
            str << "<TR><TD BGCOLOR=#00DD00>#{node.node}"
          else
            str << "<TR><TD BGCOLOR=#FF0000>#{node.node}"
          end
          run_stages.each do |stage|
            total = Time.at(0).gmtime
            total = node.stage_data[stage].total if (!node.stage_data[stage].nil?)
            if (node.stage_data[stage].nil? || node.stage_data[stage].quiesced) then
              str << "<TD BGCOLOR=#00DD00>#{format_time(total)}"
            else
              str << "<TD BGCOLOR=#FF0000>#{format_time(total)}"
            end
          end
          str <<"\n"
        end
        str << "</TABLE>\n"
        str << "</HTML>\n"
        return str
      end
    end
  end
end

if $0==__FILE__
  queue = ACME::Plugins::QData.new(nil, nil, nil)
  queue.perform_local($*[0])
end