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
    
    def start_all_nodes
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
            raise_failure "Could not start node #{node.name} on host #{host.host_name}"
          end
          @pids[node.name] = result.body
        end
      end
    end
    
    def stop_all_nodes
      @run.society.each_host do |host|
        host.each_node do |node|
          puts "Sending message to #{host.name} -- command[stop_#{@node_type}node]#{@pids[node.name]} \n" if @debug
          result = @run.comms.new_message(host).set_body("command[stop_#{@node_type}node]#{@pids[node.name]}").request(60)
          if result.nil?
            raise_failure "Could not stop node #{node.name}(#{@pids[node.name]}) on host #{host.host_name}"
          end
        end
      end
      @pids.clear
    end
    
    def restart_node(node)
      if @xml_model
        msg_body = launch_xml_node(node, "xml")
      else
        msg_body = launch_db_node(node)
      end
      puts "RESTART: Sending message to #{node.host.name} -- [command[start_#{@node_type}node]#{msg_body}] \n" if @debug
      result = @run.comms.new_message(node.host).set_body("command[start_#{@node_type}node]#{msg_body}").request(@timeout)
      if result.nil?
        raise_failure "Could not start node #{node.name} on host #{node.host.host_name}"
      end
      @pids[node.name] = result.body
    end
    
    def kill_node(node)
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
  
    class StartSociety < Cougaar::Action
      PRIOR_STATES = ["CommunicationsRunning"]
      RESULTANT_STATE = "SocietyRunning"
      
      def initialize(run, timeout=120, debug=false)
        super(run)
        unless timeout.kind_of?(Numeric) && (debug==true || debug==false)
            raise_failure "StartSociety usage: do_action 'StartSociety', timeout (default 120), debug (default false)"
        end
        @run['node_controller'] = ::Cougaar::NodeController.new(run, timeout, debug)
      end
      
      def perform
        @run['node_controller'].add_cougaar_event_params
        @run['node_controller'].start_all_nodes
      end

    end
    
    class StopSociety <  Cougaar::Action
      PRIOR_STATES = ["SocietyRunning"]
      RESULTANT_STATE = "SocietyStopped"
      def perform
        @run['node_controller'].stop_all_nodes
      end
    end
  
    class RestartNodes < Cougaar::Action
      PRIOR_STATES = ["SocietyRunning"]
      def initialize(run, *nodes)
        super(run)
        @nodes = nodes
      end
      def perform
        @nodes.each do |node|
          cougaar_node = @run.society.nodes[node]
          if cougaar_node
            @run['node_controller'].restart_node(cougaar_node)
          else
            raise_failure "Cannot restart node #{node}, node unknown."
          end
        end
      end
    end

    class KillNodes < Cougaar::Action
      PRIOR_STATES = ["SocietyRunning"]
      def initialize(run, *nodes)
        super(run)
        @nodes = nodes
      end
      def perform
        @nodes.each do |node|
          cougaar_node = @run.society.nodes[node]
          if cougaar_node
            @run['node_controller'].kill_node(cougaar_node)
          else
            puts "Cannot kill node #{node}, node unknown."
          end
        end
      end
    end
    
  end
  
  module States
    class SocietyLoaded < Cougaar::NOOPState
    end
    
    class SocietyRunning < Cougaar::NOOPState
    end
    
    class SocietyStopped < Cougaar::NOOPState
    end
    
    class RunStopped < Cougaar::State
      DEFAULT_TIMEOUT = 20.minutes
      PRIOR_STATES = ["SocietyStopped"]
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

  
