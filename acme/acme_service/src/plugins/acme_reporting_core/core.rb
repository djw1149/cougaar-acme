$: << "/usr/local/acme/plugins/acme_reporting_core"
require "RunTimeTest"
require "CompletionTest"
require "QData"
require "VerifyInventory"
require "DataGrabberTest"

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
      end
      
      def load_template_engine
        @ikko = Ikko::FragmentManager.new
        @ikko.base_path = File.join(@plugin.plugin_configuration.base_path, "templates")
      end

      def process_archive(archive)
        puts "Processing an archive #{archive.base_name}"
        run_log_test(archive)
        puts "Run log"
        RunTimeTest.new(archive, @plugin, @ikko).perform
        puts "Run Time"
        CompletionTest.new(archive, @plugin, @ikko).perform
        puts "Comp"
	QData.new(archive, @plugin, @ikko).perform
        puts "Q"
        VerifyInventory.new(archive, @plugin, @ikko).perform(0.10, 0.10)
        puts "INV"
        DataGrabberTest.new(archive, @plugin, @ikko).perform
        puts "GRAB"
      end
      
      def run_log_test(archive)
        archive.add_report("Log", @plugin.plugin_configuration.name) do |report|
          run_log = nil
          archive.files_with_name(/run\.log/).each do |f|
            run_log = f.name
          end
          if run_log
            error = 0
            run_data = File.readlines(run_log)
            last_run = []
            run_data.each do |line|
              if line =~ /Run:.*started/ then
              #only care if last run in the log was interrupted
                error = 0 
                last_run = []
              end
              error = 1 if (line =~ /INTERRUPT/ && error == 0)
              error = 2 if (line =~ /\[ERROR\]/)
              last_run << line
            end
            run_data = run_data.collect!{|x| x.gsub(/&/, "&amp;").gsub(/</, "&lt;").gsub(/>/,"&gt;")}
            report.open_file("run_report.html", "text/html", "Full Run Log") do |file|
              file.puts @ikko['run_report.html', {'description_link'=>"run_report_description.html", 'data'=>last_run}]
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

