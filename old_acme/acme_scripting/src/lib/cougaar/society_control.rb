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
  class NodeController
    def initialize(run, timeout, debug)
      @run = run
      @debug = debug
      @timeout = timeout
      @pids = {}
      @run['pids'] = @pids
    end
    
    def add_cougaar_event_params
      @xml_model = @run["loader"] == "XML"
      @node_type = ""
      @node_type = "xml_" if @xml_model
      @run.society.each_active_host do |host|
        host.each_node do |node|
          node.add_parameter("-Dorg.cougaar.event.host=127.0.0.1")
          node.add_parameter("-Dorg.cougaar.event.port=5300")
          node.add_parameter("-Dorg.cougaar.event.experiment=#{@run.comms.experiment_name}")
        end
      end
    end
    
    def start_all_nodes(action)
      nodes = []
      @run.society.each_active_host do |host|
        host.each_node do |node|
          nameserver = false
          host.each_facet(:role) do |facet|
            nameserver = true if facet[:role].downcase=="nameserver"
          end
          if nameserver
            nodes.unshift node
          else
            nodes << node
          end
        end
      end
      msgs = {}
      nodes.each do |node|
        if @xml_model
          post_node_xml(node)
          msgs[node] = launch_xml_node(node)
        else
          msgs[node] = launch_db_node(node)
        end
      end
      nodes.each do |node|
        @run.info_message "Sending message to #{node.host.name} -- [command[start_#{@node_type}node]#{msgs[node]}] \n" if @debug
        result = @run.comms.new_message(node.host).set_body("command[start_#{@node_type}node]#{msgs[node]}").request(@timeout)
        if result.nil?
          @run.error_message "Could not start node #{node.name} on host #{node.host.host_name}"
        else
          @pids[node.name] = result.body
          node.active=true
        end
      end

    end
    
    def stop_all_nodes(action)
      nameserver_nodes = []
      @run.society.each_host do |host|
        host.each_node do |node|
          nameserver = false
          host.each_facet(:role) do |facet|
            if facet[:role].downcase=="nameserver"
              nameserver_nodes << node
              nameserver = true 
            end
          end
          stop_node(node) unless nameserver
        end
      end
      nameserver_nodes.each { |node| stop_node(node) }
      @pids.clear
    end
    
    def stop_node(node)
      host = node.host
      @run.info_message "Sending message to #{host.name} -- command[stop_#{@node_type}node]#{@pids[node.name]} \n" if @debug
      result = @run.comms.new_message(host).set_body("command[stop_#{@node_type}node]#{@pids[node.name]}").request(60)
      if result.nil?
        @run.info_message "Could not stop node #{node.name}(#{@pids[node.name]}) on host #{host.host_name}"
      else
        node.active=false
      end
    end
    
    def restart_node(action, node)
      if @xml_model
        msg_body = launch_xml_node(node, "xml")
      else
        msg_body = launch_db_node(node)
      end
      @run.info_message "RESTART: Sending message to #{node.host.name} -- [command[start_#{@node_type}node]#{msg_body}] \n" if @debug
      result = @run.comms.new_message(node.host).set_body("command[start_#{@node_type}node]#{msg_body}").request(@timeout)
      if result.nil?
        @run.error_message "Could not start node #{node.name} on host #{node.host.host_name}"
      else
        node.active = true
        @pids[node.name] = result.body
      end
    end
    
    def kill_node(action, node)
      pid = @pids[node.name]
      if pid
        @pids.delete(node.name)
        @run.info_message "KILL: Sending message to #{node.host.name} -- command[stop_#{@node_type}node]#{pid} \n" if @debug
        result = @run.comms.new_message(node.host).set_body("command[stop_#{@node_type}node]#{pid}").request(60)
        if result.nil?
          @run.error_message "Could not kill node #{node.name}(#{pid}) on host #{node.host.host_name}"
        else
          node.active = false
          node.agents.each do |agent|
            agent.set_killed
          end
        end
      else
        @run.error_message "Could not kill node #{node.name}...node does not have an active PID."
      end
    end
    
    def launch_db_node(node)
      return node.parameters.join("\n")
    end
    
    def launch_xml_node(node, kind='rb')
      return node.name+".#{kind}"
    end
    
    def post_node_xml(node)
      node_society = Cougaar::Model::Society.new( "society-for-#{node.name}" ) do |society|
        society.add_host( node.host.name ) do |host|
          host.add_node( node.clone(host) )
        end
      end
      node_society.remove_all_facets
      result = Cougaar::Communications::HTTP.post("http://#{node.host.uri_name}:9444/xmlnode/#{node.name}.rb", node_society.to_ruby, "x-application/ruby")
      @run.info_message result if @debug
    end
    
  end
  
  module Actions
  
    class KeepSocietySynchronized < Cougaar::Action
      PRIOR_STATES = ["CommunicationsRunning"]
      RESULTANT_STATE = "SocietyRunning"
      DOCUMENTATION = Cougaar.document {
        @description = "Maintain a synchronization of Agents-Nodes-Hosts from Lifecycle CougaarEvents."
        @example = "do_action 'KeepSocietySynchronized'"
      }
      def perform
        @run.comms.on_cougaar_event do |event|
          if event.component=="SimpleAgent" || event.component=="ClusterImpl" || event.component=="Events"
            match = /.*AgentLifecycle\(([^\)]*)\) Agent\(([^\)]*)\) Node\(([^\)]*)\) Host\(([^\)]*)\)/.match(event.data)
            if match
              cycle, agent_name, node_name, host_name = match[1,4]
              if cycle == "Started" && @run.society.agents[agent_name]
                node = @run.society.agents[agent_name].node
                @run.society.agents[agent_name].set_running
                if node_name != node.name
                  @run.society.agents[agent_name].move_to(node_name)
                  @run.info_message "Moving agent: #{agent_name} to node: #{node_name}"

                  # If the agent wasn't moved but actually restarted,
                  # then it might still exist on the old Node. This blocks
                  # quiescence and can use up memory.

                  # Get it out of the quiescence-way - ubug 13539
                  # Note that this is not needed. The removing
                  # of the agent below triggers a checkQuiescence itself
  #                result = Cougaar::Communications::HTTP.get("#{node.uri}/agentQuiescenceState?dead=#{agent_name}", 60)

                  # Remove it to free up resources - See ubug 13550
                  Thread.new(node.uri, node.name, agent_name) do |uri, node_name, agent| 
                    result = Cougaar::Communications::HTTP.get("#{uri}/move?op=Remove&mobileAgent=#{agent}&destNode=#{node_name}&action=Add", 60)
                  end

                  # FIXME: look at the result to see if this actually did something
                  # If it did, log that fact
                  # Note that you have to poll the /move servlet as it
                  # works asynchronously. Get the UID out of the first
                  # result (the one marked In Progress), and then look for
                  # DOES_NOT_EXIST vs SUCCESSFUL or REMOVED later
                end
              end
            end
          end
        end
      end
    end
    
    class LogCougaarEvents < Cougaar::Action
      PRIOR_STATES = ["CommunicationsRunning"]
      DOCUMENTATION = Cougaar.document {
        @description = "Send all CougaarEvents to the run.log."
        @example = "do_action 'LogCougaarEvents'"
      }
      
      def perform
        @run.comms.on_cougaar_event do |event|
          ::Cougaar.logger.info event.to_s
        end
      end
    end
  
    class LoadComponent < Cougaar::Action
      PRIOR_STATES = ["SocietyRunning"]
      DOCUMENTATION = Cougaar.document {
        @description = "Adds or removes a component to/from an agent"
        @parameters = [
          {:agentname=> "Name of the agent to add the component to"},
          {:action=> "add or remove"}, 
          {:component=>"the component"}
        ]
        @example = "do_action 'LoadComponent', '1-AD', 'add', 'org.cougaar.logistics.plugin.trans.RescindWatcher'"
      }

      def initialize(run, agentname, action, classname)
        super(run)
        @agentname = agentname
        @action = action
        @classname = classname
      end
      
      def perform
        @run.society.each_agent do |agent|
          if @agentname == agent.name then
            data, uri = Cougaar::Communications::HTTP.get("#{agent.uri}/load?op=#{@action}&insertionPoint=Node.AgentManager.Agent.PluginManager.Plugin&classname=#{@classname}", 60)
          end
        end
      end
    end

    class StartSociety < Cougaar::Action
      PRIOR_STATES = ["CommunicationsRunning"]
      RESULTANT_STATE = "SocietyRunning"
      DOCUMENTATION = Cougaar.document {
        @description = "Start a society from XML or CSmart."
        @parameters = [
          {:timeout => "default=120, Number of seconds to wait to start each node before failing."},
          {:debug => "default=false, If true, outputs messages sent to start nodes."}
        ]
        @example = "do_action 'StartSociety', 300, true"
      }
      
      def initialize(run, timeout=120, debug=false)
        super(run)
        unless timeout.kind_of?(Numeric) && (debug==true || debug==false)
          raise_failure "StartSociety usage: do_action 'StartSociety', timeout (default 120), debug (default false)"
        end
        @run['node_controller'] = ::Cougaar::NodeController.new(run, timeout, debug)
      end
      
      def perform
        time = Time.now.gmtime
        @run.society.each_node do |node|
          node.replace_parameter(/Dorg.cougaar.core.society.startTime/, "-Dorg.cougaar.core.society.startTime=\"#{time.strftime('%m/%d/%Y %H:%M:%S')}\"")
        end
        @run['node_controller'].add_cougaar_event_params
        @run['node_controller'].start_all_nodes(self)
        @run.add_to_interrupt_stack do 
          do_action "StopSociety"
        end
      end
    end

    class StopSociety <  Cougaar::Action
      PRIOR_STATES = ["SocietyRunning"]
      RESULTANT_STATE = "SocietyStopped"
      DOCUMENTATION = Cougaar.document {
        @description = "Stop a running society."
        @example = "do_action 'StopSociety'"
      }
      def perform
        @run['node_controller'].stop_all_nodes(self)
      end
    end
  
    class RestartNodes < Cougaar::Action
      PRIOR_STATES = ["SocietyRunning"]
      DOCUMENTATION = Cougaar.document {
        @description = "Restarts stopped node(s)."
        @parameters = [
          :nodes => "*parameters, The list of nodes to restart"
        ]
        @example = "do_action 'RestartNodes', 'FWD-A', 'FWD-B'"
      }
      def initialize(run, *nodes)
        super(run)
        @nodes = nodes
      end
      
      def to_s
        return super.to_s+"(#{@nodes.join(', ')})"
      end
      
      def perform
        @nodes.each do |node|
          cougaar_node = @run.society.nodes[node]
          if cougaar_node
            @run['node_controller'].restart_node(self, cougaar_node)
          else
            @run.error_message "Cannot restart node #{node}, node unknown."
          end
        end
      end
    end

    class KillNodes < Cougaar::Action
      PRIOR_STATES = ["SocietyRunning"]
      DOCUMENTATION = Cougaar.document {
        @description = "Kills running node(s)."
        @parameters = [
          :nodes => "*parameters, The list of nodes to kill"
        ]
        @example = "do_action 'KillNodes', 'FWD-A', 'FWD-B'"
      }
      def initialize(run, *nodes)
        super(run)
        @nodes = nodes
      end
      
      def to_s
        return super.to_s+"(#{@nodes.join(', ')})"
      end
      
      def perform
        @nodes.each do |node|
          cougaar_node = @run.society.nodes[node]
          if cougaar_node
            @run['node_controller'].kill_node(self, cougaar_node)
          else
            @run.error_message "Cannot kill node #{node}, node unknown."
          end
        end
      end
    end
    
    class MoveAgent < Cougaar::Action
      PRIOR_STATES = ["SocietyRunning"]
      DOCUMENTATION = Cougaar.document {
        @description = "Moves an Agent from its current node to the supplied node."
        @parameters = [
          {:agent => "String, The name of the Agent to move."},
          {:node => "String, The name of the Node to move the agent to."}
        ]
        @example = "do_action 'MoveAgent', '1-35-ARBN', 'FWD-B'"
      }

      def initialize(run, agent, node)
        super(run)
        @agent = agent
        @node = node
      end
      
      def perform
        # example format of move http request
        # http://sv116:8800/$1-35-ARBN/move?op=Move&mobileAgent=1-35-ARBN&originNode=&destNode=FWD-D&isForceRestart=false&action=Add
        #

        begin
          # First do a bunch of error checking
          if (@run.society.nodes[@node] == nil)
            @run.info_message "No node #{@node} to move #{@agent} to!"
          elsif (@run.society.agents[@agent] == nil)
            @run.info_message "No agent #{@agent} in society to move to #{@node}!"
          else
            # Could (should?) also check if the agent is already on the named node
            # Note we could ask the Node to move the agent, to avoid any timing issues. But that
            # seems to leave ugly WARNs and ERRORs in the logs that have no real harm
      #	    uri = "#{@run.society.agents[@agent].node.uri}/move?op=Move&mobileAgent=#{@agent}&originNode=&destNode=#{@node}&isForceRestart=false&action=Add"
            uri = "#{@run.society.agents[@agent].uri}/move?op=Move&mobileAgent=#{@agent}&originNode=&destNode=#{@node}&isForceRestart=false&action=Add"
            result = Cougaar::Communications::HTTP.get(uri)
            unless result
              @run.error_message "Error moving agent #{@agent} using uri #{uri}" 
              return
            end
          end
        rescue
          @run.error_message "Could not move agent #{@agent} to #{@node} via HTTP\n#{$!.to_s}"
          return
        end
      end
      
      def to_s
        super.to_s+"('#{@agent}', '#{@node}')"
      end
    end      
    
  end
  
  module States
    class SocietyLoaded < Cougaar::NOOPState
      DOCUMENTATION = Cougaar.document {
        @description = "Indicates that the society was loaded from XML, a Ruby script or a CSmart database."
      }
    end
    
    class SocietyRunning < Cougaar::NOOPState
      DOCUMENTATION = Cougaar.document {
        @description = "Indicates that the society started."
      }
    end
    
    class SocietyStopped < Cougaar::NOOPState
      DOCUMENTATION = Cougaar.document {
        @description = "Indicates that the society stopped."
      }
    end
    
    class RunStopped < Cougaar::State
      DEFAULT_TIMEOUT = 20.minutes
      PRIOR_STATES = ["SocietyStopped"]
      DOCUMENTATION = Cougaar.document {
        @description = "Indicates that the run was stopped."
      }
      def process
        while(true)
          return if @run.stopped?
          sleep 2
        end
        @run.info_message "Run Stopped"
      end
    end
  end
  
end

  
