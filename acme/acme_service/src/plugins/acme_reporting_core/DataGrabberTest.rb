require "parsedate"

module ACME
  module Plugins
    
    
    class DataGrabberTest

      UNITS = 1056
      ASSETS = 22000      

      DataGrabberData = Struct.new("DataGrabberData", :run, :assets, :units, :time)  
      
      def initialize(archive, plugin, ikko)
        @archive = archive
        @ikko = ikko
        @plugin = plugin
      end

      def perform
        run_log = @archive.files_with_name(/run\.log/)[0]
        data = []
        if (run_log) then        
          data = grabber_data(run_log.name)
        end
        if (!data.empty?) then
          @archive.add_report("GbbR", @plugin.plugin_configuration.name) do |report|

            result = analyze(data.last)
            if result == 0 then
              report.success
            elsif result == 1 then
              report.partial_success
            else
              report.failure
            end
            output = html_output(data)
            report.open_file("grabber.html", "text/html", "Data grabber information") do |file|
              file.puts output
            end

            output = create_description
            report.open_file("grabber_description.html", "text/html", "Data grabber test description") do |file|
              file.puts output
            end
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
        data = []
        curr = nil
        new_run = /Run:(.*)started/
        start_pattern = /Starting: StartDatagrabberService/
        data_pattern = /INFO: DataGrabber run ([0-9]+) assets ([0-9]+) units ([0-9]+)/
        end_pattern = /Finished: StopDatagrabberService/
        start_time = nil
        
        IO.foreach(run_log) do |line|
          if (ts = get_timestamp(line, new_run)) then
            data = []
            curr = nil
          elsif (ts = get_timestamp(line, start_pattern)) then
            curr = DataGrabberData.new(0, 0, 0, Time.at(0).gmtime)
            start_time = ts[0]
          elsif (ts = get_timestamp(line, data_pattern)) then
            curr.run = ts[1][0]
            curr.assets = ts[1][1].to_i
            curr.units = ts[1][2].to_i
          elsif (ts = get_timestamp(line, end_pattern)) then
            curr.time = Time.at(ts[0] - start_time).gmtime
            data << curr
          end
        end
        return data
      end

      def analyze(data)
        unit_error_lvl = asset_error_lvl = 0
        if (data.units != UNITS) then
          unit_error_lvl = 1
        end
        if (data.units < 0.95*UNITS || data.units > 1.05*UNITS) then
          unit_error_lvl = 2
        end

        if (data.assets < 0.95*ASSETS || data.assets > 1.05*ASSETS) then
          asset_error_lvl = 1
        end
        if (data.assets < 0.90*ASSETS || data.assets > 1.10*ASSETS) then
          asset_error_lvl = 2
        end

        return [unit_error_lvl, asset_error_lvl].max
      end
       
      def html_output(data)
        ikko_data = {}
        ikko_data["id"] = @archive.base_name
        ikko_data["description_link"] = "grabber_description.html"
        tables = []
        data.each do |d|
          table_data = {}
          table_data["run"] = d.run
          table_data["assets"] = d.assets
          table_data["units"] = d.units
          table_data["time"] = d.time.strftime("%H:%M:%S")
          tables << @ikko["grabber_table.html", table_data]
        end
        ikko_data["tables"] = tables
        return @ikko["grabber.html", ikko_data]
      end

      def create_description
        ikko_data = {}
        ikko_data["name"]="Data Grabber Test"
        ikko_data["title"] = "Data Grabber Test Description"
        ikko_data["description"] = "Displays how much time the data grabber took along with the number of assets and units."
        success_table = {"success"=>"Exactly 1056 units and Assets within 5% of 22000",
                         "partial"=>"Units within 5% of 1056 and Assets within 10% of 22000",
                         "fail"=>"All other cases"}
        ikko_data["table"] = @ikko["success_template.html", success_table]
        return @ikko["description.html", ikko_data]
      end
    end
  end
end
