module ACME
  module Plugins
    Quiescence_Data = Struct.new("Quiescence_Data", :node, :stage_data, :goodnode)
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
        stage_times.each do |time|
          if !time.nil? then
            time += 24*60*60 if time.hour <= 10
          end
        end
      end
  
      def get_stage_times(run_log)
        stage_times = []
        @nightrun = false
        curr = nil
        run_log.each do |line|
          if line =~ /Run.*Started/ then
            stage_times = []
          elsif line =~ /Starting: PublishNextStage/ then
            curr = get_timestamp(line, false)
            @nightrun = true if curr.hour >= 22
          elsif line =~ /Published stage Stage ([0-9]+)/ then
            stage = $1.to_i
            stage_times[stage] = curr unless (stage == 4 or stage == 6)
          end
        end
        adjust_hours(stage_times) if @nightrun
        stage_times[4] = stage_times[3] unless stage_times[3].nil?
        stage_times[6] = stage_times[5] unless stage_times[5].nil?
        stage_times.collect! {|x| x.nil? ? Time.at(0).gmtime : x} #stages before the restore start at time 0
        return stage_times
      end

      def get_stage(time)
        stage = 0
        while ((!@stage_times[stage].nil?) && (@stage_times[stage] <= time)) do
          stage += 1
        end

        stage -= 1 
        stage = 3 if stage == 4
        stage = 5 if stage == 6
        return stage
      end
      
      def create_new_stage(new_node, stage)
        start_time = @stage_times[stage]
        start_time = Time.at(0).gmtime if start_time.nil?
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
          new_node = Quiescence_Data.new(qfile.name.split(/\//).last.split(/\./)[0], [], true)
          quiescent = false
          File.new(qfile.name).each do |line|
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
          stages << i if @stage_times[i] > Time.at(0).gmtime
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
        str << "<TR><TD>Node"
        run_stages.each do |s|
          stage = ((s == 3) || (s == 5) ? "#{s}#{s+1}" : s.to_s)
          str << "<TD>Stage #{stage}"
        end
        str << "\n"
        data.each do |node|
          if node.goodnode then
            str << "<TR><TD BGCOLOR=#00FF00>#{node.node}"
          else
            str << "<TR><TD BGCOLOR=#FF0000>#{node.node}"
          end
          run_stages.each do |stage|
            total = Time.at(0).gmtime
            total = node.stage_data[stage].total if (!node.stage_data[stage].nil?)
            if (node.stage_data[stage].nil? || node.stage_data[stage].quiesced) then
              str << "<TD BGCOLOR=#00FF00>#{format_time(total)}"
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