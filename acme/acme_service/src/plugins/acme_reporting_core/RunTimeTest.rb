require "./plugins/acme_reporting_core/RunData"
module ACME
  module Plugins

    
    class RunTimeTest
  
      def initialize(archive, plugin, ikko, cm)
        @archive = archive
        @ikko = ikko
        @plugin = plugin
        @cm = cm
      end
      
      def perform
        @archive.add_report("Time", @plugin.plugin_configuration.name) do |report|
          times = []
          run_log = @archive.files_with_name(/run\.log/)[0]
          if run_log
            #get run data from the cache manager for the current run
            runtime = @cm.load(@archive.base_name, RunTime) do |name|
              RunTime.new(run_log.name, name)
            end
            times << runtime

            group_pattern = Regexp.new("-#{@archive.group}-")
            @archive.get_prior_archives(60*60*24*365, group_pattern).each do |prior_name|
              times << get_prior_data(prior_name)
            end
  

            runtime_path = @plugin.properties['runtime_path']
            if File.exist?(runtime_path) then
              update_runtime_file(times[0], runtime_path, @archive.group)
            end

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

      def get_prior_data(prior_name)
        runtime = @cm.load(prior_name, RunTime) do |name|
          prior = @archive.open_prior_archive(name)
          run_log = prior.files_with_name(/run\.log/)[0]
          tmp =  RunTime.new(run_log.name, prior.base_name) if run_log
          prior.cleanup
          tmp #block must return object of type RunTime
        end
        return runtime
      end
      
      def mean(data)
        return 0 if data.size == 0
        n = 0
        data.compact.each do |x|
          n += x.to_i
        end
        n /= data.compact.size
        return n
      end
      
      def standard_deviation(data, m = nil)
        return variance(data, m) ** (0.5)
      end
      
      def variance(data, m = nil)
        return 0 if data.size < 2
        m = mean(data) if m.nil?
        n = 0
        data.compact.each do |x|
          n += (x.to_i - m)**2
        end
        n /= (data.compact.size - 1)
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
          data << elem[field].total unless (elem.interrupted || elem[field].nil?)
        end
        return data
      end

      def collect_stat(all_data, headers)
        result = {}
        data = []
        all_data.each do |run_data|
          data << run_data.total
        end
        result["Total"] = yield data
        
        headers.each do |header|        
          data = collect_elements(all_data, header)
          result[header] = yield data
        end
        return result         
      end              

      def format_data(n)
        return n if n.class.to_s =~ /String/
        return Time.at(n).gmtime.strftime("%H:%M:%S")
      end

      def update_runtime_file(data, dir, group)
        File.open(File.join(dir, group), "a") do |run_file|
          run_file.puts(sprintf("%-50s", data.name))
          run_file.puts(sprintf("%-10s %-10s", "Total", format_data(data.total)))
          data.headers.each do |header|
            run_file.puts(sprintf("%-10s %-10s", header, format_data(data[header].total)))
          end
        end
      end
          
      def get_class(val, mean, stddev)
        return "#FFFFFF" if val.class.to_s =~ /String/
        return val.to_f <= (mean + 2 * stddev) ? "#00DD00" : "#FF0000"
      end

      def get_headers(all_data)
        headers = []
        all_data.each do |run_data|
          headers |= run_data.headers
        end
        return headers
      end

      def row_output(row, data, headers, mean, stddev)
        if data.class.to_s =~ /RunTime/ then
          cellclass = data.interrupted ? "#FF0000" : "#FFFFFF"
          row_string = @ikko["cell_template.html", {"data"=>row, "options"=>"BGCOLOR=#{cellclass}"}]
          cellclass = get_class(data.total, mean["Total"], stddev["Total"])
          row_string << @ikko["cell_template.html", {"data"=>format_data(data.total), "options"=>"BGCOLOR=#{cellclass}"}]                        
          headers.each do |header|
            val = (data[header].nil? ? "-" : data[header].total)
            cellclass = get_class(val, mean[header], stddev[header])
            row_string << @ikko["cell_template.html", {"data"=>format_data(val), "options"=>"BGCOLOR=#{cellclass}"}]
          end
        else #data is a hash
          row_string = @ikko["cell_template.html", {"data"=>row}]
          row_string << @ikko["cell_template.html", {"data"=>format_data(data["Total"])}]                        
          headers.each do |header|
            cellclass = "#FFFFFF"
            row_string << @ikko["cell_template.html", {"data"=>format_data(data[header]), "options"=>"BGCOLOR=#{cellclass}"}]
          end
        end
        return row_string
      end
        

      def html_output(all_data)
        ikko_data = {}
        ikko_data["description_link"]="run_times_description.html"
        ikko_data["id"] = @archive.base_name

        headers = get_headers(all_data)
        header_string = @ikko["header_template.html", {"data"=>"Run"}]
        header_string << @ikko["header_template.html", {"data"=>"Total"}]
        headers.each do |h|
          header_string << @ikko["header_template.html", {"data"=>h}]
        end
        table_string = @ikko["row_template.html", {"data"=>header_string}]

        mean_data = collect_stat(all_data, headers){|x| mean(x)}
        stddev_data = collect_stat(all_data, headers){|x| standard_deviation(x)}
        percent_data = collect_stat(all_data, headers){|x| std_percent(x)}

        
        all_data.each_index do |i|
          row_string = row_output(all_data[i].name, all_data[i], headers, mean_data, stddev_data)
          table_string << @ikko["row_template.html", {"data"=>row_string}]
        end

        row_string = row_output("MEAN", mean_data, headers, nil, nil)
        table_string << @ikko["row_template.html", {"data"=>row_string}]
        row_string = row_output("STDDEV", stddev_data, headers, nil, nil)
        table_string << @ikko["row_template.html", {"data"=>row_string}]
        row_string = row_output("STDDEV Percent", percent_data, headers, nil, nil)
        table_string << @ikko["row_template.html", {"data"=>row_string}]

        ikko_data["table"] = table_string
        return @ikko["time_report.html", ikko_data]
      end

      def create_description
        ikko_data = {}
        ikko_data["name"]="Run Time Test"
        ikko_data["title"] = "Run Time Test Description"
        ikko_data["description"] = "Creates a table showing the time the society took for loading, starting, and each stage"
        ikko_data["description"] << " for each run in the archive and compares it with each run in the rpevious 24 hours."
        ikko_data["description"] << " 	Green boxes indicate times that are less than the mean plus two standard deviations."
        ikko_data["description"] << " Red boxes indicate times that are greater than the mean plus two standard deviations."
        ikko_data["description"] << " The colors of the boxes do not currently determine success"
        ikko_data["description"] << " or failure of the test.  If the run name itself is red, then that run was interrupted"
        ikko_data["description"] << " and it will not be counted in the statistics."

 
        success_table = {"success"=>"Run.log present",
                         "partial"=>"not used",
                         "fail"=>"run.log not found"}
        ikko_data["table"] = @ikko["success_template.html", success_table]
        return @ikko["description.html", ikko_data]
      end
    end
  end
end
