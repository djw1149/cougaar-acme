module ACME
  module Plugins
    
    class AgagentReport
      
      AggQueryData = Struct.new("AgagentData", :name, :time)

      def initialize(archive, plugin, ikko)
        @archive = archive
        @ikko = ikko
        @plugin = plugin
      end

      def perform
        run_log = @archive.files_with_name(/run\.log/)
        all_data = get_agagent_data(run_log[0].name)
        if (!all_data.empty?) then
          @archive.add_report("Agg", @plugin.plugin_configuration.name) do |report|
            output = html_output(all_data)
            report.open_file("agagent.html", "text/html", "Agagent Report") do |file|
              file.puts output
            end

            output = create_description
            report.open_file("agagent_description.html", "text/html", "Agagent description") do |file|
              file.puts output
            end
            report.success
          end
        end
      end

      def get_agagent_data(run_log)
        return [] unless File.exist?(run_log)
        data = []
        IO.readlines(run_log).each do |line|
          if (line =~ /AggQuery(.*?) in ([0-9]+) seconds/) then
            data << AggQueryData.new($1, $2.to_i)
          elsif (line =~ /DoParalellAggQueries in ([0-9]+)/) then
            data << AggQueryData.new("Paralell Queries", $1.to_i)
          end
        end
        return data
      end

      def total_time(all_data)
        total = 0
        all_data.each do |agagent|
          total += agagent.time
        end
        return total
      end

      def html_output(all_data)
        ikko_data = {}
        ikko_data["id"] = @archive.base_name
        ikko_data["description_link"] = "agagent_description.html"
        headers = ["Agent", "Time"]
                
        row_string = ""
        headers.each do |header|
          row_string << @ikko["header_template.html", {"data"=>header}]
        end
        table_string = @ikko["row_template.html", {"data"=>row_string}]
       
        all_data.each do |agagent|
          row_string = @ikko["cell_template.html", {"data"=>agagent.name}]
          row_string << @ikko["cell_template.html", {"data"=>agagent.time}]
          table_string << @ikko["row_template.html", {"data"=>row_string}]
        end
        row_string = @ikko["cell_template.html", {"data"=>"Total"}]
        row_string << @ikko["cell_template.html", {"data"=>total_time(all_data)}]
        table_string << @ikko["row_template.html", {"data"=>row_string}]

        ikko_data["table"] = table_string
        return @ikko["agagent_report.html", ikko_data]
      end

      def create_description
        ikko_data = {}
        ikko_data["name"]="Agagent Report"
        ikko_data["title"] = "Agagent Description"
        ikko_data["description"] = "Displays how much time each agagent query takes."
        success_table = {"success"=>"Currently this report is always successful",
                         "partial"=>"not used",
                         "fail"=>"not used"}
        ikko_data["table"] = @ikko["success_template.html", success_table]
        return @ikko["description.html", ikko_data]
      end
    end
  end
end
