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

require 'parsedate'

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
          node.add_parameter("-Dorg.cougaar.event.experiment=#{@run.comms.local_hostname}-#{@run.name}")
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
        puts "Sending message to #{node.host.name} -- [command[start_#{@node_type}node]#{msgs[node]}] \n" if @debug
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
        puts "Could not stop node #{node.name}(#{@pids[node.name]}) on host #{host.host_name}"
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
      puts result if @debug
    end
    
  end
  
  module Actions
  
    class AdvanceTime < Cougaar::Action
      DOCUMENTATION = Cougaar.document {
        @description = "Advances the scenario time and sets the execution rate."
        @parameters = [
          {:time_to_advance => "default=1.day, seconds to advance the cougaar clock total."},
          {:time_step => "default=1.day, seconds to advance the cougaar clock each step."},
          {:wait_for_quiescence => "default=true, if false, will return without waiting for quiescence after final step."},
          {:execution_rate => "default=1.0, The new execution rate (1.0 = real time, 2.0 = 2X real time)"},
          {:timeout => "default=1.hour, Timeout for waiting for quiescence"},
          {:debug => "default=false, Set 'true' to debug action"}
        ]
        @example = "do_action 'AdvanceTime', 24.days, 1.day, true, 1.0, 1.hour, false"
      }

      def initialize(run, time_to_advance=1.day, time_step=1.day, wait_for_quiescence=true, execution_rate=1.0, timeout=1.hour, debug=false)
        super(run)
        @debug = debug
        @time_to_advance = time_to_advance
        @time_step = time_step
        @wait_for_quiescence = wait_for_quiescence
        @execution_rate = execution_rate
        @timeout = timeout
        @scenario_time = /Scenario Time<\/td><td>([^<]*)<\/td>/
      end
      
      def perform
        # true => include the node agent
        @run.info_message "Advancing time: #{@time_to_advance/3600} hours Step: #{@time_step/3600} hours Rate: #{@execution_rate}" if @debug

        # We'll advance step by step, then by the remaining seconds
        steps_to_advance = (@time_to_advance / @time_step).floor
        seconds_to_advance = @time_to_advance % @time_step
        
        if @debug
          @run.info_message "Going to step forward #{steps_to_advance} steps and #{seconds_to_advance} seconds."
        end
        
        if @expected_start_time
          start_time = @expected_start_time
        else
          start_time = get_society_time
        end
        
        steps_to_advance.times do | step |
          if @debug
            @run.info_message "About to step forward one step (#{@time_step/3600} hours)"
          end
          if get_society_time > (start_time + (step + 1) * @time_step)
            @run.info_message "Skipping time step #{step+1}...society time #{get_society_time} is past #{start_time + (step+1)*@time_step}"
            next
          end
          unless advance_and_wait(@time_step)
            @run.error_message "Timed out advancing time...society not quiescent."
            return
          end
        end
        if seconds_to_advance > 0 && get_society_time < (start_time + (steps_to_advance * @time_step) + seconds_to_advance)
          if @debug
            @run.info_message "About to step forward #{seconds_to_advance} seconds"
          end
          unless advance_and_wait(seconds_to_advance)
            @run.error_message "Timed out advancing time...society not quiescent."
            return
          end
        end
      end
      
      def get_society_time
        nca_node = @run.society.agents['NCA'].node.agent
        result, uri = Cougaar::Communications::HTTP.get(nca_node.uri+"/timeControl")
        md = @scenario_time.match(result)
        if md
          return Time.utc(*ParseDate.parsedate(md[1]))
        end
      end

      def advance_and_wait(time_in_seconds)
        result = true
        @run.society.each_node do |node|
	  next unless node.active?
          myuri = node.agent.uri+"/timeControl?timeAdvance=#{time_in_seconds*1000}&executionRate=#{@execution_rate}"
          @run.info_message "URI: #{myuri}" if @debug
          data, uri = Cougaar::Communications::HTTP.get(myuri)
          md = @scenario_time.match(data)
          if md
            @run.info_message "OLD TIME: #{md[1]}" if @debug
          else
            @run.error_message "ERROR Accessing timeControl Servlet at node #{node.name}.  Data was #{data}"
          end
        end

        if @debug
          @run.info_message "Finished sending servlet requests"
        end

        # now wait for quiescence
        if @wait_for_quiescence
          comp = @run["completion_monitor"]
          if !comp
            @run.error_message "Completion Monitor not installed.  Cannot wait for quiescence"
            return false
          end
          if @debug
            @run.info_message "About to wait for quiescence"
          end
          sleep 20.seconds
          if comp.getSocietyStatus() == "INCOMPLETE"
            result = comp.wait_for_change_to_state("COMPLETE", @timeout)
          end
        end
        @run.info_message "Society time advanced to #{get_society_time}"
        return result
      end

    end # class
 
 
    class AdvanceTimeFrom < AdvanceTime
      DOCUMENTATION = Cougaar.document {
        @description = "Advances the scenario time and sets the execution rate."
        @parameters = [
          {:expected_start_time => "required, date that the society is assumed to be on (mm/dd/yy hh:mm:ss)"},
          {:time_to_advance => "default=1.day, seconds to advance the cougaar clock total."},
          {:time_to_advance => "default=1.day, seconds to advance the cougaar clock total."},
          {:time_step => "default=1.day, seconds to advance the cougaar clock each step."},
          {:wait_for_quiescence => "default=true, if false, will return without waiting for quiescence after final step."},
          {:execution_rate => "default=1.0, The new execution rate (1.0 = real time, 2.0 = 2X real time)"},
          {:timeout => "default=1.hour, Timeout for waiting for quiescence"},
          {:debug => "default=false, Set 'true' to debug action"}
        ]
        @example = "do_action 'AdvanceTimeFrom', '11/08/05', 24.days, 1.day, true, 1.0, 1.hour, false"
      }
      def initialize(run, expected_start_time, time_to_advance=1.day, time_step=1.day, wait_for_quiescence=true, execution_rate=1.0, timeout=1.hour, debug=false)
        @expected_start_time = Time.utc(*ParseDate.parsedate(expected_start_time))
        super(time_to_advance, time_step, wait_for_quiescence, execution_rate, timeout, debug)
      end
    end
 
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
            # kills don't always work first time, try again to be sure
            @run.comms.new_message(host).set_body("command[rexec]killall -9 java").request(30)
            @run.comms.new_message(host).set_body("command[cpu]0").send()
            @run.comms.new_message(host).set_body("command[shutdown]").send()
          end
        end
        @run.info_message "Waiting for ACME services to restart"
        sleep 20 # wait for all acme servers to start back up
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

  
