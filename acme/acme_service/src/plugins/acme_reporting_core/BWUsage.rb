#!/usr/bin/ruby --

module ACME; module Plugins
  class BWUsage
    def initialize( archive, plugin, icko )
      @archive = archive
      @plugin = plugin
      @icko = icko
    end

    def perform
      stages = []
      stages << "stage_1"
      stages << "stage_2"
      stages << "stage_3"
      stages << "stage_4"
      stages << "stages_3_4"
      stages << "stage_5"
      stages << "stage_6"
      stages << "stage_5_6"
      stages << "stage_7"
   
      @archive.add_report("BW", @plugin.plugin_configuration.name) do |report|
        report.open_file( "bw_usage.html", "text/html", "Bandwidth Usage by Stage") do |bw_html|
          bw_html.puts "<HTML><HEAD><TITLE>Bandwidth Usage by Stage</TITLE></HEAD>"
          bw_html.puts "<BODY><H1>Bandwidth Usage by Stage</H1>"

          stages.each do |stage|
            bw_html.puts "<H2>#{stage}</H2>"

            ns_files = @archive.files_with_description(/Network Status/)
            ns_files.delete_if { |rk_file| rk_file.name[ stage ].nil? }
 
            if (ns_files.empty?) then
              bw_html.puts "Stage #{stage} not run."
            else
              start_file = nil
              stop_file = nil
              ns_files.each do |rk_file|
                start_file = File.new( rk_file.name ) if rk_file.name =~ /during/
                stop_file = File.new( rk_file.name ) if rk_file.name =~ /after/
              end # ns_files.each

              if (start_file.nil? || stop_file.nil?) then
                bw_html.puts "Stage #{stage} not complete."
              else
                start_doc = REXML::Document.new( start_file )
                stop_doc = REXML::Document.new( stop_file )

                start_time_str = start_doc.elements["/network-information"].attributes["time"]
                stop_time_str = stop_doc.elements["/network-information"].attributes["time"]
                time_RE = /\w* (\w*) (\d*) (\d*):(\d*):(\d*) \w* (\d*)/

                match = time_RE.match( start_time_str )
                start_time = Time.gm( match[6].to_i, match[1], match[2].to_i, match[3].to_i, match[4].to_i, match[5].to_i )
                match = time_RE.match( stop_time_str )
                stop_time = Time.gm( match[6].to_i, match[1], match[2].to_i, match[3].to_i, match[4].to_i, match[5].to_i )
                delta_T = stop_time - start_time

                bw_html.puts "<TABLE>"
                bw_html.puts "<TR><TD><B>START TIME:</B></TD><TD>#{start_time}</TD></TR>"
                bw_html.puts "<TR><TD><B>END TIME:</B></TD><TD>#{stop_time}</TD></TR>"
                bw_html.puts "<TR><TD><B>DURATION:</B></TD><TD>#{delta_T} sec</TD></TR>"
                bw_html.puts "</TABLE>"

                bw_html.puts "<TABLE>"
                bw_html.puts "<TR><TD><B>HOST</B></TD>"
                bw_html.puts "    <TD><B>NIC</B></TD>"
                bw_html.puts "    <TD><B>DELTA_RX</B></TD>"
                bw_html.puts "    <TD><B>DELTA_TX</B></TD>"
                bw_html.puts "    <TD><B>MAX_BW</B></TD>"
                bw_html.puts "    <TD><B>RX_BW</B></TD>"
                bw_html.puts "    <TD><B>TX_BW</B></TD>"
                bw_html.puts "</TR>"

                host_list = start_doc.elements.to_a("/network-information/host").each do |hostL|
                  host = hostL.attributes["name"]

                  hostL.elements.to_a("./interface").each do |start_ifL|
                    start_if = start_ifL.attributes["name"]
                    in_RX = start_ifL.attributes["rx"].to_f
                    in_TX = start_ifL.attributes["tx"].to_f
                    max_BW = start_ifL.attributes["rate"]

                    xpath = "/network-information/host[@name='#{host}']/interface[@name='#{start_if}']"
                    stop_doc.elements.to_a(xpath).each do |stop_ifL|
                      out_RX = stop_ifL.attributes["rx"].to_f
                      out_TX = stop_ifL.attributes["tx"].to_f
                      delta_RX = (out_RX - in_RX)
                      delta_TX = (out_TX - in_TX)
                      bw_RX = sprintf("%1.2fKbit", (delta_RX/128) / delta_T)
                      bw_TX = sprintf("%1.2fKbit", (delta_TX/128) / delta_T)

                      bw_html.puts "<TR><TD>#{host}</TD>"
                      bw_html.puts "    <TD>#{start_if}</TD>"
                      bw_html.puts "    <TD>#{delta_RX}</TD>"
                      bw_html.puts "    <TD>#{delta_TX}</TD>"
                      bw_html.puts "    <TD>#{max_BW}</TD>"
                      bw_html.puts "    <TD>#{bw_RX}</TD>"
                      bw_html.puts "    <TD>#{bw_TX}</TD>"
                      bw_html.puts "</TR>"
                      
                    end # stop_ifL
                  end # start_ifL
                end # hostL
                bw_html.puts "</TABLE>"

              end # if files are nil else
            end # if (ns_files.empty?)
          end # stages

          bw_html.puts "</BODY>"
        end # report
      end # archive
    end # def perform
  end # class BWUsage
end; end
