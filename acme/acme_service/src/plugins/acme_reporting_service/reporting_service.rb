require 'rexml/document'
require 'fileutils'
require 'ikko'
require 'acme_reporting_service/report'
require 'acme_reporting_service/archive'
require 'net/http'
require 'thread'

module ACME; module Plugins

class ReportingService

  extend FreeBASE::StandardPlugin

  class ProcessingQueue
    def initialize
      @q     = []
      @mutex = Mutex.new
      @cond  = ConditionVariable.new
    end
  
    def enqueue(*elems)
      @mutex.synchronize do
        @q.push *elems
        @cond.signal
      end
    end
  
    def dequeue
      @mutex.synchronize do
        while @q.empty? do
          @cond.wait(@mutex)
        end
        return @q.shift
      end
    end
  
    def empty?
      @mutex.synchronize do
        return @q.empty?
      end
    end
  end
  
  def self.start(plugin)
    self.new(plugin)
    plugin.transition(FreeBASE::RUNNING)
  end
  
  attr_reader :plugin, :ikko
  
  def initialize(plugin)
    @plugin = plugin
    @archive_path = @plugin.properties['archive_path']
    @temp_path = @plugin.properties['temp_path']
    unless File.exist?(@temp_path)
      Dir.mkdir(@temp_path)
    end
    @report_path = @plugin.properties['report_path']
    @report_host_name = @plugin.properties['report_host_name']
    @report_host_port = @plugin.properties['report_host_port']
    @society_name = @plugin.properties['society_name']
    @thread_count = @plugin.properties['thread_count']
    @thread_count ||= 1
    @plugin['/acme/reporting'].manager = self
    @listeners = []
    @report_verifiers = []
    @hostname = `hostname`.strip
    @processing_queue = ProcessingQueue.new
    @groups_file = File.join(@plugin.plugin_configuration.base_path, 'groups.yaml')
    load_template_engine
    #mount_web_services
    start_threads
    monitor_path
  end
  
  def mount_web_services
    @plugin['/protocols/http/reporting'].set_proc do |request, response| 
      if request.request_method=="POST"
        data = request.query
        response['Content-Type'] = "text/html"
        response.body = @ikko["schedule_complete.html", {'filename'=>filename, 'footer'=>@footer}]
      else
        response['Content-Type'] = "text/html"
        response.body = @ikko["schedule_run.html", {'footer'=>@footer}]
      end
    end
  end
  
  def load_template_engine
    @ikko = Ikko::FragmentManager.new
    @ikko.base_path = File.join(@plugin.plugin_configuration.base_path, 'templates')
  end
  
  def generate_archive_summary(archive)
    items = []
    archive.reports.each do |report|
      items << @ikko['report_item.html', {"status"=>report.status, "name"=>report.name}]
    end
    items << @ikko['report_item.html', {"status"=>"NONE", "width"=>"100%", "name"=>"&nbsp;", "colspan"=>(15-archive.reports.size).to_s}]
    entry = {"name"=>archive.base_name, "items"=>items}
    @ikko['report_entry.html', entry]
  end
  
  def post_reports(archive)
    File.open(File.join(archive.root_path, @report_path, 'report_summary.html'), "w") do |f| 
      f.puts generate_archive_summary(archive)
    end
    archive.compress_reports
    data = File.read(File.join(archive.root_path, "reports.tgz"))
    Net::HTTP.start(@report_host_name, @report_host_port) do |http|
      response = http.post("/post_report.rb/#{@society_name}/#{archive.base_name}", 
                 data, 
                 {'content-type'=>'application/octet-stream'})
      result = response.read_body
      puts "result = #{result}"
    end
  end
  
  def start_threads
    @thread_count.times do
      Thread.new do
        while true
          archive = @processing_queue.dequeue
          if !archive.processed? || rerun_reports?(archive)
            archive.expand
            if archive.is_valid?
              notify(archive) # notify all plugins
              archive.rebuild_index
              archive.build_index_page
              archive.compress
              post_reports(archive) # send results to service
            else
              puts "Errors: Skipping archive file: #{archive.xml_file}"
            end
            archive.cleanup
          end
        end
      end
    end
  end
      
  def monitor_path
    unless File.exist?(@archive_path)
      @plugin.log_error << "Archive path #{@archive_path} not found"
    end
    last = []
    Thread.new do
      sleep 5
      puts "Beginning to process archives"
      while true
        files = Dir.glob(File.join(@archive_path, "*.xml"))
        new_files = files - last
        new_files.each do |file|
          archive = ArchiveStructure.new(self, file, @temp_path, @report_path)
          @processing_queue.enqueue(archive)
        end
        last = files
        sleep 5
      end
    end
  end
  
  def open_prior_archive(current, prior)
    prior_file = File.join(@archive_path, "#{prior}.xml")
    return nil unless File.exist?(prior_file)
    prior_archive = ArchiveStructure.new(self, prior_file, current.root_path, @report_path)
    prior_archive.expand
    return prior_archive
  end
  
  def groups
    groups = {}
    files = []
    Dir.glob(File.join(@archive_path, "*.xml")).each do |file|
      if File.basename(file) =~ /^baseline.*/
        files << File.basename(file)[0...-4]
      end
    end
    files.sort {|a,b| parse_time(b)<=>parse_time(a)}
    files.each do |file|
      group = file.split(/-/)[1]
      group_entries = groups[group]
      unless group_entries
        group_entries = []
        groups[group] = group_entries
      end
      group_entries << file
    end
    groups
  end  
  
  def group_baseline(group_name)
    group = self.groups[group_name]
    return nil if group.nil? || group.size == 0
    if File.exist?(@groups_file)
      begin
        set_groups = YAML.load(File.read(@groups_file))
        if set_groups.kind_of?(Hash) &&
         set_groups.has_key?(group_name)
          if group.include?(set_groups[group_name])
            return set_groups[group_name]
          else
            @plugin.log_error << "Baseline does not exist: group: #{group_name} - baseline: #{set_groups[group_name]}\nDefaulting to last baseline"
            return nil
          end
        end
      rescue
        @plugin.log_error << "Could not parse YAML group file: #{File.expand_path(@groups_file)}"
        return nil
      end
    end
    return group.last
  end
  
  def parse_time(name)
    name = name[0...-4] if name.include?(".xml")
    parts = name.split("-")
    hms = parts[-1]
    ymd = parts[-2]
    Time.utc( ymd[0,4].to_i, ymd[4,2].to_i,  ymd[6,2].to_i, hms[0,2].to_i,  hms[2,2].to_i, hms[4,2].to_i)
  end

  def get_prior_archives(current, time=nil, name_pattern=/.*/)
    base_time = parse_time(File.basename(current.xml_file))
    files = []
    Dir.glob(File.join(@archive_path, "*.xml")).each do |file|
      ftime = parse_time(File.basename(file))
      if (base_time - ftime) > 0
        if (time==nil || (base_time - ftime) < time) && name_pattern =~ File.basename(file)
          files << File.basename(file)[0...-4]
        end
      end
    end
    files.sort {|a,b| parse_time(b)<=>parse_time(a)}
  end

  def add_listener(order=:none, &block)
    @listeners << block
  end
  
  def notify(struct)
    @listeners.each do |listener|
      begin
        listener.call(struct)
      rescue Exception => e
        @plugin.log_error << e.to_s
        @plugin.log_error << e.backtrace.join("\n")
      end
    end
  end
  
  def add_report_verifier(&block)
    @report_verifiers << block
  end
  
  def rerun_reports?(struct)
    rerun_reports = false
    @report_verifiers.each do |listener|
      begin
        rerun_reports = true if listener.call(struct)
      rescue Exception => e
        @plugin.log_error << e.to_s
        @plugin.log_error << e.backtrace.join("\n")
      end
    end
    return rerun_reports
  end
end

end ; end 
