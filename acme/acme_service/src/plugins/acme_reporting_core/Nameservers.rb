#!/usr/bin/ruby --

module ACME; module Plugins
  class Nameservers
    def initialize(archive, plugin, icko)
      @archive = archive
      @plugin = plugin
      @icko = icko
    end

    def perform
      line_RE =     /SelectManager - Selected server/
      time_RE =     /(\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d,\d\d\d) INFO/
      addr_RE =     /address=([^ ]*)/
      ave_RE =      /average=([0-9\.]*)/
      dev_RE =      /stdDev=([0-9\.]*)/
      score_RE =    /score ([0-9\.]*)/
      paddr_RE =    /was (.*)$/

      node_RE =     /\/([^\.\/]*)\./

      nameservers = {}

      @archive.add_report("WP", @plugin.plugin_configuration.name) do |report|
         report.open_file( "node_nameserver.html", "text/html", "Nameserver Usage" ) do |wn_html|
           wn_html.puts "<HTML><HEAD><TITLE>Nameserver Usage</TITLE></HEAD>"
           wn_html.puts "<BODY><H1>Nameserver Usage</H1>"

           detail_html = []
           detail_html << "<H2>Detailed Listing of Nameservers by Node</H2>"
           detail_html << "<TABLE><TR><TD><B>NODE</B></TD><TD><B>NAMESERVER</B></TD><TD><B>SCORE</B></TD><TD><B>TIME</B></TD></TR>"
           log_files = @archive.files_with_description(/Log4j/)

           log_files.each do |rk_file|
             begin
               file = File.new( rk_file.name )
               node = node_RE.match( rk_file.name )[1]
               last_ns = nil
                 
               file.each_line do |line|
                 if (line_RE.match( line )) then
                   time = time_RE.match( line )[1]
                   addr = addr_RE.match( line )[1]
                   ave = ave_RE.match( line )[1]
                   dev = dev_RE.match( line )[1]
                   score = score_RE.match( line )[1]
                   paddr = paddr_RE.match( line )[1]
                         
                   last_ns = addr
                       
                   detail_html << "<TR>"
                   detail_html << "<TD>#{node}</TD>"
                   detail_html << "<TD>#{addr}</TD>"
                   detail_html << "<TD>#{score}</TD>"
                   detail_html << "<TD>#{time}</TD>"
                   detail_html << "</TR>"
                 end
               end

               unless (last_ns.nil?) then
                 nameservers[last_ns] = [] if nameservers[last_ns].nil?
                 nameservers[last_ns] << node
               end
             rescue Exception => e
               puts "#{e}"
             end
           end  
 
           detail_html << "</TABLE>"

           wn_html.puts "<H2>Nodes by Nameserver</H2>"

           wn_html.puts "<TABLE><TR><TD><B>Nameserver</B></TD><TD><B>Node Count</B></TD><TD><B>Nodes</B></TD></TR>"

           nameservers.each_key do |key|
             wn_html.puts "<TR><TD>#{key}</TD><TD>#{nameservers[key].length}</TD><TD>#{nameservers[key].join(', ')}</TD></TR>"
           end
           wn_html.puts "</TABLE>"
           wn_html.puts "<HR />"
           wn_html.puts "#{detail_html.join(' ')}"

           wn_html.puts "</BODY></HTML>"
         end
       end
     end
   end
 end
end

