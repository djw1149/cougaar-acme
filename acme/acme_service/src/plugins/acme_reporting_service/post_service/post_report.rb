#!/usr/local/bin/ruby

require 'ikko'

PATH = File.join(File.dirname(__FILE__), 'societies') 

class Experiment
  attr_accessor :time, :path
  def initialize(time, path)
    @time, @path = time, path
  end
  def <=>(other)
    other.time<=>@time
  end
  
  def date
    year = @time[0,4].to_i
    month = @time[4,2].to_i
    day = @time[6,2].to_i
    Time.mktime(year, month, day).strftime("%A - %B %d, %Y")
  end
end

class IndexManager

  def initialize(path)
    @path = path
    @ikko = Ikko::FragmentManager.new
    @ikko.base_path = "."
    rebuild_indexes
  end
    
  def rebuild_indexes
    main_index_entries = []
    Dir.glob(File.join(@path, 'societies', '*')).each do |file|
      next unless File.directory?(file)
      build_society_index(file)
      main_index_entries << @ikko['main_index_entry.html', {'society'=>File.basename(file)}]
    end
    File.open(File.join(@path, "index.html"), "w") do |main_index|
      main_index.puts @ikko['main_index.html', {'societies'=>main_index_entries}]
    end
  end

  def build_society_index(file)
    experiments = []
    society = File.basename(file)
    Dir.glob(File.join(file, '*')) do |expt|
      md = /.*[0-9]+of[0-9]+\-([0-9]+\-[0-9]+)/.match(File.basename(expt))
      next unless md
      experiments << Experiment.new(md[1], expt)
    end
    experiments.sort!
    row = "even"
    date = ""
    entries = [] 
    experiments.each do |expt|
      unless date == expt.time[0,8]
        entries << @ikko['host_index_date.html', {"date"=>expt.date}]
        date = expt.time[0,8]
      end
      begin
        entries << @ikko['host_index_entry.html', {"row"=>row, "summary"=>File.read(File.join(expt.path, "reports", "report_summary.html"))}]
      rescue
        puts "WARNING: No report summary in #{expt.path}/reports"
      end
      row = (row=="even" ? "odd" : "even")
    end
    File.open(File.join(file, 'index.html'), 'w') do |host_index|
      host_index.puts @ikko['host_index.html', {'society'=>society, 'entries'=>entries}]
    end
  end
end


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
