require "./plugins/acme_reporting_core/CacheManager"
require "./plugins/acme_reporting_core/RunTimeTest"
require "./plugins/acme_reporting_core/CompletionTest"
require "./plugins/acme_reporting_core/QData"
require "./plugins/acme_reporting_core/VerifyInventory"
require "./plugins/acme_reporting_core/DataGrabberTest"
require "./plugins/acme_reporting_core/Nameservers"
require "./plugins/acme_reporting_core/Scripts"
require "./plugins/acme_reporting_core/BWUsage"
require "./plugins/acme_reporting_core/MemoryReport"
require "./plugins/acme_reporting_core/AgagentReport"

module ACME
  module Plugins
    
    class ReportingCore
      extend FreeBASE::StandardPlugin
      
      def self.start(plugin)
        self.new(plugin)
        plugin.transition(FreeBASE::RUNNING)
      end
      
      attr_reader :plugin
      
      def initialize(plugin)
        @plugin = plugin
        @reporting = @plugin['/acme/reporting']
        load_template_engine
        @reporting.manager.add_listener(&method(:process_archive))
        load_cache_manager
      end
      
      def load_template_engine
        @ikko = Ikko::FragmentManager.new
        @ikko.base_path = File.join(@plugin.plugin_configuration.base_path, "templates")
      end

      def load_cache_manager
        cache_path = @plugin.properties['cache']
        @cache_manager = CacheManager.new(cache_path)
      end

      def process_archive(archive)
        puts "Processing an archive #{archive.base_name}"
        begin
          run_log_test(archive)
          puts "Run log"
          RunTimeTest.new(archive, @plugin, @ikko, @cache_manager).perform
          puts "Run Time"
          CompletionTest.new(archive, @plugin, @ikko).perform
          puts "Comp"
          QData.new(archive, @plugin, @ikko, @cache_manager).perform
          puts "Q"
          VerifyInventory.new(archive, @plugin, @ikko).perform(0.10, 0.10)
          puts "INV"
          DataGrabberTest.new(archive, @plugin, @ikko).perform
          puts "GRAB"
          Nameservers.new(archive, @plugin, @ikko).perform
          puts "NS"
          Scripts.new(archive, @plugin, @ikko).perform
          puts "Definition"
          BWUsage.new(archive, @plugin, @ikko).perform
          puts "BWUsage"
          MemoryReport.new(archive, @plugin, @ikko, @cache_manager).perform
          puts "MEM"
          AgagentReport.new(archive, @plugin, @ikko).perform
          puts "AG"
          @cache_manager.prune(500*1024*1024) #500 MB cache limit for now
        rescue
          puts $!
          puts $!.backtrace
          archive.add_report("Exception", @plugin.plugin_configuration.name) do |report|
            report.open_file("Exception.html", "text/html", "Exception") do |out|
              out.puts "<html>"
              out.puts "<title>Exception</title>"
              out.puts "#{$!} <BR>"
              out.puts $!.backtrace.collect{|x| x.gsub(/&/, "&amp;").gsub(/</, "&lt;").gsub(/>/,"&gt;")}.join("<BR>")
              out.puts "</html>"
            end
            report.failure
          end
        end
      end
      
      def run_log_test(archive)
        #if a run contains kills and a line matches any regexp in this array then it is not an error
        acceptable_kill_errors = [/Error accessing .*PersistenceManager/, 
                                  /Error accessing .*CaManager/]
        archive.add_report("Log", @plugin.plugin_configuration.name) do |report|
          run_log = nil
          archive.files_with_name(/run\.log/).each do |f|
            run_log = f.name
          end
          if run_log
            error = 0
            kills = false
            run_data = File.readlines(run_log)
            last_run = []
            run_data.each do |line|
              if line =~ /Run:.*started/ then
              #only care if last run in the log was interrupted
                error = 0
                kills = false 
                last_run = []
              end
              kills = true if (line =~ /KillNodes/)
              error = 1 if (line =~ /INTERRUPT/ && error == 0)
              if (line =~ /\[ERROR\]/) then
                #check if this is an acceptable kill error, === used to get true/false answer for matching
                unless (kills && acceptable_kill_errors.collect{|re| re === line}.include?(true)) then
                  error = 2
                end
              end
              last_run << line
            end
            run_data = run_data.collect!{|x| x.gsub(/&/, "&amp;").gsub(/</, "&lt;").gsub(/>/,"&gt;")}
            report.open_file("run_report.html", "text/html", "Full Run Log") do |file|
              file.puts @ikko['run_report.html', {'description_link'=>"run_report_description.html", 'data'=>last_run, 'date'=>Time.now}]
            end

            desc = create_description
            report.open_file("run_report_description.html", "text/html", "Run Report Description") do |file|
              file.puts desc
            end


            if (error == 0) then
              report.success
            elsif (error == 1) then
              report.partial_success
            else
              report.failure          
            end
          else
            report.failure
          end
        end
      end
      
      def create_description
        ikko_data = {}
        ikko_data["name"] = "Run Report"
        ikko_data["title"] = "Run Report Description"
        ikko_data["description"] = "Prints the listing of the run.log for the current run.  Other runs in the log are ignored"
        success_table = {"success"=>"No Errors or interrupts in the run",
                         "partial"=>"Interrupts present but no errors",
                         "fail"=>"Errors present or run.log file not found"}
        ikko_data["table"] = @ikko["success_template.html", success_table]
        return @ikko["description.html", ikko_data]
      end
    end
  end       
end  

