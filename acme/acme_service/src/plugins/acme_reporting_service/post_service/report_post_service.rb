require 'webrick'
require 'ikko'

Socket.do_not_reverse_lookup=true

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
    @build_again = true
    return if @build_thread
    @build_thread = Thread.new do 
      while @build_again
        @build_again = false
        main_index_entries = []
        Dir.glob(File.join(@path, '*')).each do |file|
          next unless File.directory?(file)
          build_society_index(file)
          main_index_entries << @ikko['main_index_entry.html', {'society'=>File.basename(file)}]
        end
        File.open(File.join(@path, "index.html"), "w") do |main_index|
          main_index.puts @ikko['main_index.html', {'societies'=>main_index_entries}]
        end
      end
      @build_thread = nil
    end
  end

  def build_society_index(file)
    experiments = []
    society = File.basename(file)
    Dir.glob(File.join(file, '*')) do |expt|
      md = /.*[0-9]*of[0-9]\-([0-9]+\-[0-9]+)/.match(File.basename(expt))
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

PATH = "/Users/rich/cvs/ultralog/csmart/src/ruby/acme_service/src/new_plugins/acme_reporting_service/post_service/reports"
PORT = 9443
@im = IndexManager.new(PATH)

httpd = WEBrick::HTTPServer.new(
  :BindAddress => "0.0.0.0",
  :Port => PORT
)

httpd.mount_proc("/post_report") do |request, response|
  if request.request_method=="POST"
    p = request.path.split("/")
    host = p[2]
    archive = p[3]
    if host && archive
      host_path = File.join(PATH, host)
      archive_path = File.join(host_path, archive)
      report_archive = File.join(archive_path, "reports.tgz")
      
      begin
        `mkdir #{host_path}` unless File.exist?(host_path)
        `mkdir #{archive_path}` unless File.exist?(archive_path)
        File.open(report_archive, "w") do |file|
          file.write(request.body)
        end
        `tar -C #{archive_path} -xzf #{report_archive}`
        `rm -f #{report_archive}`
        response.body = "SUCCESS"
        response['Content-Type'] = "text/plain"
        @im.rebuild_indexes
      rescue
        response.body = "FAILURE - could not write report"
        response['Content-Type'] = "text/plain"
        puts $!
        puts $!.backtrace.join("\n")
      end
    else
      response.body = "FAILURE - malformed uri: /post_report/<host>/<experiment>"
      response['Content-Type'] = "text/plain"
    end
  else
    response.body = "<html><body><h1>Only works with HTTP POST.</h1></html>"
    response['Content-Type'] = "text/html"
  end

end

trap("SIGINT") {httpd.stop; exit}

httpd.start