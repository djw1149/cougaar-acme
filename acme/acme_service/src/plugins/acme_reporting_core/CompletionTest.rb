module ACME
  module Plugins
    class CompletionTest
      def initialize(archive, plugin, ikko)
        @archive = archive
        @plugin = plugin
        @ikko = ikko
      end
      
      def perform
        comp_files = @archive.files_with_description(/completion/)
        comp_files.each do |comp_file|
          @archive.add_report("Completion test for file #{comp_file.name}", @plugin.plugin_configuration.name) do |report|
            data = get_file_data(File.new(comp_file.name))
            result = analyze(data)
            if result == 0 then
              report.success
            elsif result == 1 then
              report.partial_success
            else
              report.failure
            end
            output = html_output(data, comp_file.name)
            outfile = comp_file.name.split(/\//).last.split(/\./)[0]
            report.open_file("completionTest-#{outfile}.html", "text/html", "Agent completion tests") do |file|
              file.puts output
            end
          end
        end
      end
  
      def get_file_data(file)
        data = {}
        agent = nil
        file.each do|line|
          if line =~ /agent=/ then
            line.chomp!
            agent = line.split(/=/)[1]
            agent.delete!("\'>")
            data[agent] = {}
          elsif (line =~ /<(.+)>(.+)<\/\1>/) then
            if !agent.nil? then
              if ($1 == "Ratio") then
                data[agent][$1] = $2.to_f
              else
               data[agent][$1] = $2.to_i
              end
            else
              data[$1] = $2.to_i
            end
          elsif line =~ /\/SimpleCompletion/ then
            agent = nil
          end
        end
        return data
      end

      def analyze(data)
        error = 0
        e = ratio_test(data)
        error = (error > e ? error : e)
        return error
      end
      
      def ratio_test(data)
        error = 0
        data.each_key do |agent|
          next unless data[agent].class.to_s == "Hash"
          error = 1 if (error == 0 && data[agent]["Ratio"] < 1.0 && data[agent]["Ratio"] >= 0.90) 
          error = 2 if data[agent]["Ratio"] < 0.90
        end
        return error
      end
      
      def html_output(data, file)
        str = ""
        str << "<HTML>\n"
        str << "<TABLE border=\"1\">\n"
        str << "<CAPTION>\n"
        str << "Completion test for the file:  #{file.split(/\//).last}\n"
        str << "</CAPTION>\n"
        str << "<TR><TD>Agent"
        
        #Examine an arbitrary agent and pull out the field names"
        data.keys.each do |key|
          if data[key].class.to_s == "Hash" then
            data[key].keys.sort.each do |field|
              str << "<TD>#{field}"
            end
            break
          end
        end
        str << "\n"
        data.keys.sort.each do |agent|
          if (data[agent].class.to_s == "Hash") then
            str << agent_html(data[agent], agent)
            str << "\n"
          end
        end
        str << "</TABLE>\n"
        str << "<BR>\n"
        str << "<b>"
        data.keys.sort.each do |field|
          if (data[field].class.to_s != "Hash") then
            str << "#{field}:  #{data[field]}\n"
            str << "<BR>\n"
          end
        end
        str << "</b>\n"
        str << "</HTML>\n"
        return str
      end
      
      def agent_html(data, agent)
        set = ""
        if (data["Ratio"] == 1.0) then
          set << "<TR BGCOLOR=#00FF00><TD>"
        elsif (data["Ratio"] >= 0.90) then
          set << "<TR BGCOLOR=#FFFF00><TD>"
        else
          set << "<TR BGCOLOR=#FF0000><TD>"
        end
        set << agent.to_s
        data.keys.sort.each do |field|
          set << "<TD>#{data[field]}"
        end
        return set
      end
    end
  end
end
