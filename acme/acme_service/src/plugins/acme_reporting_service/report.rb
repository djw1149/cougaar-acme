require 'rexml/document'
require 'fileutils'
require 'ikko'

module ACME; module Plugins

  class ReportingService
  
    class Report
      ReportFile = Struct.new(:name, :mimetype, :description)
      
      SUCCESS = "SUCCESS"
      PARTIAL_SUCCESS = "PARTIAL_SUCCESS"
      FAILURE = "FAILURE"
      attr_accessor :description
      attr_reader :files, :name, :plugin_name, :status
      
      attr_accessor :score
      
      def initialize(archive_structure, name, plugin_name)
        @archive_structure = archive_structure
        @name = name
        @plugin_name = plugin_name
        @files = []
        @status = SUCCESS
      end
      
      def success
        @status = SUCCESS
      end
      
      def partial_success
        @status = PARTIAL_SUCCESS
      end
      
      def failure
        @status = FAILURE
      end
      
      def each_file
        @files.each {|file| yield file}
      end
      
      def open_file(filename, mimetype="text/html", description="", &block)
        report_file = File.join(@archive_structure.root_path, @archive_structure.report_path, plugin_name, filename)
        unless File.exist?(File.join(@archive_structure.root_path, @archive_structure.report_path, plugin_name))
          Dir.mkdir(File.join(@archive_structure.root_path, @archive_structure.report_path, plugin_name))
        end
        
        begin
          File.open(report_file, "wb", &block)
          @files << ReportFile.new(File.join(@archive_structure.report_path, plugin_name, filename), mimetype, description)
        rescue
          @archive_structure.service.plugin.log_error << "Error writing report file #{report_file}"
          @archive_structure.service.plugin.log_error << $!
          @archive_structure.service.plugin.log_error << $!.backtrace.join("\n")
        end
      end
    end

  end
      
end ; end 
