#!/usr/local/bin/ruby

PATH = File.join(File.dirname(__FILE__), 'societies') 

if ENV['REQUEST_METHOD'] == "POST"
  paths = ENV['PATH_INFO'].split('/')
  host = paths[1] 
  archive = paths[2]
  if host && archive
    host_path = File.join(PATH, host)
    archive_path = File.join(host_path, archive)
    report_archive = File.join(archive_path, "reports.tgz")
    
    begin
      unless File.exist?(host_path)
        `mkdir #{host_path}` 
        `chmod g+w #{host_path}`
      end
      `mkdir #{archive_path}` unless File.exist?(archive_path)
      File.open(report_archive, "w") do |file|
        file.write($stdin.read)
      end
      `tar -C #{archive_path} -xzf #{report_archive}`
      `rm -f #{report_archive}`
      `chmod g+w #{archive_path} --recursive`
      puts "Content-Type: text/plain"
      puts ""
      puts 'SUCCESS'
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