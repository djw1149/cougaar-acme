module ACME
  module Plugins
    
    class ArchiveMemoryData

      def initialize
        @data = {}
      end

      def []=(stage, node, value)
        if !(stage.nil? || node.nil?) then 
	  @data[stage] = {} if @data[stage].nil?
          @data[stage][node] = value
        end
      end
      
      def [](stage, node)
        return nil if @data[stage].nil?
        return @data[stage][node]
      end

      def stages
        return @data.keys.sort
      end
      
      def sorted_nodes
        return @data[stages.last].keys.sort{|x, y| @data[stages.last][y] <=> @data[stages.last][x]}
      end
  
      def nodes
        return @data[stages.last].keys
      end
    end


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
            all_data = []
            all_data << compile_memory_data(memory_files)
            group_pattern = Regexp.new("-#{@archive.group}-")
            @archive.get_prior_archives(60*60*24*365, group_pattern).each do |prior_name|
              prior_archive = @archive.open_prior_archive(prior_name)
              prior_memory_files = prior_archive.files_with_description(/Memory usage file/)
              all_data << compile_memory_data(prior_memory_files) unless prior_memory_files.empty?
              prior_archive.cleanup
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

      def compile_memory_data(memory_files)
        archive_data = ArchiveMemoryData.new
        memory_files.each do |file|
	  data = read_file(file.name)
          archive_data[data.stage, data.node_name] = data.memory
        end
        return archive_data
      end

      
      def read_file(filename)
        data = MemoryStructure.new
        stage = nil
        if filename =~ /memdata_(Stage.*)\// then          
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

      def average(all_data, stage, node)
        values = []
        total = 0
        all_data.each do |run_data|
          next if run_data[stage, node].nil?
          values << run_data[stage, node]
          total += values.last
        end
        return 0 if values.size == 0        
        return total/(values.size)
      end
        

      def html_output(all_data)
        run_data = all_data[0]
        ikko_data = {}
        ikko_data["id"] = @archive.base_name
        ikko_data["description_link"] = "memory_description.html"
        headers = ["Node"]
        headers << run_data.stages
        headers.flatten!
                
        row_string = ""
        headers.each do |header|
          row_string << @ikko["header_template.html", {"data"=>header}]
        end
        table_string = @ikko["row_template.html", {"data"=>row_string}]
       
        
        run_data.sorted_nodes.each do |node|
          row_string = @ikko["cell_template.html", {"data"=>node, "options"=>"ROWSPAN=2"}]
          run_data.stages.each do |stage|
            if (run_data[stage, node].nil?) then
              row_string << @ikko["cell_template.html", {"data"=>"NODE NOT PRESENT", "options"=>"BGCOLOR=#ff0000"}]
            else
              row_string << @ikko["cell_template.html", {"data"=>"#{run_data[stage, node]} MB", "options"=>"BGCOLOR=#DDDDDD"}]
            end
          end
          table_string << @ikko["row_template.html", {"data"=>row_string}]
          
          row_string = ""
          run_data.stages.each do |stage|
            row_string << @ikko["cell_template.html", {"data"=>"#{average(all_data, stage, node)} MB", "options"=>"BGCOLOR=#BBBBBB"}]
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
