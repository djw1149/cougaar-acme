module Cougaar
  module Actions
    class LoadSocietyFromPersistenceSnapshot <  Cougaar::Action
      RESULTANT_STATE = "SocietyLoaded"
      DOCUMENTATION = Cougaar.document {
        @description = "Load a society from a persistence snapshot file."
        @parameters = [
          {:filename => "required, The persistence snapshot filename"},
          {:debug => "boolean=false, True to print out debug messages"}
        ]
        @example = "do_action 'LoadSocietyFromPersistenceSnapshot', '~/snapshot.tgz''"
      }
      def initialize(run, filename, debug = false)
        super(run)
        @filename = filename
        @debug = debug
      end

      def perform()
        `cd #{ENV['CIP']}/workspace;rm -rf P`
        `cd #{ENV['CIP']}/workspace;tar -xzf #{@filename}`
        begin
          builder = Cougaar::SocietyBuilder.from_ruby_file("#{ENV['CIP']}/workspace/P/society.rb")
        rescue
         raise_failure "Could not build society from Ruby file: #{ENV['CIP']}/workspace/P/society.rb", $!
        end
        @run.society = builder.society
        @run.society.communities = Cougaar::Model::Communities.from_xml_file(@run.society, "#{ENV['CIP']}/workspace/P/communities.xml")
        `rm -rf #{ENV['CIP']}/workspace/P/society.rb`
        `rm -rf #{ENV['CIP']}/workspace/P/communities.xml`
				@run["loader"] = "XML"
      end
      
      def to_s
        super.to_s+"(#{@filename})"
      end
      
    end
    
    class SavePersistenceSnapshot <  Cougaar::Action
      def initialize(run, filename, debug = false)
        super(run)
        @filename = filename
        @debug = debug
      end
      
      def to_s
        super.to_s+"(#{@filename})"
      end

      def perform()
        begin
          snapshot_society = @run.society.clone
          nca_node = snapshot_society.agents['NCA'].node.agent
          result, uri = Cougaar::Communications::HTTP.get(nca_node.uri+"/timeControl")
          md = /Scenario Time<\/td><td>([^\s]*) (.*)<\/td>/.match(result)
          if md
            date = md[1]
            date = date.split("/")
            date = (date << (date.shift)).join("/")
            snapshot_society.each_node do |node|
              node.replace_parameter(/Dorg.cougaar.core.agent.startTime/, "-Dorg.cougaar.core.agent.startTime=#{date}")
            end
          end
          File.open("#{ENV['CIP']}/workspace/P/society.rb", "w") do |file|
            file.puts snapshot_society.to_ruby
          end
          File.open("#{ENV['CIP']}/workspace/P/communities.xml", "w") do |file|
            file.puts @run.society.communities.to_xml
          end
          `cd #{ENV['CIP']}/workspace; tar -czf #{@filename} P`
          `rm -rf #{ENV['CIP']}/workspace/P/society.rb`
          `rm -rf #{ENV['CIP']}/workspace/P/communities.xml`
        rescue
          @run.error_message "Error saving persistence snapshot to #{@filename}."
          @run.error_message $!
          @run.error_message $!.backtrace.join("\n")
        end
      end
    end
  end
end
