$: << "/usr/local/acme/plugins/acme_reporting_core"
require "RunTimeTest"
require "CompletionTest"
require "QData"
require "VerifyInventory"

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
        puts "Processing an archive"
        run_log_test(archive)
        RunTimeTest.new(archive, @plugin, @ikko).perform
        CompletionTest.new(archive, @plugin, @ikko).perform
	QData.new(archive, @plugin, @ikko).perform
        VerifyInventory.new(archive, @plugin, @ikko).perform(0.10, 0.10)
      end
      
      def run_log_test(archive)
        archive.add_report("RLog", @plugin.plugin_configuration.name) do |report|
          run_log = nil
          archive.files_with_name(/run\.log/).each do |f|
            run_log = f.name
          end
          if run_log
            error = false
            run_data = File.readlines(run_log)
            run_data.each do |line|
              #only care if last run in the log was interrupted
              error = false if line =~ /Run:.*Started/ 
              error = true if line =~ /INTERRUPT/
            end
            run_data = run_data.collect!{|x| x.gsub(/&/, "&amp;").gsub(/</, "&lt;").gsub(/>/,"&gt;")}
            report.open_file("run_report.html", "text/html", "Full Run Log") do |file|
              file.puts @ikko['run_report.html', {'data'=>run_data}]
            end
            if (error) then
              report.failure
            else
              report.success
            end
          else
            report.failure
          end
        end
      end
    end
  end       
end  

