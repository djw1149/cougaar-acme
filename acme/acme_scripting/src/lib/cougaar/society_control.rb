##
#  <copyright>
#  Copyright 2002 InfoEther, LLC
#  under sponsorship of the Defense Advanced Research Projects Agency (DARPA).
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the Cougaar Open Source License as published by
#  DARPA on the Cougaar Open Source Website (www.cougaar.org).
#
#  THE COUGAAR SOFTWARE AND ANY DERIVATIVE SUPPLIED BY LICENSOR IS
#  PROVIDED 'AS IS' WITHOUT WARRANTIES OF ANY KIND, WHETHER EXPRESS OR
#  IMPLIED, INCLUDING (BUT NOT LIMITED TO) ALL IMPLIED WARRANTIES OF
#  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, AND WITHOUT
#  ANY WARRANTIES AS TO NON-INFRINGEMENT.  IN NO EVENT SHALL COPYRIGHT
#  HOLDER BE LIABLE FOR ANY DIRECT, SPECIAL, INDIRECT OR CONSEQUENTIAL
#  DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE OF DATA OR PROFITS,
#  TORTIOUS CONDUCT, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
#  PERFORMANCE OF THE COUGAAR SOFTWARE.
# </copyright>
#

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
          node.add_parameter("-Dorg.cougaar.event.experiment=#{@run.name}")
        end
      end
    end
    
    def start_all_nodes(action)
      @run.society.each_active_host do |host|
        host.each_node do |node|
          if @xml_model
            post_node_xml(node)
            msg_body = launch_xml_node(node)
          else
            msg_body = launch_db_node(node)
          end
          puts "Sending message to #{host.name} -- [command[start_#{@node_type}node]#{msg_body}] \n" if @debug
          result = @run.comms.new_message(host).set_body("command[start_#{@node_type}node]#{msg_body}").request(@timeout)
          if result.nil?
            action.raise_failure "Could not start node #{node.name} on host #{host.host_name}"
          end
          @pids[node.name] = result.body
        end
      end
    end
    
    def stop_all_nodes(action)
      last_node = nil
      @run.society.each_host do |host|
        host.each_node do |node|
          nameserver = false
          host.each_facet(:service) do |facet|
            nameserver = true if facet[:service]=="nameserver"
          end
          if nameserver
            last_node = node
          else
            stop_node(node)
          end
        end
      end
      stop_node(last_node) if last_node
      @pids.clear
    end
    
    def stop_node(node)
      host = node.host
      puts "Sending message to #{host.name} -- command[stop_#{@node_type}node]#{@pids[node.name]} \n" if @debug
      result = @run.comms.new_message(host).set_body("command[stop_#{@node_type}node]#{@pids[node.name]}").request(60)
      if result.nil?
        puts "Could not stop node #{node.name}(#{@pids[node.name]}) on host #{host.host_name}"
      end
    end
    
    def restart_node(action, node)
      if @xml_model
        msg_body = launch_xml_node(node, "xml")
      else
        msg_body = launch_db_node(node)
      end
      puts "RESTART: Sending message to #{node.host.name} -- [command[start_#{@node_type}node]#{msg_body}] \n" if @debug
      result = @run.comms.new_message(node.host).set_body("command[start_#{@node_type}node]#{msg_body}").request(@timeout)
      if result.nil?
        puts "Could not start node #{node.name} on host #{node.host.host_name}"
      end
      @pids[node.name] = result.body
    end
    
    def kill_node(action, node)
      pid = @pids[node.name]
      if pid
        @pids.delete(node.name)
        puts "KILL: Sending message to #{node.host.name} -- command[stop_#{@node_type}node]#{pid} \n" if @debug
        result = @run.comms.new_message(node.host).set_body("command[stop_#{@node_type}node]#{pid}").request(60)
        if result.nil?
          puts "Could not kill node #{node.name}(#{pid}) on host #{node.host.host_name}"
        end
      else
        puts "Could not kill node #{node.name}...node does not have an active PID."
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
      result = Cougaar::Communications::HTTP.post("http://#{node.host.host_name}:9444/xmlnode/#{node.name}.rb", node_society.to_ruby, "x-application/ruby")
      puts result if @debug
    end
    
  end
  
  module Actions

    class AdvanceTime < Cougaar::Action
      DOCUMENTATION = Cougaar.document {
        @description = "Advances the scenario time and sets the execution rate."
        @parameters = [
          {:time_to_advance => "default=86400000 (1 day) millisecs to advance the cougaar clock total."},
          {:time_step => "default=86400000 (1 day) millisecs to advance the cougaar clock each step."},
          {:execution_rate => "default=1.0, The new execution rate (1.0 = real time, 2.0 = 2X real time)"},
          {:debug => "default=false, Set 'true' to debug action"}
        ]
        @example = "do_action 'AdvanceTime', 3600000, 60000, 1.0, false"
      }

      def initialize(run, time_to_advance=86400000, time_step=86400000, execution_rate=1.0, debug=false)
        super(run)
        @debug = debug
        @time_to_advance = time_to_advance
        @time_step = time_step
        @execution_rate = execution_rate
        @expected_result = Regexp.new("Scenario Time");
      end
      
      def perform
        # true => include the node agent
        puts "Advancing time: #{@time_to_advance} Step: #{@time_step} Rate: #{@execution_rate}" if @debug

        # We'll advance step by step, then by the remaining seconds
        steps_to_advance = (@time_to_advance / @time_step).floor
        seconds_to_advance = @time_to_advance % @time_step
        if @debug
          ::Cougaar.logger.info "going to step forward #{steps_to_advance} steps and #{seconds_to_advance} seconds"
        end

        steps_to_advance.times do
          if @debug
            ::Cougaar.logger.info "About to step forward one step (#{@time_step / 1000} seconds)"
          end
          advance_and_wait(@time_step)
        end
        if seconds_to_advance > 0
          if @debug
            ::Cougaar.logger.info "About to step forward #{seconds_to_advance} seconds"
          end
          advance_and_wait(1000 * seconds_to_advance)
        end
      end

      def advance_and_wait(time)
        @run.society.each_node do |node|
          myuri = "http://#{node.host.name}:#{@run.society.cougaar_port}/$#{node.name}/timeControl?timeAdvance=#{time}&executionRate=#{@execution_rate}"
          puts "URI: #{myuri}" if @debug
          data, uri = Cougaar::Communications::HTTP.get(myuri)
          puts data if @debug
          if (@expected_result.match(data) == nil)
            puts "ERROR Accessing timeControl Servlet at node #{node.name}"
            raise Exception.exception("ERROR Accessing timeControl Servlet at node #{node.name}");
          end
        end

        # now wait for quiescence
        comp = @run["completion_monitor"]
        if !comp
          ::Cougaar.logger.error "Completion Monitor not installed.  Cannot wait for quiescence"
          puts "Completion Monitor not installed.  Cannot wait for quiescence"
        end
        if @debug
          ::Cougaar.logger.info "Finished sending servlet requests; about to wait for quiescence"
        end
        sleep 20.seconds
        if comp.getSocietyStatus() == "INCOMPLETE"
          comp.wait_for_change_to_state("COMPLETE")
        end
      end

    end # class
 
    class KeepSocietySynchronized < Cougaar::Action
      PRIOR_STATES = ["CommunicationsRunning"]
      RESULTANT_STATE = "SocietyRunning"
      DOCUMENTATION = Cougaar.document {
        @description = "Maintain a synchronization of Agents-Nodes-Hosts from Lifecycle CougaarEvents."
        @example = "do_action 'KeepSocietySynchronized'"
      }
      def perform
        @run.comms.on_cougaar_event do |event|
          if event.component=="SimpleAgent" || event.component=="ClusterImpl"
            match = /.*AgentLifecycle\(([^\)]*)\) Agent\(([^\)]*)\) Node\(([^\)]*)\) Host\(([^\)]*)\)/.match(event.data)
            if match
              cycle, agent, node, host = match[1,4]
              if cycle == "Started" && @run.society.agents[agent] && node != @run.society.agents[agent].node.name
                @run.society.agents[agent].move_to(node)
                @run.info_message "Moving agent: #{agent} to node: #{node}"
              end
            end
          end
        end
      end
    end
    
    class CleanupSociety < Cougaar::Action
      PRIOR_STATES = ["CommunicationsRunning"]
      DOCUMENTATION = Cougaar.document {
        @description = "Stop all Java processes and remove actives stressors on all hosts listed in the society."
        @example = "do_action 'CleanupSociety'"
      }
      
      def perform
        ['operator', 'acme'].each do |service|
          @run.society.each_service_host(service) do |host|
            @run.comms.new_message(host).set_body("command[rexec]killall -9 java").request(30)
            @run.comms.new_message(host).set_body("command[cpu]0").send()
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
        @run['node_controller'].add_cougaar_event_params
        @run['node_controller'].start_all_nodes(self)
      end

    end
    
    class EgregiousHack <  Cougaar::Action
      def initialize(run, filename)
        super(run)
        @filename = filename
      end

      def perform()
        mobysociety = Cougaar::Model::Society.new("moby")
        mobyhost = Cougaar::Model::Host.new("moby")
        mobysociety.add_host(mobyhost)
        mobynode = Cougaar::Model::Node.new("moby")
        mobyhost.add_node(mobynode)

        run.society.each_host do |host|
	        host.each_node do |node|
            node.each_agent do |agent|
              mobynode.add_agent(agent.clone(node))
		        end
	        end
        end

        print "WRITING: moby.xml as #{@filename}\n"
        File.open(@filename, "wb") {|file| file.puts(mobysociety.to_xml)}
        print "DONE Writing: #{@filename}\n"
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
            raise_failure "Cannot restart node #{node}, node unknown."
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
            puts "Cannot kill node #{node}, node unknown."
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
        begin
          uri = "#{@run.society.agents[@agent].uri}/move?op=Move&mobileAgent=#{@agent}&originNode=&destNode=#{@node}&isForceRestart=false&action=Add"
          result = Cougaar::Communications::HTTP.get(uri)
          raise_failure "Error moving agent" unless result
        rescue
          raise_failure "Could not move agent via HTTP", $!
        end
       #http://sv116:8800/$1-35-ARBN/move?op=Move&mobileAgent=1-35-ARBN&originNode=&destNode=FWD-D&isForceRestart=false&action=Add
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
        puts "Run Stopped"
      end
    end
  end
  
end

  
