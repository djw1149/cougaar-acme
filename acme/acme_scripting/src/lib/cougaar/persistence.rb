=begin
 * <copyright>  
 *  Copyright 2001-2004 InfoEther LLC  
 *  Copyright 2001-2004 BBN Technologies
 *
 *  under sponsorship of the Defense Advanced Research Projects  
 *  Agency (DARPA).  
 *   
 *  You can redistribute this software and/or modify it under the 
 *  terms of the Cougaar Open Source License as published on the 
 *  Cougaar Open Source Website (www.cougaar.org <www.cougaar.org> ).   
 *   
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
 *  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
 *  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR 
 *  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT 
 *  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
 *  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT 
 *  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
 *  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY 
 *  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
 *  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
 *  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 * </copyright>  
=end

module Cougaar
  module Actions
    class LoadSocietyFromPersistenceSnapshot <  Cougaar::Action
      RESULTANT_STATE = "SocietyLoaded"
      DOCUMENTATION = Cougaar.document {
        @description = "Load a society from a persistence snapshot file."
        @parameters = [
          {:filename => "required, The persistence snapshot filename"},
          {:remote_restore => "boolean=false, Use a remote restore via ssh to nfs-shared service host"}
        ]
        @example = "do_action 'LoadSocietyFromPersistenceSnapshot', '~/snapshot.tgz''"
      }
      def initialize(run, filename, remote_restore = false)
        super(run)
        @filename = filename
        @remote_restore = remote_restore
      end

      def perform()
        `cd #{ENV['CIP']}/workspace;rm -rf P;rm -rf security`
        # untar archive...
        untar_command = "cd #{ENV['CIP']}/workspace;tar -xzf #{@filename}"
        if @remote_restore
          host_society = Ultralog::OperatorUtils::HostManager.new.load_society
          raise_failure "Could not load host society" unless host_society
          host = host_society.get_service_host('nfs-shared')
          raise_failure "Could not find service host with nfs-shared for remote restore" unless host
          @run.info_message "ssh #{host.host_name} '#{untar_command.gsub(/mnt\/shared/, 'export/shared')}'"
          timer = Time.now
          @run.info_message `ssh #{host.host_name} '#{untar_command.gsub(/mnt\/shared/, 'export/shared')}'`
          @run.info_message "Untar time: #{Time.now - timer}"
        else
          timer = Time.now
          `#{untar_command}`
          @run.info_message "Untar time: #{Time.now - timer}"
        end
        
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
  module States
    
    # Wait for this state to ensure given nodes have persisted
    class NodesPersisted < Cougaar::State
      DEFAULT_TIMEOUT = 30.minutes
      PRIOR_STATES = ["SocietyRunning"]
      DOCUMENTATION = Cougaar.document {
        @description = "Waits for all agents on the given nodes to have persisted at least once"
        @parameters = [
          {:nodes => "Nodes we want to wait for. If not given, use all in the society."}
        ]
        @example = "
          wait_for 'NodesPersisted', 'FWD-A'
        "
      }

      def initialize(run, *nodes)
        super(run)
        @nodes = *nodes
      end

      def process
      	if @nodes == nil || @nodes.size == 0
	  @run.info_message("Will wait for all nodes in the society.")
	  @nodes = []
	  @run.society.each_node do |node|
	    @nodes << node
          end
        else
          @run.info_message("Waiting for the following nodes to persist:  #{@nodes.join(', ')}.")
        end

        while (@nodes.size > 0)
          @nodes.each do |node|
            if node_persisted?(node)
              @nodes.delete(node)
              if (node.kind_of?(String))
                @run.info_message("Node #{node} has persisted.")
              else
                @run.info_message("Node #{node.name} has persisted.")
              end
            end
          end
        end
	@run.info_message("All nodes persisted.")
      end
      
      def node_persisted?(node)
        cougaar_node = nil
        ready = true
        if node.kind_of?(String)
	  cougaar_node = @run.society.nodes[node]
        else
	  cougaar_node = node
        end
        if cougaar_node == nil
  	  @run.error_message("No known node #{node} to look for.")
        else
          cougaar_node.each_agent do |agent|
            filename = File.join(ENV['CIP'], 'workspace', 'P', agent.name, 'delta_00000')
            ready = File.exist?(filename)
            break if !ready
          end
        end
        return ready
      end
    end
  end
end
