module ACME
  module Plugins

    class AgentCompletionData
      attr_accessor :error
      attr_reader :name
        
      def initialize (name)
        @name = name
        @comp_data = {}
        @error = CompletionTest::SUCCESS
      end
        
      def []=(tag, value)
        @comp_data[tag]=value
      end
        
      def [](tag)
        return @comp_data[tag]
      end
        
      def <=>(rhs)
        return rhs.error <=> @error if (@error != rhs.error)
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
        comp_files.uniq.each do |comp_file|
          benchmark_pattern = Regexp.new(File.basename(comp_file.name))
          benchmark_file = baseline.files_with_name(benchmark_pattern)[0]
          report_name = File.basename(comp_file.name, ".xml")

          @archive.add_report(report_name, @plugin.plugin_configuration.name) do |report|
            data = get_file_data(File.new(comp_file.name))
            next if data.agents.empty?
            
            benchmark_data = nil
            benchmark_data = get_file_data(File.new(benchmark_file.name)) unless benchmark_file.nil?
            result = analyze(data, benchmark_data)
            data.agents.sort! #analyze function may change ordering if agents fail
        
            if result == SUCCESS then
              report.success
            elsif result == PARTIAL then
              report.partial_success
            else
              report.failure
            end
            output = html_output(data, report_name, baseline_name)
            outfile = "Comp-#{report_name}.html"
            report.open_file(outfile, "text/html", "Agent completion tests for #{report_name}") do |file|
              file.puts output
            end

            output = create_description
            report.open_file("comp_description.html", "text/html", "Completion Report Description") do |file|
              file.puts output
            end
          end
        end
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
        error = (benchmark.nil? ? PARTIAL : SUCCESS)
        e = ratio_test(data)
        error = (error > e ? error : e)
        if (!benchmark.nil?) then
          e = task_test(data, benchmark)
          error = (error > e ? error : e)
        end
        return error
      end
     
      def ratio_test(data)
        error = SUCCESS
        data.agents.each do |agent|
          if (agent["Ratio"] < 1.0 && agent["Ratio"] >= 0.90) then
            error = PARTIAL if error == SUCCESS
            agent.error = PARTIAL if agent.error == SUCCESS
          elsif (agent["Ratio"] < 0.90) then
            error = FAIL
            agent.error = FAIL
          end
        end
        return error
      end
      
      def task_test(data, benchmark)
        error = SUCCESS
        data.agents.each do |agent|
          benchmark_agent = (benchmark.agents.collect{|x| agent.name == x.name ? x : nil}.compact)[0]
          next if benchmark_agent.nil?
          low_bound = (benchmark_agent["NumTasks"] * (1 - TOLERENCE)).to_i
          if agent["NumTasks"] < low_bound then
            error = FAIL
            agent.error = FAIL
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
        
        table_string = @ikko["row_template.html", {"data"=>header_row,"options"=>""}]
        data.agents.each do |agent|
          agent_row = @ikko["cell_template.html", {"data"=>agent.name,"options"=>""}]
          fields.each do |key|
            agent_row << @ikko["cell_template.html", {"data"=>agent[key],"options"=>""}]
          end
          options = ""
          if (agent.error == SUCCESS) then
            options << "BGCOLOR=#00DD00"
          elsif (agent.error == PARTIAL) then
            options << "BGCOLOR=#FFFF00"
          else
            options << "BGCOLOR=#FF0000"
          end
          table_string << @ikko["row_template.html", {"data"=>agent_row,"options"=>options}]
        end
        ikko_data["table"] = table_string
        return @ikko["comp_report.html", ikko_data]
      end

      def create_description
        ikko_data = {}
        ikko_data["name"]="Completion Report"
        ikko_data["title"] = "Completion Report Description"
        ikko_data["description"] = "Creates a table from the information in completion report xml files.  Currently the test"
        ikko_data["description"] << " is based on the tasks and ratio fields.  An agent is green if it has a ratio of 1.0 and "
        ikko_data["description"] << "is within 10% of the baseline number of tasks.  An agent is yellow is it has a ratio of"
        ikko_data["description"] << " at least 0.95 and is within 10% of the baseline tasks.  An agent is red otherwise."
        ikko_data["description"] << " If the appropriate benchmark file can not be found because the subject file is named"
        ikko_data["description"] << " in a nonstandard way, then the number of tasks test will not be run.  In this case"
        ikko_data["description"] << " the report will be at most PARTIAL SUCCESS."

        success_table = {"success"=>"Every agent has a ratio of 1.0 and is within 10% of the baseline",
                         "partial"=>"Baseline missing or at least one agent is yellow as described above and none are red",
                         "fail"=>"At least one agent has a ratio less than 0.90 or is not within 10% of the baseline"}
        ikko_data["table"] = @ikko["success_template.html", success_table]
        return @ikko["description.html", ikko_data]
      end

    end
  end
end
