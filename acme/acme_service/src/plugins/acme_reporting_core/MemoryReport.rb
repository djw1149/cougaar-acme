module ACME
  module Plugins
    
    class MemoryReport
      
      MemoryStructure = Struct.new("MemoryStructure", :node_name, :memory, :stage)

      def initialize(archive, plugin, ikko)
        @archive = archive
        @ikko = ikko
        @plugin = plugin
      end

      def perform
        memory_files = @archive.files_with_description(/Memory usage file/)
        if (!memory_files.empty?) then
          @archive.add_report("Memory", @plugin.plugin_configuration.name) do |report|
            all_data = {}
            memory_files.each do |file|
              data = read_file(file.name)
              if all_data[data.stage].nil? then
                all_data[data.stage] = {}
              end
              all_data[data.stage][data.node_name] = data
            end
            output = html_output(all_data)
            report.open_file("memory.html", "text/html", "Memory Report") do |file|
              file.puts output
            end

            output = create_description
            report.open_file("memory_description.html", "text/html", "Memory description") do |file|
              file.puts output
            end
            
            report.success
          end
        end
      end

      def all_nodes(all_data)
        nodes = []
        all_data.each_value do |stage_data|
          nodes |= stage_data.keys
        end
        return nodes.sort{|x, y| all_data[last_stage(all_data)][y].memory <=> all_data[last_stage(all_data)][x].memory}
      end

      def last_stage(all_data)
        return all_data.keys.sort.last
      end

      def read_file(filename)
        data = MemoryStructure.new
        stage = nil
        if filename =~ /(Stage.*)\// then
          stage = $1
        end
        file = IO.readlines(filename)
        data.node_name = file[0]
        memory = file[4].gsub(/VmRSS:/, "").strip 
        memory =~ /([0-9]+)/
        memory = $1.to_i
        memory = memory / 1024 #convert to MB
        data.memory = memory
        data.stage = stage
        return data
      end

      def html_output(all_data)
        ikko_data = {}
        ikko_data["id"] = @archive.base_name
        ikko_data["description_link"] = "memory_description.html"
        headers = ["Node"]
        all_data.keys.sort.each do |stage|
          headers << stage
        end       
        
        row_string = ""
        headers.each do |header|
          row_string << @ikko["header_template.html", {"data"=>header}]
        end
        table_string = @ikko["row_template.html", {"data"=>row_string}]
       
        all_nodes(all_data).each do |node|
          row_string = @ikko["cell_template.html", {"data"=>node}]
          all_data.keys.sort.each do |stage|
            if (all_data[stage][node].nil?) then
              row_string << @ikko["cell_template.html", {"data"=>"NODE NOT PRESENT", "options"=>"BGCOLOR=#ff0000"}]
            else
              row_string << @ikko["cell_template.html", {"data"=>"#{all_data[stage][node].memory} MB"}]
            end
          end
          table_string << @ikko["row_template.html", {"data"=>row_string}]
        end
        ikko_data["table"] = table_string
        return @ikko["memory_report.html", ikko_data]
      end

      def create_description
        ikko_data = {}
        ikko_data["name"]="Memory Report"
        ikko_data["title"] = "Memory Report Description"
        ikko_data["description"] = "Displays how much memory each node is using at each stage"
        success_table = {"success"=>"Currently this report is always successful",
                         "partial"=>"not used",
                         "fail"=>"not used"}
        ikko_data["table"] = @ikko["success_template.html", success_table]
        return @ikko["description.html", ikko_data]
      end
    end
  end
end
