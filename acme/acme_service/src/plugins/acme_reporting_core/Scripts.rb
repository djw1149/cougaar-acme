#!/usr/bin/ruby --

module ACME; module Plugins
  class Scripts
    def initialize(archive, plugin, icko)
      @archive = archive
      @plugin = plugin
      @icko = icko
    end

    def perform
      @archive.add_report("Def", @plugin.plugin_configuration.name) do |report|
         report.open_file( "scripts.html", "text/html", "Scripts" ) do |wn_html|
           def_files = @archive.files_with_description(/Experiment/)
           def_files.each do |rk_file|
             wn_html.puts "<HTML><HEAD><TITLE>Scripts</TITLE></HEAD>"
             wn_html.puts "<BODY><H3>Definition File: #{rk_file.name}</H3>"
	     wn_html.puts "<HR>"
	     wn_html.puts "<PRE>"
	     file = File.new( rk_file.name )
	     file.each_line do |line|
	       wn_html.puts "#{line}"
             end
             wn_html.puts "</PRE>"
             wn_html.puts "<HR>"
           end
           tplate = @archive.files_with_description(/Main/)
           tplate.each do |rk_file|
             wn_html.puts "<HR>"
             wn_html.puts "<H3>Template File: #{rk_file.name}</H3>"
             wn_html.puts "<HR>"
	     wn_html.puts "<PRE>"
             file = File.new( rk_file.name )
             file.each_line do |line|
               wn_html.puts "#{line}"
             end
             wn_html.puts "<HR></PRE>"
             wn_html.puts "</BODY></HTML>"
           end
         end
       end
     end
   end
 end
end

