module ACME; module Plugins

  class ReportingService
  
    class ArchiveStructure
      FileReference = Struct.new(:name, :original_name, :description)
      ReportReference = Struct.new(:name, :description, :status)
      
      attr_reader :files, :service, :xml_file, :reports, :report_path, :mtime
      attr_accessor :root_path
      
      def initialize(service, xml_file, root_path, report_path)
        @service = service
        @files = []
        @reports = []
        @report_path = report_path
        @xml_file = xml_file
        @root_path = root_path
        
        unless File.exist?(root_path)
          Dir.mkdir(root_path)
        end
        
        unless File.exist?(File.join(root_path, report_path))
          Dir.mkdir(File.join(root_path, report_path))
        end
        
        @archive_file = @xml_file.gsub(/\.xml/, ".tgz")
        @mtime = File.mtime(xml_file)
        doc = REXML::Document.new(File.new(xml_file))
        @original_directory = doc.root.attributes['directory']
        doc.root.each_element("file") do |f|
          @files << FileReference.new(
            File.join(@root_path, f.attributes['name']).gsub(/#{File::SEPARATOR*2}/, File::SEPARATOR), 
            f.attributes['name'], f.attributes['description'])
        end
        doc.root.each_element("reports") do |r|
          @processed = true
        end
      end
      
      def base_name
        File.basename(@xml_file).gsub(/\.xml/, "")
      end
      
      def <=>(other)
        other.mtime <=> @mtime
      end
      
      def processed?
        @processed
      end
      
      def files_with_description(desc)
        list = []
        @files.each {|f| list << f if desc === f.description}
        list
      end
      
      def files_with_name(name)
        list = []
        @files.each {|f| list << f if name === f.name}
        list
      end
      
      def add_report(name, plugin_name)
        report = Report.new(self, name, plugin_name)
        yield report
        @reports << report
        report
      end
      
      def expand
        `tar -C #{@root_path} -xzf #{@archive_file}`
      end
      
      def rebuild_index
        result = []
        result << %Q{<run directory="#{@original_directory}">}
        @files.each do |f|
          result << %Q{  <file name="#{f.original_name}" description="#{f.description}"/>}
        end
        result << %Q{  <reports date="#{Time.now}">}
        @reports.each do |report|
          result << %Q{    <report name="#{report.name}" status="#{report.status}" score="#{report.score}" plugin="#{report.plugin_name}">}
          report.files.each do |rf|
            result << %Q{      <file name="#{rf.name}" mimetype="#{rf.mimetype}" description="#{rf.description}"/>}
          end
          result << "    </report>"
        end
        result << "  </reports>"
        result << "</run>"
        File.open(@xml_file+".new", "w") {|f| f.puts result.join("\n")}
      end
      
      def build_index_page
        begin
          report_entries = []
          @reports.each do |report|
            file_entries = []
            report.each_file do |report_file|
              file_entries << @service.ikko['report_index_file.html', 
                {'name'=>File.basename(report_file.name),
                 'path'=>report_file.name.split(File::SEPARATOR)[1..-1].join(File::SEPARATOR),
                 'description'=>report_file.description}]
            end
            report_entries << @service.ikko['report_index_entry.html',
              {'name'=>report.name,
               'plugin'=>report.plugin_name,
               'status'=>report.status,
               'files'=>file_entries}]
          end
          File.open(File.join(@root_path, "reports", "index.html"), "w") do |index|
            index.puts @service.ikko['report_index.html',
              {'experiment'=>base_name,
               'entries'=>report_entries}]
          end
        rescue
          puts "Error building index page: #{$!}"
          puts $!.backtrace.join("\n")
        end
      end
      
      def compress
        `cd #{@root_path}; tar -czf #{File.expand_path(@archive_file)+".new"} *`
      end

      def compress_reports
        `cd #{@root_path}; tar -czf #{File.expand_path(File.join(@root_path, 'reports.tgz'))} reports`
      end
      
      def cleanup
        `rm -rf #{File.join(@root_path, "*")}`
      end
    end

    
  end
      
end ; end 
