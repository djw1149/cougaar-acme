require "parsedate"

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
      
      def perform
        @archive.add_report("Q", @plugin.plugin_configuration.name) do |report|
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

              output = create_description
              report.open_file("qdata_description.html", "text/html", "Quiescence Time Report Description") do |file|
                file.puts output
              end

            end
          else
            report.failure
          end
        end
      end

      def get_timestamp(line)
        pd = nil
        if (line =~ /\](.*)::/) then #run.log format
          pd = ParseDate.parsedate($1)
        elsif (line =~ /^(.*),/) then #log4jlog format
          pd = ParseDate.parsedate($1)
        end
	if pd.nil? then
          puts line
          return nil
        end
        return Time.mktime(*pd)
      end

      def get_stage_times(run_log)
        stage_times = []
        curr = nil
        stage = nil
        run_log.each do |line|
          if line =~ /Run.*Started/ then
            stage_times = []
          elsif (stage.nil? && line =~ /Starting: PublishNextStage/) then
            curr = get_timestamp(line)
          elsif line =~ /Published stage Stage ([0-9]+)/ then
            stage = $1.to_i
            stage_times[stage] = StageTime.new
            if !(stage == 4 or stage == 6) then
              stage_times[stage].start_time = curr
            else
              stage -= 1
            end
          elsif (!stage.nil? && line =~ /Done: SocietyQuiesced/) then
            curr = get_timestamp(line)
            stage_times[stage].end_time = curr
            stage_times[stage].range = (stage_times[stage].start_time .. stage_times[stage].end_time) 
            stage = nil 
          end
        end
        stage_times.collect!{|x| (x.nil? || x.range.nil?) ? nil : x}
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
          next unless qfile.name =~ /\.log/ #don't want cnclogs
          new_node = QuiescenceData.new(qfile.name.split(/\//).last.split(/\./)[0], [], true)
          quiescent = false
          File.new(qfile.name).each do |line|
            next unless line =~ /quiescent="(false|true)"/
            quiescent = ($1 == "true")
            ts = get_timestamp(line)
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
        ikko_data = {}
        ikko_data["id"]= @archive.base_name
        ikko_data["description_link"] = "qdata_description.html"
        header_string = @ikko["header_template.html", {"data"=>"Agent Name", "option"=>""}]
        run_stages.each do |s|
          stage = ((s == 3) || (s == 5) ? "#{s}#{s+1}" : s.to_s)
          header_string << @ikko["header_template.html", {"data"=>"Stage #{stage}"}]
        end
        table_string = @ikko["row_template.html", {"data"=>header_string}]
        data.each do |node|
          row_string = ""
          if node.goodnode then
            row_string << @ikko["cell_template.html", {"data"=>node.node, "options"=>"BGCOLOR=00DD00"}]
          else
            row_string << @ikko["cell_template.html", {"data"=>node.node, "options"=>"BGCOLOR=FF0000"}]
          end
          run_stages.each do |stage|
            #Some agents may have no quiescent data for a stage
            #espescially if the run was bad
            #so default total to 0 and be careful with node.stage_data[stage]
            total = Time.at(0).gmtime
            total = node.stage_data[stage].total if (!node.stage_data[stage].nil?)
            if (node.stage_data[stage].nil? || node.stage_data[stage].quiesced) then
              row_string <<@ikko["cell_template.html", {"data"=>format_time(total), "options"=>"BGCOLOR=00DD00"}]
            else
              row_string <<@ikko["cell_template.html", {"data"=>format_time(total), "options"=>"BGCOLOR=FF0000"}]
            end
          end
          table_string << @ikko["row_template.html", {"data"=>row_string, "option"=>""}]
        end
        ikko_data["table"] = table_string
        return @ikko["qdata_report.html", ikko_data]
      end

      def create_description
        ikko_data = {}
        ikko_data["name"]="Quiescence Data Report"
        ikko_data["title"] = "Quiescence Data Description"
        ikko_data["description"] = "Creates a table showing the time that each node spent unquiescent at each stage.  An entry"
        ikko_data["description"] << " in the table is red if the node did not quiesce at the end of that stage.  An entry in the "
        ikko_data["description"] << "node column is red if that node did not quiesce at the end of any stage.  If the node did"
        ikko_data["description"] << " not quiesce by the end of the stage then the time will be underreported."

        success_table = {"success"=>"Each node is quiescent at the end of each stage",
                         "partial"=>"not used",
                         "fail"=>"At least one node is not quiescent at the end of at least one stage"}
        ikko_data["table"] = @ikko["success_template.html", success_table]
        return @ikko["description.html", ikko_data]
      end

    end
  end
end