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
    
    class SocietyLayout
      attr_accessor :society_file, :layout_file, :hosts_file, :society
      
      def self.from_files(society_file, layout_file, hosts_file)
        layout = SocietyLayout.new
        layout.society_file = society_file
        layout.layout_file = layout_file
        layout.hosts_file = hosts_file
        layout.load_files
        return layout
      end
      
      def self.from_society(society, layout_file, hosts_file)
        layout = SocietyLayout.new
        layout.society = society
        layout.layout_file = layout_file
        layout.hosts_file = hosts_file
        layout.load_files
        return layout
      end
      
      def load_files
        @society = load_file(@society_file) if @society_file
        @society_layout = load_file(@layout_file) if @layout_file
        @society_hosts = load_file(@hosts_file) if @hosts_file
      end
      
      def layout
        # build temporary host and node and move all agents to it
        guid = Time.now.to_i
        @society.add_host("host-#{guid}") { |host| host.add_node("node-#{guid}") }
        agentlist = []
        @society.each_agent { |agent| agentlist << agent }
        agentlist.each {|agent| agent.move_to("node-#{guid}")}
        # remove all existing hosts/nodes
        purgelist = []
        @society.each_host { |host| purgelist << host unless host.name=="host-#{guid}" }
        purgelist.each { |host| society.remove_host(host) } 
        # build a list of available hosts
        hostlist = []
        @society_hosts.each_host do |host|
          host.each_facet("type") do |facet|
            hostlist << host if facet['type']=='node'
          end
        end
        # perform layout
        hostindex = 0
        @society_layout.each_host do |host|
          if hostindex == hostlist.size
            raise "Not enough hosts in #{@host_file} for the society layout in #{@layout_file}"
          end
          @society.add_host(hostlist[hostindex].name) do |newhost|
            host.each_facet { |facet| newhost.add_facet(facet.clone) }
            host.each_node do |node|
              newhost.add_node(node.name)
              node.each_agent do |agent| 
                to_move = @society.agents[agent.name]
                unless to_move
                  raise "Layout specifies agent '#{agent.name}' that is not defined in the society"
                end
                to_move.move_to(node.name)
              end
            end
          end
          hostindex += 1
        end
        # check to make sure we laid out all the agents
        agentlist = []
        @society.nodes["node-#{guid}"].each_agent { |agent| agentlist << agent }
        if agentlist.size>0
          raise "Did not layout the agents: #{ agentlist.join(', ') }"
        end
        @society.remove_host("host-#{guid}")
      end
      
      def to_ruby_file(filename)
        f = File.open(filename, "w")
        f.puts(@society.to_ruby)
        f.close
      end
      
      def to_xml_file(filename)
        f = File.open(filename, "w")
        f.puts(@society.to_xml)
        f.close
      end
      
      def tree
        @society.each_host do |host|
          puts host.name
          host.each_node do |node|
            puts "  "+node.name
            node.each_agent do |agent|
              puts "    "+agent.name
            end
          end
        end
      end
      
      def load_file(file)
        if file[-3..-1] == '.rb'
          return Cougaar::SocietyBuilder.from_ruby_file(file).society
        else
          return Cougaar::SocietyBuilder.from_xml_file(file).society
        end
      end
    end
    
    class Communities
      include Enumerable
      
      def initialize(society)
        @society = society
        @communities = []
        yield self if block_given?
      end
      
      def add(name)
        @communities.each {|community| return if community.name==name}
        community = Community.new(name, @society)
        yield community
        @communities << community
      end
      
      def each(&block)
        @communities.each { |community| yield community }
      end
      
      def to_xml
        xml = []
        xml << "<Communities>"
        each do |community|
          community.to_xml(xml)
        end
        xml << "</Communities>"
        xml.join("\n")
      end
      
      class Community
        include Enumerable
        attr_accessor :name
        
        def initialize(name, society)
          @name = name
          @society = society
          @entities = []
          @attributes = []
        end
        
        def add_attribute(id, value)
          @attributes << [id, value]
        end
        
        def remove_attribute(id)
          @attributes.delete_if { |attr| attr[0]==id }
        end
        
        def replace_attribute(id, value)
          @attributes.size.times do |i|
            if @attributes[i][0]==id
              @attributes[i] == [id, value]
              return
            end
          end
        end
          
        def each_attribute
          @attributes.each { |attr| yield attr[0], attr[1] }
        end
        
        def to_xml(xml = nil)
          xml ||= []
          xml << "  <Community Name='#{@name}' >"
          each_attribute do |id, value|
            xml << "    <Attribute ID='#{id}' Value='#{value}' />"
          end
          each do |entity|
            entity.to_xml(xml)
          end
          xml << "  </Community>"
          xml.to_s
        end
        
        def each(&block)
          @entities.each { |entity| yield entity }
        end
        
        def add_agent(agent, &block)
          raise "Unknown agent: #{agent}" unless @society.agents[agent]
          @entities << add_entity(agent, "Agent", &block)
        end
        
        def add_node(node, &block)
          raise "Unknown node: #{node}" unless @society.nodes[node]
          @entities << add_entity(node, "Node", &block)
        end
        
        def add_nodes(*nodes, &block)
          nodes.each do |node|
            raise "Unknown node: #{node}" unless @society.nodes[node]
            @entities << add_entity(node, 'Node', &block)
          end
        end
  
        def add_agents_on_nodes(node_agents, *nodes, &block)
          nodes.each do |node|
            @entities << add_entity(node, 'Agent', &block) if node_agents
            raise "Unknown node: #{node}" unless @society.nodes[node]
            @society.nodes[node].each_agent do |agent|
              @entities << add_entity(agent.name, 'Agent', &block)
            end
          end
        end
        
        def add_all_agents(&block)
          @society.each_agent(true) do |agent|
            @entities << add_entity(agent.name, 'Agent', &block)
          end
        end
        
        def add_entity(name, entity_type, &block)
          entity = Entity.new(name, entity_type)
          yield entity if block_given?
          entity
        end
        
        def [](member_id)
          @members.each do |member|
            return member if member.name==member_id
          end
        end
        
        class Entity
          attr_accessor :name, :entity_type
          
          def initialize(name, entity_type)
            @name = name
            @entity_type = entity_type
            @roles = []
            @attributes = []
          end

          def add_attribute(id, value)
            @attributes << [id, value]
          end
          
          def remove_attribute(id)
            @attributes.delete_if { |attr| attr[0]==id }
          end
          
          def replace_attribute(id, value)
            @attributes.size.times do |i|
              if @attributes[i][0]==id
                @attributes[i] == [id, value]
                return
              end
            end
          end
          
          def each_attribute
            @attributes.each { |attr| yield attr[0], attr[1] }
          end
          
          def to_xml(xml=nil)
            xml ||= []
            xml << "    <Entity Name='#{@name}' >"
            xml << "      <Attribute ID='EntityType' Value='#{@entity_type}' />"
            @roles.each do |role|
              xml << "      <Attribute ID='Role' Value='#{role}' />"
            end
            each_attribute do |id, value|
              xml << "      <Attribute ID='#{id}' Value='#{value}' />"
            end
            xml << "    </Entity>"
            xml.to_s
          end
          
          def add_role(role)
            @roles << role
          end
        end
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
      
      def self.remove(monitor)
        @@monitors.delete(monitor)
      end
      
      def self.each_monitor
        @@monitors.each {|monitor| yield monitor}
      end
      
      def finish
        SocietyMonitor.remove(self)
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
