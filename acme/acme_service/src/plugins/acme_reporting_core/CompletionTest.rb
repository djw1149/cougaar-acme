module ACME
  module Plugins

    class AgentCompletionData

      attr_reader :name, :error, :failed_fields, :partial_fields
        
      def initialize (name)
        @name = name
        @comp_data = {}
        @error = CompletionTest::SUCCESS
        @failed_fields = []
        @partial_fields = []
      end

      def []=(tag, value)
        @comp_data[tag]=value
      end
        
      def [](tag)
        return @comp_data[tag]
      end
        
      def <=>(rhs)
        return @name <=> rhs.name
      end
        
      def get_fields
        fields = []
        fields << "NumTasks"
        fields << "Ratio"
        @comp_data.keys.sort.each do |field|
          fields << field unless fields.include?(field)
        end
        return fields
      end

      def set_error(field, lvl)
        @failed_fields << field if lvl == CompletionTest::FAIL
        @partial_fields << field if lvl == CompletionTest::PARTIAL
        @error = lvl if @error < lvl
      end

      def field_level(field)
        return CompletionTest::FAIL if @failed_fields.include?(field)
        return CompletionTest::PARTIAL if @partial_fields.include?(field)
        return CompletionTest::SUCCESS
      end
    end
                       
    class CompletionTest

      SUCCESS = 0
      PARTIAL = 1
      FAIL = 2
      

      FileData = Struct.new("FileData", :agents, :totals)
      TOLERENCE = 0.10

      def initialize(archive, plugin, ikko)
        @archive = archive
        @plugin = plugin
        @ikko = ikko
      end
      
      def perform
        comp_files = @archive.files_with_description(/completion/)
        baseline_name = @archive.group_baseline
        baseline = @archive.open_prior_archive(baseline_name)
        baseline_name = "Missing Baseline" if baseline.nil?
    
        if comp_files.size > 0 then
          @archive.add_report("COMP", @plugin.plugin_configuration.name) do |report|
            result = SUCCESS
            comp_files.uniq.each do |comp_file|
              benchmark_pattern = Regexp.new(File.basename(comp_file.name))
              benchmark_file = nil
              benchmark_file = baseline.files_with_name(benchmark_pattern)[0] unless baseline.nil?
              data = get_file_data(File.new(comp_file.name))
              next if data.agents.empty?
              
              benchmark_data = nil
              benchmark_data = get_file_data(File.new(benchmark_file.name)) unless benchmark_file.nil?
            
              r = analyze(data, benchmark_data)
              result = r if result < r           

              outfile = "C-#{File.basename(comp_file.name, ".xml").gsub(/[^A-Z0-9]/, "")}"
              outfile += "-#{result_string(result)}.html"
              output = html_output(data, outfile, baseline_name)
              report.open_file(outfile, "text/html", "Agent completion test") do |file|
                file.puts output
              end
            end
            if result == SUCCESS then
              report.success
            elsif result == PARTIAL then
              report.partial_success
            else
              report.failure
            end
            output = create_description
            report.open_file("comp_description.html", "text/html", "Completion Report Description") do |file|
              file.puts output
            end
          end
        end
      end

      def result_string(r)
        str = "FAIL"
        if r == SUCCESS
          str = "SUCCESS"
        elsif r == PARTIAL
          str == "PARTIAL_SUCCESS"
        end
        return str
      end
  
      def get_file_data(file)
        data = FileData.new([], {})
        curr_agent = nil
        file.each do|line|
          if line =~ /agent=/ then
            line.chomp!
            agent_name = line.split(/=/)[1]
            agent_name.delete!("\'>")
            curr_agent = AgentCompletionData.new(agent_name)
          elsif (line =~ /<(.+)>(.+)<\/\1>/) then
            if !curr_agent.nil? then
              if ($1 == "Ratio") then
                curr_agent[$1] = $2.to_f
              elsif ($1 == "TimeMillis") then
                curr_agent["Time"] = Time.at($2.to_i/1000).strftime("%b/%d/%Y-%H:%M:%S")
              else
                curr_agent[$1] = $2.to_i
              end
            else
              data.totals[$1] = $2.to_i
            end
          elsif line =~ /\/SimpleCompletion/ then
            data.agents << curr_agent            
            curr_agent = nil
          end
        end
        data.agents.sort!
        return data
      end

      def analyze(data, benchmark)
        error = (benchmark.nil? ? PARTIAL : SUCCESS) #if there's no benchmark allow partial success at best
        e = ratio_test(data)
        error = (error > e ? error : e)
        if (!benchmark.nil?) then
          e = field_test("NumRootProjectSupplyTasks", data, benchmark, 0, 0.10)
          error = (error > e ? error : e)
          e = field_test("NumRootSupplyTasks", data, benchmark, 0, 0.10)
          error = (error > e ? error : e)
          e = field_test("NumRootTransportTasks", data, benchmark, 0, 0.10)
          error = (error > e ? error : e)
        end
        return error
      end     

      def ratio_test(data)
        error = SUCCESS
        data.agents.each do |agent|
          if (agent["Ratio"] < 1.0 && agent["Ratio"] >= 0.95) then
            error = PARTIAL if error == SUCCESS
            agent.set_error("Ratio", PARTIAL)
          elsif (agent["Ratio"] < 0.95) then
            error = FAIL
            agent.set_error("Ratio", FAIL)
          end
        end
        return error
      end
      
     def field_test(field, data, benchmark, pass_tol, partial_tol)
        error = SUCCESS
        data.agents.each do |agent|
          benchmark_agent = (benchmark.agents.collect{|x| agent.name == x.name ? x : nil}.compact)[0]
          next if benchmark_agent.nil?
          low_pass_bound = (benchmark_agent[field] * (1 - pass_tol)).to_i
          up_pass_bound = (benchmark_agent[field] * (1 + pass_tol)).to_i
          low_partial_bound = (benchmark_agent[field] * (1 - partial_tol)).to_i
          up_partial_bound = (benchmark_agent[field] * (1 + partial_tol)).to_i
          pass_range = Range.new(low_pass_bound, up_pass_bound)
          partial_range = Range.new(low_partial_bound, up_partial_bound)
          
          if (!partial_range.include?(agent[field])) then
            error = FAIL
            agent.set_error(field, FAIL)
          elsif (!pass_range.include?(agent[field])) then
            error = PARTIAL if error == SUCCESS
            agent.set_error(field, PARTIAL)
          end
        end
        return error
      end

      def html_output(data, stage, baseline)
        ikko_data = {}
        ikko_data["description_link"] = "comp_description.html"
        ikko_data["stage"] = stage
        ikko_data["baseline"] = baseline
        ikko_data["id"] = @archive.base_name
        ikko_data["totals"] = []
        data.totals.each_key do |key|
          ikko_data["totals"] << "#{key}:  #{data.totals[key]}"        
        end
        headers = ["Agent Name"]
        fields = data.agents[0].get_fields
        headers << fields
        headers.flatten!
        header_row = ""
        headers.each do |header|
          header_row << @ikko["header_template.html", {"data"=>header.gsub(/Num/, ""),"options"=>""}]
        end
        ikko_data["bad"] = create_bad_table(data.agents, fields, header_row)        
        ikko_data["table"] = create_full_table(data.agents, fields, header_row)        

        return @ikko["comp_report.html", ikko_data]
      end

      def color(agent, field)
        lvl = FAIL
        if (field == "NAME") then
          lvl = agent.error
        else
          lvl = agent.field_level(field)
        end

        return "BGCOLOR=#00DD00" if lvl == SUCCESS
        return "BGCOLOR=#FFFF00" if lvl == PARTIAL
        return "BGCOLOR=#FF0000"
      end

      def create_agent_row(agent, fields)
        agent_row = @ikko["cell_template.html", {"data"=>agent.name,"options"=>color(agent, "NAME")}]
        fields.each do |key|
          val = agent[key]
          val = sprintf("%.4f", val) if val.class.name == "Float"
          agent_row << @ikko["cell_template.html", {"data"=>val,"options"=>color(agent, key)}]
        end
        return agent_row
      end

      def create_bad_table(agents, fields, header_row)
        table_string = @ikko["row_template.html", {"data"=>header_row,"options"=>""}]
        bad_agents = agents.collect{|x| (x.error != SUCCESS ? x : nil)}
        bad_agents.compact!
        return "" if bad_agents.empty?
        bad_agents.each do |agent|
          agent_row = create_agent_row(agent, fields)
          table_string << @ikko["row_template.html", {"data"=>agent_row,"options"=>""}]
        end
        return table_string
      end

      def create_full_table(agents, fields, header_row)
        table_string = @ikko["row_template.html", {"data"=>header_row,"options"=>""}]
        agents.each do |agent|
          agent_row = create_agent_row(agent, fields)
          table_string << @ikko["row_template.html", {"data"=>agent_row,"options"=>""}]
        end
        return table_string
      end


      def create_description
        ikko_data = {}
        ikko_data["name"]="Completion Report"
        ikko_data["title"] = "Completion Report Description"
        ikko_data["description"] = "Creates a table from the information in completion report xml files.  Currently the test"
        ikko_data["description"] << " is based on the ratio plus the RootProjectSupplyTasks, RootSupplyTasks, and RootTransportTasks fields."
        ikko_data["description"] << " An agent is green if it has a ratio of 1.0 and exactly matches the baseline in the root task fields."
        ikko_data["description"] << " An agent is yellow is it has a ratio of at least 0.95 and is within 10% of the baseline in the root"
        ikko_data["description"] << " task fields.  An agent is red if the ratio is less than 0.95 or varies by greater than 10% from the"
        ikko_data["description"] << " baseline in a root task field.  If the benchmark cannot be found, the root task tests will not be run"
        ikko_data["description"] << " and the report will be at most PARTIAL SUCCESS."

        success_table = {"success"=>"Every agent has a ratio of 1.0 and matches the baseline in all root task fields",
                         "partial"=>"Baseline missing or every agent has ratio of at least 0.95 and is within 10% of the baseline in all root task fields",
                         "fail"=>"All other cases"}
        ikko_data["table"] = @ikko["success_template.html", success_table]
        return @ikko["description.html", ikko_data]
      end

    end
  end
end
