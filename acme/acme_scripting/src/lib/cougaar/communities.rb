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

  module Actions
    class DeployCommunitiesFile < Cougaar::Action
      PRIOR_STATES = ["CommunicationsRunning"]
      RESULTANT_STATE = "SocietyRunning"
      DOCUMENTATION = Cougaar.document {
        @description = "Write the society's communities.xml file."
        @parameters = [
          {:destination => "[default='operator', 'operator'|'all'], Host to write communities.xml file to.  If this is not specified its writes to all."},
          {:debug => "default=false, If true, outputs messages sent to deploy communities.xml file."}
        ]
        @example = "do_action 'DeployCommunitiesFile'"
      }
      
      def initialize(run, destination='operator', debug=false)
        super(run)
        @destination = destination
        @debug = debug
      end
      
      def perform
        communities_xml = @society.communities.to_xml
        if @destination == 'operator'
          @society.each_service_host("operator") do |host|
            result = Cougaar::Communications::HTTP.post("http://#{node.host.host_name}:9444/communities", communities_xml, "text/xml")
            puts result if @debug
          end
        else
          @society.each_service_host("acme") do |host|
            result = Cougaar::Communications::HTTP.post("http://#{node.host.host_name}:9444/communities", communities_xml, "text/xml")
            puts result if @debug
          end
        end
      end

    end
  end

  module Model
  
    class Society
      def communities
        @communities ||= Communities.new(self)
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
        xml = Community::PREAMBLE.clone
        xml << "<Communities>"
        each do |community|
          community.to_xml(xml)
        end
        xml << "</Communities>"
        xml.join("\n")
      end
      
      class Community
        PREAMBLE = ['<?xml version="1.0" encoding="UTF-8"?>',
          '<!DOCTYPE Communities [',
          '<!ELEMENT Communities (Community+)>',
          '<!ELEMENT Community (Attribute+, Entity*)>',
          '<!ATTLIST Community Name CDATA #REQUIRED>',
          '<!ELEMENT AttributeID EMPTY>',
          '<!ATTLIST AttributeID ID CDATA #REQUIRED>',
          '<!ATTLIST AttributeID Access (manager|member|associate|world) #IMPLIED>',
          '<!ELEMENT Entity (Attribute*)>',
          '<!ATTLIST Entity Name CDATA #REQUIRED>',
          '<!ELEMENT Attribute EMPTY>',
          '<!ATTLIST Attribute ID CDATA #REQUIRED>',
          '<!ATTLIST Attribute Value CDATA #REQUIRED>',
          ']>']
        include Enumerable
        attr_accessor :name, :validate
        
        def initialize(name, society)
          @name = name
          @society = society
          @entities = []
          @attributes = []
        end
        
        def add_attribute(id, value)
          @attributes << [id, value]
        end
        
        def validate?
          return @validate
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
          raise "Unknown agent: #{agent}" if @validate && !@society.agents[agent]
          @entities << add_entity(agent, "Agent", &block)
        end
        
        def add_node(node, &block)
          raise "Unknown node: #{node}" if @validate && !@society.nodes[node]
          @entities << add_entity(node, "Node", &block)
        end
        
        def add_nodes(*nodes, &block)
          nodes.each do |node|
            raise "Unknown node: #{node}" if @validate && !@society.nodes[node]
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
  end
end