require 'rexml/document'
require 'fileutils'
require 'ikko'
require 'acme_reporting_service/report'
require 'acme_reporting_service/archive'
require 'net/http'

module ACME; module Plugins

class ReportingService

  extend FreeBASE::StandardPlugin
  
  def self.start(plugin)
    self.new(plugin)
    plugin.transition(FreeBASE::RUNNING)
  end
  
  attr_reader :plugin, :ikko
  
  def initialize(plugin)
    @plugin = plugin
    @archive_path = @plugin.properties['archive_path']
    @temp_path = @plugin.properties['temp_path']
    @report_path = @plugin.properties['report_path']
    @report_host_name = @plugin.properties['report_host_name']
    @report_host_port = @plugin.properties['report_host_port']
    @society_name = @plugin.properties['society_name']
    @plugin['/acme/reporting'].manager = self
    @listeners = []
    @hostname = `hostname`.strip
    @archive_structures = []
    load_template_engine
    monitor_path
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
    File.open(File.join(@temp_path, @report_path, 'report_summary.html'), "w") do |f| 
      f.puts generate_archive_summary(archive)
    end
    archive.compress_reports
    data = File.read(File.join(@temp_path, "reports.tgz"))
    Net::HTTP.start(@report_host_name, @report_host_port) do |http|
      response = http.post("/post_report.rb?/#{@society_name}/#{archive.base_name}", 
                 data, 
                 {'content-type'=>'application/octet-stream'})
      result = response.read_body
      puts "result = #{result}"
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
      files = Dir.glob(File.join(@archive_path, "*.xml"))
      new_files = files - last
      new_files.each do |file|
        archive = ArchiveStructure.new(self, file, @temp_path, @report_path) # this is the temporary expansion path
        unless archive.processed?
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
        @archive_structures << archive
        @archive_structures.sort
      end
      last = files
      sleep 10
    end
  end

  def add_listener(order=:none, &block)
    @listeners << block
  end
  
  def notify(struct)
    @listeners.each do |listener|
      listener.call(struct)
    end
  end
end

end ; end 
