module ACME
  module Plugins
    
    class ArchiveMemoryData

      def initialize
        @data = {}
        @xmx = {}
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
        return @data.keys.sort {|x, y|
          x =~ /Stage([0-9]+)/
          x_stage = $1
          y =~ /Stage([0-9]+)/
          y_stage = $1
          (x_stage != y_stage) ? (x_stage <=> y_stage) : (x <=> y)
        }                      
      end
      
      def sorted_nodes
        return @data[stages.last].keys.sort
      end
  
      def nodes
        return @data[stages.last].keys
      end

      def xmx(node)
        return @xmx[node]
      end
 
      def set_xmx(node, val)
        @xmx[node] = val
      end
    end


    class MemoryReport
      
      MemoryStructure = Struct.new("MemoryStructure", :node_name, :memory, :stage)

      def initialize(archive, plugin, ikko, cm)
        @archive = archive
        @ikko = ikko
        @plugin = plugin
        @cm = cm
      end

      def perform
        memory_files = @archive.files_with_description(/Memory usage file/)
        node_files = @archive.files_with_description(/XML node config files/)
        if (!memory_files.empty?) then
          @archive.add_report("Mem", @plugin.plugin_configuration.name) do |report|
            all_data = []
            #get run data from the cache manager for the current run
            all_data <<  @cm.load(@archive.base_name, ArchiveMemoryData) do |name|
              compile_memory_data(memory_files, node_files)
            end

            avg_files = [@archive.base_name]
            group_pattern = Regexp.new("-#{@archive.group}-")
            @archive.get_prior_archives(60*60*24*365, group_pattern).each do |prior_name|
              avg_files << prior_name
              all_data << get_prior_data(prior_name)
            end
            all_data.compact!


            output = html_output(all_data)
            report.open_file("memory.html", "text/html", "Memory Report") do |file|
              file.puts output
            end

            output = create_avg_list(avg_files)
            report.open_file("avg_list.html", "text/html", "Archives used in averaging") do |file|
              file.puts output
            end
           
            output = create_description
            report.open_file("memory_description.html", "text/html", "Memory description") do |file|
              file.puts output
            end
            
            bad_nodes = check_out_of_memory
            if (bad_nodes.empty?) then
              report.success
            else
              report.open_file("out_of_memory.html", "text", "List of out of memory nodes") do |file|
                bad_nodes.each do |node| 
                  file.puts(node)
                end
              end
              report.failure
            end
          end
        end
      end

      def check_out_of_memory
        bad_files = []
        log_files = @archive.files_with_description(/Log4j node log/)
        log_files.each do |log_file|
          IO.foreach(log_file.name) do |line|
            if (line =~ /OutOfMemory/i) then
              bad_files << File.basename(log_file.name)
              break
            end
          end
        end
        return bad_files
      end


      def get_prior_data(prior_name)
        data = @cm.load(prior_name, ArchiveMemoryData) do |name|
          prior_archive = @archive.open_prior_archive(name)
          prior_memory_files = prior_archive.files_with_description(/Memory usage file/)
          tmp =  compile_memory_data(prior_memory_files) unless prior_memory_files.empty?
          prior_archive.cleanup
          tmp #black must return object of type ArchiveMemoryData
        end
        return data
      end

      def compile_memory_data(memory_files, node_files = [])
        archive_data = ArchiveMemoryData.new
        memory_files.each do |file|
	  data = read_memory_file(file.name)
          archive_data[data.stage, data.node_name] = data.memory
          node_pattern = Regexp.new("#{data.node_name}.xml")
          node_files.each do |node_file|
            if node_pattern.match(node_file.name)
              archive_data.set_xmx(data.node_name, get_xmx(node_file.name))
              break
            end
          end
        end
        return archive_data
      end

      def read_memory_file(filename)
        data = MemoryStructure.new
        stage = nil
        if filename =~ /memdata_(Stage.*?)\// then          
          stage = $1
        elsif filename =~ /memdata_(PreStage.*?)\// then
          stage = $1
        end
        file = IO.readlines(filename)
        data.node_name = file[0].strip!
        memory = file[4].gsub(/VmRSS:/, "").strip 
        memory =~ /([0-9]+)/
        memory = $1.to_i
        memory = memory / 1024 #convert to MB
        data.memory = memory
        data.stage = stage
        return data
      end

     def get_xmx(node_file)
       IO.readlines(node_file).each do |line|
         if (line =~ /-Xmx([0-9]+)m/)
           return $1.to_i
         end
       end
       return nil
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
        ikko_data["files_link"] = "avg_list.html"
        headers = run_data.stages
        headers << "Xmx"
              
        row_string = @ikko["header_template.html", {"data"=>"Node", "options"=>"COLSPAN=2"}]
        headers.each do |header|
          row_string << @ikko["header_template.html", {"data"=>header}]
        end
        table_string = @ikko["row_template.html", {"data"=>row_string}]
       
        
        run_data.sorted_nodes.each do |node|
          table_string << node_row_string(all_data, run_data, node)
        end

        ikko_data["table"] = table_string
        return @ikko["memory_report.html", ikko_data]
      end

      def node_row_string(all_data, run_data, node)
        table_string = ""
        row_string = @ikko["cell_template.html", {"data"=>node, "options"=>"ROWSPAN=3"}]
        row_string << @ikko["cell_template.html", {"data"=>"Used", "options"=>"BGCOLOR=#DDDDDD"}]
        run_data.stages.each do |stage|
          row_string << write_stage(run_data, node, stage)
        end
        row_string << write_xmx(run_data, node)
        table_string << @ikko["row_template.html", {"data"=>row_string}]
          
        row_string = @ikko["cell_template.html", {"data"=>"Avg", "options"=>"BGCOLOR=#BBBBBB"}]
        run_data.stages.each do |stage|
          row_string << @ikko["cell_template.html", {"data"=>"#{average(all_data, stage, node)} MB", "options"=>"BGCOLOR=#BBBBBB"}]
        end
        table_string << @ikko["row_template.html", {"data"=>row_string}]

        row_string = @ikko["cell_template.html", {"data"=>"Free", "options"=>"BGCOLOR=#999999"}]
        run_data.stages.each do |stage|
          row_string << write_free(run_data, node, stage)
        end
        table_string << @ikko["row_template.html", {"data"=>row_string}]
        return table_string
      end

      def write_stage(run_data, node, stage)
        str = ""
        if (run_data[stage, node].nil?) then
          str = @ikko["cell_template.html", {"data"=>"NODE NOT PRESENT", "options"=>"BGCOLOR=#ff0000"}]
        else
          str = @ikko["cell_template.html", {"data"=>"#{run_data[stage, node]} MB", "options"=>"BGCOLOR=#DDDDDD"}]
        end
        return str
      end

      def write_xmx(run_data, node)
        str = ""
        if run_data.xmx(node).nil? then
          str = @ikko["cell_template.html", {"data"=>"NODE NOT PRESENT", "options"=>"BGCOLOR=#ff0000"}]
        else
          str = @ikko["cell_template.html", {"data"=>"#{run_data.xmx(node)} MB", "options"=>"BGCOLOR=#DDDDDD ROWSPAN=3"}]
        end
        return str   
      end

      def write_free(run_data, node, stage)
        str = ""
        if run_data.xmx(node).nil?  || run_data[stage, node].nil? then
          str = @ikko["cell_template.html", {"data"=>"NODE NOT PRESENT", "options"=>"BGCOLOR=#ff0000"}]
        else
          str = @ikko["cell_template.html", {"data"=>"#{run_data.xmx(node) - run_data[stage, node]} MB", "options"=>"BGCOLOR=#999999"}]
        end
        return str
      end

      def create_avg_list(avg_files)
        return @ikko["avg_list.html", {"files"=>avg_files}]
      end

      def create_description
        ikko_data = {}
        ikko_data["name"]="Memory Report"
        ikko_data["title"] = "Memory Report Description"
        ikko_data["description"] = "Displays how much memory each node is using at each stage.  The top entry is the usage for the current run."
        ikko_data["description"] <<"  The bottome entry is the average usage over all runs in the group."

        success_table = {"success"=>"No out of memory errors detected",
                         "partial"=>"not used",
                         "fail"=>"At least one out of memory error"}
        ikko_data["table"] = @ikko["success_template.html", success_table]
        return @ikko["description.html", ikko_data]
      end
    end
  end
end
