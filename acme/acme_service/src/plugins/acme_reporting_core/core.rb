$: << "/usr/local/acme/plugins/acme_reporting_core"
require "RunTimeTest"
require "CompletionTest"
require "QData"

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
        run_log(archive)
        RunTimeTest.new(archive, @plugin, @ikko).perform
        CompletionTest.new(archive, @plugin, @ikko).perform
	QData.new(archive, @plugin, @ikko).perform
      end
      
      def run_log(archive)
        archive.add_report("Run Log", @plugin.plugin_configuration.name) do |report|
          run_data = nil
          archive.files_with_name(/run\.log/).each do |f|
            run_data = File.read(f.name)
          end
          if run_data
            report.open_file("run_report.html", "text/html", "Full Run Log") do |file|
              file.puts @ikko['run_report.html', {'data'=>run_data}]
            end
            report.success
          else
            report.failure
          end
        end
      end
    end
  end       
end  

