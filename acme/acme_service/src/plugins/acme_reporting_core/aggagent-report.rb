require './plugins/acme_reporting_core/aggagent-parser'

module ACME; module Plugins
  class AggAgentReport
    def initialize(archive, plugin, ikko)
      @archive = archive
      @ikko = ikko
      @plugin = plugin
    end

    def perform
      run_log = @archive.files_with_name(/run\.log/)

      @archive.add_report("AggAgent", @plugin.plugin_configuration.name) do |report|
        report.open_file("aggagent.html", "text/html", "AggAgent Report") do |file|
          parser = AggAgentParser.new( File.open(run_log[0].name) )

          file.puts "<HTML><BODY>"

          file.puts "<H1>AggAgent Queries</H1>"
          file.puts "<H2>Runtimes</H2>"

          file.puts "<TABLE><TH>"
          parser.get_queries.each do |query|
            file.puts "<TD>#{query}</TD>"
          end
          file.puts "</TH>"

          total = 0
          overLimit = 0

          parser.get_sources.each do |source|
            file.puts "<TR>"
            file.puts "<TD>#{source}</TD>"
            parser.get_queries.each do |query|
              total = total + 1
              if (parser.get_time( query, source ) > 60) then
                file.puts "<TD color='red'>"
                overLimit = overLimit + 1
              else
                file.puts "<TD>"
              end           
              file.puts "#{parser.get_time(query, source)}</TD>"                             
            end
            file.puts "</TR>"          
          end
          file.puts "</TABLE></BODY></HTML>"

          if (overLimit == 0) then
            report.success
          else 
            if (overLimit > 0.05 * total) then
              report.failure
            else
              report.partial_success
            end
          end
        end
      end
    end
  end

end; end
