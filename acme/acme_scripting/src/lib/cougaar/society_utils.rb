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

  module Model
  
    class SocietyComparison
    
      attr_accessor :society1, :society2, :differences
      
      def initialize(society1, society2)
        @society1 = society1
        @society2 = society2
        @differences = []
      end
      
      class RemovalDifference
        def initialize(object)
          super(kind, object)
          @var = var
          @value1 = value1
          @value2 = value2
        end
      end
      
      class InstanceDifference
        def initialize(object, var, value1, value2)
          super(kind, object)
          @var = var
          @value1 = value1
          @value2 = value2
        end
      end
      
      def instance_diff(object, var, value1, value2)
        @differences << InstanceDifference.new(object, var, value1, value2)
      end
      
      def component_removed(list)
        @differences << Instance
      end
      
      def diff
        diff_hosts
        diff_nodes
        diff_agents
        return self
      end
      
      private
      
      def diff_hosts
        society1_hosts = []
        society1.each_host {|host| society1_hosts << host.name}
        society2_hosts = []
        society2.each_host {|host| society2_hosts << host.name}
        removed_hosts = society1_hosts - society2_hosts
        added_hosts = society2_hosts - society1_hosts
      end
      
      def diff_nodes
        society1_nodes = []
        society1.each_node {|node| society1_nodes << node.name}
        society2_nodes = []
        society2.each_node {|node| society2_nodes << node.name}
        removed_nodes = society1_nodes - society2_nodes
        added_nodes = society2_nodes - society1_nodes
      end
      
      def diff_agents
        society1_agents = []
        society1.each_agent {|agent| society1_agents << agent.name}
        society2_agents = []
        society2.each_agent {|agent| society2_agents << agent.name}
        removed_agents = society1_agents - society2_agents
        added_agents = society2_agents - society1_agents
      end
    end
    
    
    ##
    # The SocietyMonitor collects chagnes to the cougaar society and 
    # reports them to instances.
    #
    #
    class SocietyMonitor
      
      @@monitors = []
      def self.add(monitor)
        @@monitors << monitor
      end
      
      def self.each_monitor
        @@monitors.each {|monitor| yield monitor}
      end
    
      def initialize
        SocietyMonitor.add(self)
      end
      
      def host_added(host) ; end
      def host_removed(host) ; end
      
      def node_added(node) ; end
      def node_removed(node) ; end
      
      def agent_added(agent) ; end
      def agent_removed(agent) ; end
      
      def component_added(component) ; end
      def component_removed(component) ; end
      
      def self.enable_stdout
        m = SocietyMonitor.new
        def m.host_added(host)
          puts "Host added        #{host.host_name} < #{host.society.name}"
        end
        def m.host_removed(host)
          puts "Host removed      #{host.host_name} < #{host.society.name}"
        end
        def m.node_added(node)
          puts "Node added        #{node.name} < #{node.host.host_name} < #{node.host.society.name}"
        end
        def m.node_removed(node)
          puts "Node removed      #{node.name} < #{node.host.host_name} < #{node.host.society.name}"
        end
        def m.agent_added(agent)
          puts "Agent added       #{agent.name} < #{agent.node.name} < #{agent.node.host.host_name} < #{agent.node.host.society.name}"
        end
        def m.agent_removed(agent)
          puts "Agent removed     #{agent.name} < #{agnet.node.name} on #{agent.node.host.host_name} < #{agent.node.host.society.name}"
        end
        def m.component_added(component)
          puts "Component added   #{component.name} < #{component.agent.name} < #{component.agent.node.name} < #{component.agent.node.host.host_name} < #{component.agent.node.host.society.name}"
        end
        def m.agent_removed(agent)
          puts "Component removed #{component.name} < #{component.agent.name} < #{component.agent.node.name} < #{component.agent.node.host.host_name} < #{component.agent.node.host.society.name}"
        end
      end
    end
  end
end