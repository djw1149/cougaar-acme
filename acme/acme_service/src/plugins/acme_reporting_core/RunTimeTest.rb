require "parsedate"

module ACME
  module Plugins

    
    class RunTimeTest
      RunTimeData = Struct.new("RunTimeData", :type, :interrupted, :load_time, :start_time, :total_time, :stage_times)
      def initialize(archive, plugin, ikko)
        @archive = archive
        @ikko = ikko
        @plugin = plugin
      end
      
      def perform
        @archive.add_report("Time", @plugin.plugin_configuration.name) do |report|
          run_log = @archive.files_with_name(/run\.log/)[0]
          if run_log
            times = read_run_times(File.new(run_log.name))
            output = html_output(times)
            report.open_file("run_times.html", "text/html", "Run time statistics") do |file|
              file.puts output
            end

            output = create_description
            report.open_file("run_times_description.html", "text/html", "Run time test description") do |file|
              file.puts output
            end

            report.success
          else
            report.failure
          end
        end
      end
      
      def get_timestamp(line)
        line =~ /\](.*)::/ #extract the date from the line
        pd = ParseDate.parsedate($1)
        time = Time.mktime(*pd)
        return time
      end
      
      def next_target(target, type=nil)
        return :load_time_start if target == :start_run
        return :load_time_end if target == :load_time_start
        return :start_time_start if target == :load_time_end
        return :start_time_persistance_end  if (target == :start_time_start && type == "Persistence")
        return :start_time_scratch_end if (target == :start_time_start && (type == "XML" || type == "Script"))
        return :stage_time_start if target == :start_time_persistance_end || target == :start_time_scratch_end
        return :stage_time_end if target == :stage_time_start
        return :stage_time_start if target == :stage_time_end
        return nil
      end
        
      def read_run_times(run_log)
        pattern_table = {:start_run => /Run:.*started/,
                         :load_time_start => /Starting: LoadSocietyFrom(Persistence|XML|Script)/,
                         :load_time_end => /Finished: LoadSociety/,
                         :start_time_start =>  /Starting: StartSociety/,
                         :start_time_persistance_end => /Done: SocietyQuiesced/,
                         :start_time_scratch_end => /Waiting for: NextOPlanStage/,
                         :stage_time_start => /Starting: PublishNextStage/,
                         :stage_time_end => /Done: SocietyQuiesced/}
        
        target = :start_run
        all_data = []
        start = nil
        current = nil
        total_start = nil        

        run_log.each do |line|
          ts = get_timestamp(line)
          if (md = pattern_table[target].match(line)) then            
            if (target == :start_run) then
              current = RunTimeData.new("", false, Time.at(0).gmtime, Time.at(0).gmtime, Time.at(0).gmtime, [])
              total_start = ts
            elsif (target == :load_time_start) then
              start = ts
              current.type = md[1]
            elsif (target == :load_time_end) then
              current.load_time = ts - start
            elsif (target == :start_time_start) then
              start = ts
            elsif (target == :start_time_persistance_end || target == :start_time_scratch_end) then
              current.start_time = ts - start
            elsif (target == :stage_time_start)
              start = ts
            elsif (target == :stage_time_end) then
              current.stage_times << ts - start
            end
            target = next_target(target, current.type)
          elsif (line =~ /INTERRUPT/) then 
            current.interrupted = true
            if (target == :stage_time_end)
              current.stage_times << ts - start
            end
            all_data << current
            current = nil
            target = :start_run
          elsif (target != :start_run && line =~ /Run:.*finished/) then
            all_data << current
            current = nil
            target = :start_run
          end
          current.total_time = ts - total_start if (!current.nil?)
        end
        all_data << current unless target == :start_run
        return all_data
      end
      
      def mean(data)
        return 0 if data.size == 0
        n = 0
        data.each do |x|
          n += x.to_i
        end
        n /= data.size
        return n
      end
      
      def standard_deviation(data, m = nil)
        return variance(data, m) ** (0.5)
      end
      
      def variance(data, m = nil)
        return 0 if data.size < 2
        m = mean(data) if m.nil?
        n = 0
        data.each do |x|
          n += (x.to_i - m)**2
        end
        n /= (data.size - 1)
        return n
      end
      
      def std_percent(data)
	m = mean(data)
        sd = standard_deviation(data, m)
        return sprintf("%6.3f", (100*sd).to_f / m.to_f) + "%"
      end

      def collect_elements(all_data, field)
        data = []
        all_data.each do |elem|
          if elem.class.to_s  == "Struct::RunTimeData" then
            data << elem[field] unless (elem[field].nil? || elem.type =~ /INTERRUPTED/)
          else 
            data << elem[field] unless elem[field].nil?
          end
        end
        return data
      end

      def collect_stat(all_data)
        load_times = collect_elements(all_data, "load_time")
        start_times = collect_elements(all_data, "start_time")
        total_times = collect_elements(all_data, "total_time")
        all_stage_times = collect_elements(all_data, "stage_times")
        stage_times = []
        all_stage_times[0].each_index do |i|
          stage_times << collect_elements(all_stage_times, i)
        end
        
        stat_data = RunTimeData.new
        stat_data.load_time = yield load_times
        stat_data.start_time = yield start_times
        stat_data.total_time = yield total_times
        stat_data.stage_times = []
        stage_times.each do |time|
          stat_data.stage_times << (yield time)
        end
        return stat_data
      end              

      def format_time(n)
        return Time.at(n).gmtime.strftime("%H:%M:%S")
      end

      def get_class(val, mean, stddev)
        return val <= (mean + 2 *stddev) ? "#00DD00" : "#FF0000"
      end

      def row_output(row, data, mean, stddev)
        row_string = @ikko["cell_template.html", {"data"=>row}]
        cellclass = get_class(data.total_time, mean.total_time, stddev.total_time)
        row_string <<  @ikko["cell_template.html", {"data"=>format_time(data.total_time), "options"=>"bgcolor=#{cellclass}"}]

        cellclass = get_class(data.load_time, mean.load_time, stddev.load_time)
        row_string <<  @ikko["cell_template.html", {"data"=>format_time(data.load_time), "options"=>"bgcolor=#{cellclass}"}]

        cellclass = get_class(data.start_time, mean.start_time, stddev.start_time)
        row_string <<  @ikko["cell_template.html", {"data"=>format_time(data.start_time), "options"=>"bgcolor=#{cellclass}"}]

        data.stage_times.each_index do |i|
          cellclass = get_class(data.stage_times[i], mean.stage_times[i], stddev.stage_times[i])
          row_string <<  @ikko["cell_template.html", {"data"=>format_time(data.stage_times[i]), "options"=>"bgcolor=#{cellclass}"}]
        end
        return row_string
      end


      def html_output(all_data)
        ikko_data = {}
        ikko_data["description_link"]="run_times_description.html"
        ikko_data["id"] = @archive.base_name

        mean_data = collect_stat(all_data){|x| mean(x)}
        stddev_data = collect_stat(all_data){|x| standard_deviation(x)}
        percent_data = collect_stat(all_data){|x| std_percent(x)}

        headers = ["Run", "Total Time", "Load Time", "Start Time", "Stage Time[s]"]
        header_string = ""
        headers.each do |h|
          header_string << @ikko["header_template.html", {"data"=>h}]
        end
        table_string = @ikko["row_template.html", {"data"=>header_string}]
        
        all_data.each_index do |i|
          row_string = row_output((i+1).to_s, all_data[i], mean_data, stddev_data)
          table_string << @ikko["row_template.html", {"data"=>row_string}]
        end

        row_string = @ikko["cell_template.html", {"data"=>"MEAN"}]
        row_string << @ikko["cell_template.html", {"data"=>format_time(mean_data.total_time)}]
        row_string << @ikko["cell_template.html", {"data"=>format_time(mean_data.load_time)}]
        row_string << @ikko["cell_template.html", {"data"=>format_time(mean_data.start_time)}]

        mean_data.stage_times.each do |stage|
          row_string << @ikko["cell_template.html", {"data"=>format_time(stage)}]
        end
        table_string << @ikko["row_template.html", {"data"=>row_string}]

        row_string = @ikko["cell_template.html", {"data"=>"STDDEV"}]
        row_string << @ikko["cell_template.html", {"data"=>format_time(stddev_data.total_time)}]
        row_string << @ikko["cell_template.html", {"data"=>format_time(stddev_data.load_time)}]
        row_string << @ikko["cell_template.html", {"data"=>format_time(stddev_data.start_time)}]
        stddev_data.stage_times.each do |stage|
          row_string << @ikko["cell_template.html", {"data"=>format_time(stage)}]
        end
        table_string << @ikko["row_template.html", {"data"=>row_string}]

        row_string = @ikko["cell_template.html", {"data"=>"STDDEV Percent"}]
        row_string << @ikko["cell_template.html", {"data"=>percent_data.total_time}]
        row_string << @ikko["cell_template.html", {"data"=>percent_data.load_time}]
        row_string << @ikko["cell_template.html", {"data"=>percent_data.start_time}]
        percent_data.stage_times.each do |stage|
          row_string << @ikko["cell_template.html", {"data"=>stage}]
        end
        table_string << @ikko["row_template.html", {"data"=>row_string}]

        ikko_data["table"] = table_string
        return @ikko["time_report.html", ikko_data]
      end

      def create_description
        ikko_data = {}
        ikko_data["name"]="Run Time Test"
        ikko_data["title"] = "Run Time Test Description"
        ikko_data["description"] = "Creates a table showing the time the society took for loading, starting, and each stage"
        ikko_data["description"] << " for each run in the run.log.  Green boxes indicate times that are less than the mean"
        ikko_data["description"] << " plus two standard deviations.  Red boxes indicate times that are greater than the mean"
        ikko_data["description"] << " plus two standard deviations.  The colors of the boxes do not currently determine success"
        ikko_data["description"] << " or failure of the test."
 
        success_table = {"success"=>"Run.log present",
                         "partial"=>"not used",
                         "fail"=>"run.log not found"}
        ikko_data["table"] = @ikko["success_template.html", success_table]
        return @ikko["description.html", ikko_data]
      end
    end
  end
end
