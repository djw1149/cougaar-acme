require "parsedate"

module ACME
  module Plugins
    
    
    class DataGrabberTest
      DataGrabberData = Struct.new("DataGrabberData", :run, :assets, :units, :time)  
      
      def initialize(archive, plugin, ikko)
        @archive = archive
        @ikko = ikko
        @plugin = plugin
      end

      def perform
        run_log = @archive.files_with_name(/run\.log/)[0]
        data = grabber_data(run_log.name)
        if (!data.nil?) then
          @archive.add_report("Grabber", @plugin.plugin_configuration.name) do |report|

            output = html_output(data)
            report.open_file("grabber.html", "text/html", "Data grabber information") do |file|
              file.puts output
            end

            output = create_description
            report.open_file("grabber_description.html", "text/html", "Data grabber test description") do |file|
              file.puts output
            end
            report.success
          end
        end
      end

      def get_timestamp(line, pattern)
        ts = nil
        if pattern.match(line)
          match_vars = $~[1..-1] #save $1, $2, ...
          line =~ /\](.*)::/ #extract the date from the line
          if $1 then
            pd = ParseDate.parsedate($1)
            time = Time.mktime(*pd)
            ts = [time, match_vars]
          end
        end
        return ts
      end

      def grabber_data(run_log)
        data = nil
        start_pattern = /Starting: StartDatagrabberService/
        data_pattern = /INFO: DataGrabber run ([0-9]+) assets ([0-9]+) units ([0-9]+)/
        end_pattern = /Finished: StopDatagrabberService/
        start_time = nil
        
        IO.foreach(run_log) do |line|
          if (ts = get_timestamp(line, start_pattern)) then
            data = DataGrabberData.new
            start_time = ts[0]
          elsif (ts = get_timestamp(line, data_pattern)) then
            data.run = ts[1][0]
            data.assets = ts[1][1]
            data.units = ts[1][2]
          elsif (ts = get_timestamp(line, end_pattern)) then
            data.time = Time.at(ts[0] - start_time).gmtime
          end
        end
        return data
      end
      
      def html_output(data)
        ikko_data = {}
        ikko_data["id"] = @archive.base_name
        ikko_data["description_link"] = "grabber_description.html"
        ikko_data["run"] = data.run
        ikko_data["assets"] = data.assets
        ikko_data["units"] = data.units
        ikko_data["time"] = data.time.strftime("%H:%M:%S")
        return @ikko["grabber.html", ikko_data]
      end

      def create_description
        ikko_data = {}
        ikko_data["name"]="Data Grabber Test"
        ikko_data["title"] = "Data Grabber Test Description"
        ikko_data["description"] = "Displays how much time the data grabber took along with the number of assets and units."
        success_table = {"success"=>"Currently this report is always successful",
                         "partial"=>"not used",
                         "fail"=>"not used"}
        ikko_data["table"] = @ikko["success_template.html", success_table]
        return @ikko["description.html", ikko_data]
      end
    end
  end
end
