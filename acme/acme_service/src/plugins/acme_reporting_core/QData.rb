require "parsedate"
require "./plugins/acme_reporting_core/RunData"

module ACME
  module Plugins

    class QuiescenceData
      attr_reader :node, :stage_data
      attr_accessor :goodnode

      def initialize(name)
        @node = name
        @stage_data = {}
        @goodnode = true
      end
       
      def <=> (other)
        if (@goodnode == other.goodnode)
          return other.total <=> total
        elsif (@goodnode)
          return 1
        end
        return -1
      end

      def total
        t = 0
        @stage_data.each_value do |val|
          t += val.total
        end
        return t
      end
    end
        

    class StageQData
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
            @run_times = RunTime.new(run_log.name)
            quiescence_files = @archive.files_with_description(/Log4j node log/)
            data = get_quiescence_times(quiescence_files)
            status = analyze(data)
            data.sort!
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
        end
      end

      def get_timestamp(line)
        pd = nil
        if (line =~ /\](.*)::/) then #run.log format
          pd = ParseDate.parsedate($1)
        elsif (line =~ /^(.*),/) then #log4jlog format
          pd = ParseDate.parsedate($1)
        end
        
        return Time.at(0) if (pd.nil? || pd[0...6] != pd[0...6].compact)
       
        return Time.mktime(*pd)
      end
      
      def create_new_stage(new_node, stage, initial)
        start_time = nil
        start_time = @run_times[stage].start_time
        return StageQData.new(stage, start_time, initial)
      end               

      def get_quiescence_times(qfiles)
        data = []
        qfiles.each do |qfile|
          next unless qfile.name =~ /\.log/ #don't want cnclogs
          new_node = QuiescenceData.new(qfile.name.split(/\//).last.split(/\./)[0])
          quiescent = false
          prev = false
          File.new(qfile.name).each do |line|
            next unless line =~ /quiescent="(false|true)"/
            prev = quiescent
            quiescent = ($1 == "true")
            ts = get_timestamp(line)
            stage = @run_times.get_stage(ts)
            next if stage.nil?
            if (new_node.stage_data[stage].nil?)
              new_node.stage_data[stage] = create_new_stage(new_node, stage, prev)
            end
            new_node.stage_data[stage].add(ts, quiescent)
          end
          data << new_node
        end
        return data
      end

      def get_run_stages
        stages = @run_times.headers
        stages -= ["Total", "Load Time"]
        return stages
      end

      def analyze(data)
        status = 0
        stages = get_run_stages
        data.each do |node|
          next if @run_times.killed_nodes.include?(node.node)
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
          header_string << @ikko["header_template.html", {"data"=>s}]
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