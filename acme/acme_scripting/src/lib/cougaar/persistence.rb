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
        `cd #{ENV['CIP']}/workspace;rm -rf P;rm -rf security`
        `cd #{ENV['CIP']}/workspace;tar -xzf #{@filename}`
        if File.exists?("#{ENV['CIP']}/workspace/P/securityservices_config.jar")
          `cp #{ENV['CIP']}/workspace/P/securityservices_config.jar #{ENV['CIP']}/configs/security/securityservices_config.jar`
        end
        begin
          builder = Cougaar::SocietyBuilder.from_ruby_file("#{ENV['CIP']}/workspace/P/society.rb")
        rescue
         raise_failure "Could not build society from Ruby file: #{ENV['CIP']}/workspace/P/society.rb", $!
        end
        @run.society = builder.society

        time = Time.now.gmtime
        @run.society.each_node do |node|
          node.replace_parameter(/Dorg.cougaar.core.society.startTime/, "-Dorg.cougaar.core.society.startTime=\"#{time.strftime('%m/%d/%Y %H:%M:%S')}\"")
#          node.replace_parameter(/Dorg.cougaar.core.node.SkipReconciliation/, "-Dorg.cougaar.core.node.SkipReconciliation=true")
        end

        @run.society.communities = Cougaar::Model::Communities.from_xml_file(@run.society, "#{ENV['CIP']}/workspace/P/communities.xml")
        `rm -rf #{ENV['CIP']}/workspace/P/society.rb`
        `rm -rf #{ENV['CIP']}/workspace/P/communities.xml`
        `rm -rf #{ENV['CIP']}/workspace/P/securityservices_config.jar`
				@run["loader"] = "XML"
      end
      
      def to_s
        super.to_s+"(#{@filename})"
      end
      
    end


    class SynchronizeSocietyTime <  Cougaar::Action
      DOCUMENTATION = Cougaar.document {
        @description = "Synchronize the in-memory society's time with actual Cougaar time."
        @example = "do_action 'SynchronizeSocietyTime'"
      }
      
      def initialize(run)
        super(run)
      end
      
      def perform()
        begin
          nca_node = nil
          @run.society.each_agent do |agent|
            if (agent.has_facet?(:role) && agent.get_facet(:role) == "LogisticsCommanderInChief")
              nca_node = agent.node.agent
              break
            end
          end

          result, uri = Cougaar::Communications::HTTP.get(nca_node.uri+"/timeControl")
          md = /Scenario Time<\/td><td>([^\s]*) (.*):(.*):(.*)<\/td>/.match(result)
          if md
            date = md[1]
            socHour = md[2]
            date = date.split("/")
            date = (date << (date.shift)).join("/")
            @run.society.each_node do |node|
              node.replace_parameter(/Dorg.cougaar.core.agent.startTime/, "-Dorg.cougaar.core.agent.startTime=\"#{date} #{socHour}:00:00\"")
            end
          end
        rescue
          @run.error_message "Error syncing society time."
          @run.error_message $!
          @run.error_message $!.backtrace.join("\n")
        end
      end
    end
    
    class SavePersistenceSnapshot <  Cougaar::Action
      DOCUMENTATION = Cougaar.document {
        @description = "Save a society to a persistence snapshot file."
        @parameters = [
          {:filename => "required, The persistence snapshot filename"},
          {:debug => "boolean=false, True to print out debug messages"}
        ]
        @example = "do_action 'SavePersistenceSnapshot', '~/snapshot.tgz''"
      }
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
          nca_node = nil
          @run.society.each_agent do |agent|
            if (agent.has_facet?(:role) && agent.get_facet(:role) == "LogisticsCommanderInChief")
              nca_node = agent.node.agent
              break
            end
          end

          result, uri = Cougaar::Communications::HTTP.get(nca_node.uri+"/timeControl")
          md = /Scenario Time<\/td><td>([^\s]*) (.*):(.*):(.*)<\/td>/.match(result)
          if md
            date = md[1]
            socHour = md[2]
            date = date.split("/")
            date = (date << (date.shift)).join("/")
            snapshot_society.each_node do |node|
              node.replace_parameter(/Dorg.cougaar.core.agent.startTime/, "-Dorg.cougaar.core.agent.startTime=\"#{date} #{socHour}:00:00\"")
            end
          end
          File.open("#{ENV['CIP']}/workspace/P/society.rb", "w") do |file|
            file.puts snapshot_society.to_ruby
          end
          File.open("#{ENV['CIP']}/workspace/P/communities.xml", "w") do |file|
            file.puts @run.society.communities.to_xml
          end
          if File.exists?("#{ENV['CIP']}/configs/security/securityservices_config.jar")
            `cp #{ENV['CIP']}/configs/security/securityservices_config.jar #{ENV['CIP']}/workspace/P/securityservices_config.jar`
            `cd #{ENV['CIP']}/workspace; tar -czf #{@filename} P security`
          else
            `cd #{ENV['CIP']}/workspace; tar -czf #{@filename} P`
          end
          `rm -rf #{ENV['CIP']}/workspace/P/society.rb`
          `rm -rf #{ENV['CIP']}/workspace/P/communities.xml`
          `rm -rf #{ENV['CIP']}/workspace/P/securityservices_config.jar`
        rescue
          @run.error_message "Error saving persistence snapshot to #{@filename}."
          @run.error_message $!
          @run.error_message $!.backtrace.join("\n")
        end
      end
    end
  end
end
