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

require 'cougaar/experiment'

module Cougaar

  module Actions
    class LayoutSociety < ::Cougaar::Action
      PRIOR_STATES = ["SocietyLoaded"]
      DOCUMENTATION = Cougaar.document {
        @description = "Layout a loaded society using the supplied layout and optional hosts file."
        @parameters = [
          {:layout => "The layout file (valid society file in .xml or .rb)."},
          {:hosts => "default=nil, If present, uses the hosts from this file instead of those in the layout file."}
        ]
        @example = "do_action 'LayoutSociety', '1ad-layout.xml', 'sa-hosts.xml'"
      }
      
      def initialize(run, layout, hosts=nil)
        super(run)
        @layout = layout
        @hosts = hosts
        @layout = ::Cougaar::Model::SocietyLayout.new
        @layout.layout_file = layout
        @layout.hosts_file = hosts
        @layout.load_files
      end
      
      def perform
        @run.info_message "Layout file #{@layout.layout_file}"
        @run.archive_file(@layout.layout_file, "Layout file for the society run")
        if @hosts
          @run.info_message "Hosts file  #{@layout.hosts_file}"
          @run.archive_file(@layout.hosts_file, "Hosts file for the society run")
        else
          @run.info_message "No hosts file used for layout"
        end
        @layout.society = @run.society
        @layout.layout
      end

    end
  end

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
      
      def self.from_files(society_file, layout_file, hosts_file = nil)
        layout = SocietyLayout.new
        layout.society_file = society_file
        layout.layout_file = layout_file
        layout.hosts_file = hosts_file
        layout.load_files
        return layout
      end
      
      def self.from_society(society, layout_file, hosts_file = nil)
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
        hostlist = nil
        hostgroups = nil
        unused_hostlist = nil
        if @society_hosts
          hostgroups = {}
          unused_hostlist = []
          @society_hosts.each_host do |host|
            target = false
            host.each_facet(:service) do |facet|
              target = true if facet[:service].downcase=='acme'
            end
            if target
              group = host.get_facet(:group)
              if group
                list = hostgroups[group]
                list ||= []
                list << host
                hostgroups[group]=list
              else
                list = hostgroups[:ungrouped]
                list ||= []
                list << host
                hostgroups[:ungrouped] = list
              end
            else
              unused_hostlist << host
            end
          end
        end
        
        # copy layout and host society's facets to the society...
        @society_layout.each_facet { |facet| @society.add_facet(facet.clone) }
        @society_hosts.each_facet { |facet| @society.add_facet(facet.clone) } if @society_hosts
        
        # perform layout
        @society_layout.each_host do |host|
          if @society_hosts
            if host.has_facet?(:group)
              target_host = hostgroups[host.get_facet(:group)].shift
              #puts "Group #{host.get_facet(:group)} has #{hostgroups[host.get_facet(:group)].size} hosts left"
              unless target_host
                raise "Not enough hosts in #{@host_file} for group #{host.get_facet(:group)} in the society layout file #{@layout_file}"
              end
            else
              target_host = hostgroups[:ungrouped].shift
              #puts "Group ungrouped has #{hostgroups[:ungrouped].size} hosts left"
              unless target_host
                raise "Not enough hosts in #{@host_file} for ungrouped in the society layout file #{@layout_file}"
              end
            end
          else
            target_host = host
          end
          @society.add_host(target_host.name) do |newhost|
            host.each_facet { |facet| newhost.add_facet(facet.clone) }
            if target_host!=host
              target_host.each_facet { |facet| newhost.add_facet(facet.clone) }
            end
            host.each_node do |node|
              newhost.add_node(node.name) do |newnode|
                node.each_facet { |facet| newnode.add_facet(facet.clone) }
              end
              node.each_agent do |agent| 
                to_move = @society.agents[agent.name]
                if to_move
                  to_move.move_to(node.name)
                  # add layout society's agent facets to the agent
                  agent.each_facet {|facet| to_move.add_facet(facet.clone)}
                else
                  puts "Layout specifies agent '#{agent.name}' that is not defined in the society"
                  Cougaar.logger.info "[#{Time.now}]  Layout specifies agent '#{agent.name}' that is not defined in the society"
                end
              end
            end
          end
        end
        
        if unused_hostlist
          unused_hostlist.each do |host|
            @society.add_host(host.name) do |newhost|
              host.each_facet { |facet| newhost.add_facet(facet.clone) }
            end
          end
        end
        
        # check to make sure we laid out all the agents
        agentlist = []
        @society.nodes["node-#{guid}"].each_agent { |agent| agentlist << agent }
        if agentlist.size>0
          names = agentlist.collect { |agent| agent.name }
          raise "Did not layout the agents: #{ names.join(', ') }"
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
