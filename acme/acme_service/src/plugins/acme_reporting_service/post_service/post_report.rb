#!/usr/local/bin/ruby

require 'index_manager'

PATH = File.join(File.dirname(__FILE__), 'societies') 

if ENV['REQUEST_METHOD'] == "POST"
  paths = ENV['PATH_INFO'].split('/')
  host = paths[1] 
  archive = paths[2]
  debug = []
  if host && archive
    host_path = File.join(PATH, host)
    archive_path = File.join(host_path, archive)
    report_archive = File.join(archive_path, "reports.tgz")
    
    begin
      unless File.exist?(host_path)
        debug << `mkdir #{host_path}`
      end
      unless  File.exist?(archive_path)
        debug << `mkdir #{archive_path}` 
      end
      File.open(report_archive, "w") do |file|
        file.write($stdin.read)
      end
     
      debug << `tar -C #{archive_path} --same-owner -xzf #{report_archive}`
      debug << `rm -f #{report_archive}`
      begin
        IndexManager.new(File.dirname(__FILE__))
      rescue
        debug << $!.to_s
        debug << $!.backtrace.join("\n")
      end

      puts "Content-Type: text/plain"
      puts ""
      puts "SUCCESS"   # + ":\n" + debug.join("\n")
    rescue
      puts "Content-Type: text/plain"
      puts "" 
      puts "FAILURE - could not write report\n" + $! + "\n"+ $!.backtrace.join("\n")+
        "\nhost_path=#{host_path}\n"+
        "archive_path=#{archive_path}\n"+
        "report_archive=#{report_archive}"
    end
  else
    puts "Content-Type: text/plain"
    puts "" 
    puts "FAILURE - malformed uri: /post_report.rb/<host>/<experiment>"
  end
else
    puts "Content-Type: text/html"
    puts "" 
    puts "<html><body><h1>Only works with HTTP POST.</h1></html>"
end
