module ACME
  module Plugins
    RunTimeData = Struct.new("RunTimeData", :type, :interrupted, :load_time, :start_time, :stage_times)
    
    class RunTimeTest
      def initialize(archive, plugin, ikko)
        @archive = archive
        @ikko = ikko
        @plugin = plugin
      end
      
      def perform
        @archive.add_report("Run Time", @plugin.plugin_configuration.name) do |report|
          run_log = @archive.files_with_name(/run\.log/)[0]
          if run_log
            times = read_run_times(File.new(run_log.name))
            output = html_output(times)
            report.open_file("run_times.html", "text/html", "Run time statistics") do |file|
              file.puts output
            end
            report.success
          else
            report.failure
          end
        end
      end
      
      def get_timestamp(line, pattern)
        ts = nil
        if pattern.match(line)
          match_vars = $~[1..-1] #save $1, $2, ...
          line =~ /([0-9]+)-([0-9]+)-([0-9]+) ([0-9]+):([0-9]+):([0-9]+)/
          time = Time.local($1.to_i, $2.to_i, $3.to_i, $4.to_i, $5.to_i, $6.to_i).to_i
          ts = [time, match_vars]
        end
        return ts
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
        run_log.each do |line|
          if (ts = get_timestamp(line, pattern_table[target])) then
            if (target == :start_run) then
              current = RunTimeData.new("", false, Time.at(0).gmtime, Time.at(0).gmtime, [])
            elsif (target == :load_time_start) then
              start = ts[0]
              current.type = ts[1][0]
            elsif (target == :load_time_end) then
              current.load_time = Time.at(ts[0] - start).gmtime
            elsif (target == :start_time_start) then
              start = ts[0]
            elsif (target == :start_time_persistance_end || target == :start_time_scratch_end) then
              current.start_time = Time.at(ts[0] - start).gmtime
            elsif (target == :stage_time_start)
              start = ts[0]
            elsif (target == :stage_time_end) then
              current.stage_times << Time.at(ts[0] - start).gmtime
            end
            target = next_target(target, current.type)
          elsif (ts = get_timestamp(line, /INTERRUPT/)) then 
            current.interrupted = true
            if (target == :stage_time_end)
              current.stage_times << Time.at(ts[0] - start).gmtime
            elsif (target == :start_time_end || target == :load_time_end)
              current[target] = Time.at(ts[0] - start).gmtime
            end
            all_data << current
            target = :start_run
          elsif (target != :start_run && ts = get_timestamp(line, /Run:.*finished/)) then
            all_data << current
            target = :start_run
          end
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
      
      def format_time(n)
        return Time.at(n).gmtime.strftime("%H:%M:%S")
      end
      
      def get_format_string(data, i)
        str = sprintf("%-7s", (data.interrupted ? "#{i+1}INT" : (i+1).to_s))
        str << sprintf("%-12s", data.load_time.strftime("%H:%M:%S"))
        str << sprintf("%-12s", data.start_time.strftime("%H:%M:%S"))
        data.stage_times.each do |stage_time|
          str << sprintf("%-12s", stage_time.strftime("%H:%M:%S"))
        end
        return str
      end
      
      def get_html_string(data, i)
        str = "<TR><TH>#{data.interrupted ? "#{i+1}INT" : (i+1).to_s}<TH>#{data.load_time.strftime("%H:%M:%S")}<TH>#{data.start_time.strftime("%H:%M:%S")}"
        data.stage_times.each do |stage_time|
          str << "<TH>#{stage_time.strftime("%H:%M:%S")}"
        end
        str << "\n"
        return str
      end
      
      def html_output(all_data)
        str = "<HTML>\n"
        str << "<TABLE border=1>\n"
        str << "<CAPTION>\n"
        str << "Run times by stage\n"
        str << "</CAPTION>\n"
        str << "<TR><TH>Run<TH>Load Time<TH>Start Time<TH>Stage Time[s]\n"
        all_data.each_index do |i|
          str << get_html_string(all_data[i], i)
        end

        load_times = collect_elements(all_data, "load_time")
        start_times = collect_elements(all_data, "start_time")
        all_stage_times = collect_elements(all_data, "stage_times")
        stage_times = []
        all_stage_times[0].each_index do |i|
          stage_times << collect_elements(all_stage_times, i)
        end
        
        str << "<TR><TH>MEAN<TH>#{format_time(mean(load_times))}<TH>#{format_time(mean(start_times))}"
        stage_times.each do |stage|
          str << "<TH>#{format_time(mean(stage))}"
        end
        str << "\n"
        
        str << "<TR><TH>STDDEV<TH>#{format_time(standard_deviation(load_times))}<TH>#{format_time(standard_deviation(start_times))}"
        stage_times.each do |stage|
          str << "<TH>#{format_time(standard_deviation(stage))}"
        end
        str << "\n"
        
        str << "<TR><TH>VARIANCE<TH>#{format_time(variance(load_times))}<TH>#{format_time(variance(start_times))}"
        stage_times.each do |stage|
          str << "<TH>#{format_time(variance(stage))}"
        end
        str << "\n"
        str <<"</TABLE>\n"
        str << "</HTML>\n"
        return str
      end

      def chart_output(all_data)
        str = ""
        str << sprintf("%-7s%-12s%-12s%-12s", "Run", "Load Time", "Start Time", "Stage Time[s]\n")
        all_data.each_index do |i|
          str << get_format_string(all_data[i], i)
          str << "\n"
        end
      
        load_times = collect_elements(all_data, "load_time")
        start_times = collect_elements(all_data, "start_time")
        all_stage_times = collect_elements(all_data, "stage_times")
        stage_times = []
        all_stage_times[0].each_index do |i|
          stage_times << collect_elements(all_stage_times, i)
        end
        
        str << sprintf("%-7s%-12s%-12s", "MEAN", format_time(mean(load_times)), format_time(mean(start_times)))
        stage_times.each do |stage|
          str << sprintf("%-12s", format_time(mean(stage)))
        end
        str << "\n"

        str << sprintf("%-7s%-12s%-12s", "STDDEV", format_time(standard_deviation(load_times)), format_time(standard_deviation(start_times)))
        stage_times.each do |stage|
          str << sprintf("%-12s", format_time(standard_deviation(stage)))
        end
        str << "\n"
        
        str << sprintf("%-7s%-12s%-12s", "VAR", format_time(variance(load_times)), format_time(variance(start_times)))
        stage_times.each do |stage|
          str << sprintf("%-12s", format_time(variance(stage)))
        end
        str << "\n"
        return str
      end
    end
  end
end

  