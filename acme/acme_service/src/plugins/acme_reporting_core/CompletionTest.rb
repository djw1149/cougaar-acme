module ACME
  module Plugins

    class CompletionTest
      AgentData = Struct.new("AgentData", :name, :comp_data, :error)
      FileData = Struct.new("FileData", :agents, :totals)
      SUCCESS = 0
      PARTIAL = 1
      FAIL = 2

      def initialize(archive, plugin, ikko)
        @archive = archive
        @plugin = plugin
        @ikko = ikko
      end
      
      def perform
        comp_files = @archive.files_with_description(/completion/)
        comp_files.each do |comp_file|
          report_name = File.basename(comp_file.name, ".xml")
          report_name.gsub!(/comp_/, "")
          
          @archive.add_report(report_name, @plugin.plugin_configuration.name) do |report|
            data = get_file_data(File.new(comp_file.name))
            result = analyze(data)
            if result == SUCCESS then
              report.success
            elsif result == PARTIAL then
              report.partial_success
            else
              report.failure
            end
            output = html_output(data, report_name)
            outfile = "Comp-#{report_name}.html"
            report.open_file(outfile, "text/html", "Agent completion tests for #{report_name}") do |file|
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
            curr_agent = AgentData.new(agent_name, {}, SUCCESS)
          elsif (line =~ /<(.+)>(.+)<\/\1>/) then
            if !curr_agent.nil? then
              if ($1 == "Ratio") then
                curr_agent.comp_data[$1] = $2.to_f
              else
                curr_agent.comp_data[$1] = $2.to_i
              end
            else
              data.totals[$1] = $2.to_i
            end
          elsif line =~ /\/SimpleCompletion/ then
            data.agents << curr_agent            
            curr_agent = nil
          end
        end

        return data
      end

      def analyze(data)
        error = SUCCESS
        e = ratio_test(data)
        error = (error > e ? error : e)
        e = task_test(data)
        error = (error > e ? error : e)

        return error
      end
      
      def ratio_test(data)
        error = SUCCESS
        data.agents.each do |agent|
          if (agent.comp_data["Ratio"] < 1.0 && agent.comp_data["Ratio"] >= 0.90) then
            error = PARTIAL if error == SUCCESS
            agent.error = PARTIAL if agent.error == SUCCESS
          elsif (agent.comp_data["Ratio"] < 0.90) then
            error = FAIL
            agent.error = FAIL
          end
        end
        return error
      end
      
      def task_test(data)
        error = SUCCESS
        data.agents.each do |agent|
          if agent.comp_data["NumTasks"] < 100 then
            error = FAIL
            agent.error = FAIL
          end
        end
        return error
      end

      def html_output(data, stage)
        ikko_data = {}
        ikko_data["stage"] = stage
        ikko_data["totals"] = []
        data.totals.each_key do |key|
          ikko_data["totals"] << "#{key}:  #{data.totals[key]}"        
        end
        headers = ["Agent Name"]
        headers << data.agents[0].comp_data.keys.sort
        headers.flatten!
        header_row = ""
        headers.each do |header|
          header_row << @ikko["header_template.html", {"data"=>header,"options"=>""}]
        end
        
        table_string = @ikko["row_template.html", {"data"=>header_row,"options"=>""}]
        data.agents.each do |agent|
          agent_row = @ikko["cell_template.html", {"data"=>agent.name,"options"=>""}]
          agent.comp_data.keys.sort.each do |key|
            agent_row << @ikko["cell_template.html", {"data"=>agent.comp_data[key],"options"=>""}]
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
    end
  end
end
