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


require 'rexml/document'

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

require 'rexml/document'

module Cougaar
  module Actions
    class DeployCommunitiesFile < Cougaar::Action
      PRIOR_STATES = ["CommunicationsRunning"]
      DOCUMENTATION = Cougaar.document {
        @description = "Write the society's communities.xml file."
        @parameters = [
          {:nodeFile => "default=false, Write community files based on nodes. If false, write all communities into one file."},
          {:destination => "[default='operator', 'operator'|'all'], Host to write communities.xml file to.  If this is not specified its writes to all."},
          {:debug => "default=false, If true, outputs messages sent to deploy communities.xml file."}
        ]
        @example = "do_action 'DeployCommunitiesFile'"
      }

      def initialize(run, nodeFile=false, destination='operator', debug=false)
        super(run)
        @nodeFile = nodeFile
        @destination = destination
        @debug = debug
      end

      def perform
        unless @nodeFile
          communities_xml = @run.society.communities.to_xml
          if @destination == 'operator'
            @run.society.each_service_host("operator") do |host|
              result = Cougaar::Communications::HTTP.post("http://#{host.uri_name}:9444/communities", communities_xml, "text/xml")
              @run.info_message result if @debug
            end
          else
            @run.society.each_service_host("acme") do |host|
              result = Cougaar::Communications::HTTP.post("http://#{host.uri_name}:9444/communities", communities_xml, "text/xml")
              @run.info_message result if @debug
            end
          end # @destination == 'operator'
        else
          #@dir = "#{CIP}/configs/communities"
          #if !File.exists?(@dir)
          #  Dir.mkdir(@dir)
          #end
          @run.society.each_node do |node|
            node.append_value_on_parameter("-Dorg.cougaar.community.configfile", "#{node.name}_communities.xml")
            node.append_value_on_parameter("-Dorg.cougaar.config.path", "$COUGAAR_INSTALL_PATH/configs/communities")
            node_xml = node.to_community_xml
            result = Cougaar::Communications::HTTP.post("http://#{node.host.uri_name}:9444/communities/#{node.name}", node_xml, "text/xml")
            @run.info_message result if @debug            
            #file = File.join(@dir, "#{node.name}_communities.xml")
            #begin
            #  File.open(file, "w") { |myfile| myfile.puts node_xml }
            #rescue
            #  @run.error_message "Could not write communities to #{file}"
            #end
          end
        end # if !@nodeFile
      end

    end

    class SaveCurrentCommunities < Cougaar::Action
      PRIOR_STATES = ["SocietyLoaded"]
      DOCUMENTATION = Cougaar.document {
        @description = "Write the society's communities definition to a local file."
        @parameters = [
          {:file => "[default='communities.xml', File to write communities file to (in xml format)."}
        ]
        @example = "do_action 'SaveCurrentCommunities', 'myCommunities.xml'"
      }

      def initialize(run, file='communities.xml')
        super(run)
        @file = file
      end

      def to_s
        return super.to_s+"('#{@file}')"
      end

      def perform
        communities_xml = @run.society.communities.to_xml
        begin
          File.open(@file, "w") { |file| file.puts communities_xml }
          @run.archive_and_remove_file(@file, "Saved instance of the society communities in memory")
        rescue
          @run.error_message "Could not write communities to #{@file}"
        end
      end
    end

    class LoadCommunitiesFromXML < Cougaar::Action
      PRIOR_STATES = ["SocietyLoaded"]
      DOCUMENTATION = Cougaar.document {
        @description = "Load a communities file from XML into the current society."
        @parameters = [
          {:file => "filename, File to read communities from (in xml format)."}
        ]
        @example = "do_action 'LoadCommunitiesFromXML', 'myCommunities.xml'"
      }

      def initialize(run, filename)
        super(run)
        @filename = filename
      end

      def to_s
        return super.to_s+"('#{@filename}')"
      end

      def perform
        Cougaar::Model::Communities.from_xml(@run.society, @filename)
      end
    end
  end

  module Model

    class Society
      def communities
        @communities ||= Communities.new(self)
      end

      def communities=(communities)
        @communities = communities
        @communities.society = self
      end
    end

    class Communities
      include Enumerable

      attr_accessor :society

      def Communities.from_xml_file(society, filename)
        communities = Communities.new(society)
        doc = REXML::Document.new(File.new(filename))
        doc.root.elements.each("Community") do |community_element|
          communities.add(community_element.attributes['Name']) do |community|
            community.initialize_from_rexml_element(community_element)
          end
        end
        communities
      end

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
        xml = ['<?xml version="1.0" encoding="UTF-8"?>',
          '<!DOCTYPE Communities [',
          '<!ELEMENT Communities (Community+)>',
          '<!ELEMENT Community (Attribute+, Entity*)>',
          '<!ATTLIST Community Name CDATA #REQUIRED>',
          '<!ELEMENT AttributeID EMPTY>',
          '<!ATTLIST AttributeID ID CDATA #REQUIRED>',
          '<!ELEMENT Entity (Attribute*)>',
          '<!ATTLIST Entity Name CDATA #REQUIRED>',
          '<!ELEMENT Attribute EMPTY>',
          '<!ATTLIST Attribute ID CDATA #REQUIRED>',
          '<!ATTLIST Attribute Value CDATA #REQUIRED>',
          ']>']
        xml << "<Communities>"
        each do |community|
          community.to_xml(xml)
        end
        xml << "</Communities>"
        xml.join("\n")
      end

      class Community

        include Enumerable
        attr_accessor :name, :validate

        def initialize(name, society)
          @name = name
          @society = society
          @entities = []
          @attributes = []
          @subcommunities = []
        end

        def initialize_from_rexml_element(community_element)
          community_element.elements.each("Attribute") do |attribute_element|
            add_attribute(attribute_element.attributes['ID'], attribute_element.attributes['Value'])
          end
          community_element.elements.each("Entity") do |entity_element|
            entity_name = entity_element.attributes['Name']
            et_element = entity_element.elements['Attribute[@ID="EntityType"]']
            entity_type = et_element ?  et_element.attributes['Value'] : nil

            add_entity(entity_name, entity_type) do |entity|
              entity_element.elements.each("Attribute") do |attribute_element|
                id = attribute_element.attributes['ID']
                value = attribute_element.attributes['Value']
                if id=='Role'
                  entity.add_role(value)
                elsif id!='EntityType'
                  entity.add_attribute(id, value)
                end
              end
            end
          end
          community_element.elements.each("Community") do |subcommunity_element|
            ExperimentMonitor.notify(ExperimentMonitor::InfoNotification.new("#{community_element.attributes['Name']}"))
            add_subcommunity(community_element.attributes['Name']) do |subcommunity|
              subcommunity.initialize_from_rexml_element(subcommunity_element)
            end
          end
        end

        def add_subcommunity(name)
          @subcommunities.each {|community| return if community.name==name}
          community = Community.new(name, @society)
          yield community
          @subcommunities << community
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

        def each_subcommunity
          @subcommunities.each { |comm| yield comm }
        end

        def to_xml(xml = nil, indent = 2)
          xml ||= []
          xml << " "*indent+"<Community Name='#{@name}' >"
          each_attribute do |id, value|
            xml << " "*indent+"  <Attribute ID='#{id}' Value='#{value}' />"
          end
          each do |entity|
            entity.to_xml(xml, indent+2)
          end
          each_subcommunity do |community|
            community.to_xml(xml, indent+2)
          end
          xml << " "*indent+"</Community>"
          xml.to_s
        end

        def each(&block)
          @entities.each { |entity| yield entity }
        end

        def add_agent(agent, &block)
          raise "Unknown agent: #{agent}" if @validate && !@society.agents[agent]
          add_entity(agent, "Agent", &block)
        end

        def add_node(node, &block)
          raise "Unknown node: #{node}" if @validate && !@society.nodes[node]
          add_entity(node, "Node", &block)
        end

        def add_nodes(*nodes, &block)
          nodes.each do |node|
            raise "Unknown node: #{node}" if @validate && !@society.nodes[node]
            add_entity(node, 'Node', &block)
          end
        end

        def add_agents_on_nodes(node_agents, *nodes, &block)
          nodes.each do |node|
            add_entity(node, 'Agent', &block) if node_agents
            raise "Unknown node: #{node}" unless @society.nodes[node]
            @society.nodes[node].each_agent do |agent|
              add_entity(agent.name, 'Agent', &block)
            end
          end
        end

        def add_all_agents(&block)
          @society.each_agent(true) do |agent|
            add_entity(agent.name, 'Agent', &block)
          end
        end

        def add_entity(name, entity_type=nil, &block)
          entity = Entity.new(name, entity_type)
          @entities << entity
          yield entity if block_given?
          entity
        end

        def [](member_id)
          @members.each do |member|
            return member if member.name==member_id
          end
        end

        def hasEntity?(entityName)
          @entities.each {|entity| return true if entityName == entity.name}
          return false
        end

        def getParentCommunities(subcommunity, list)
          @society.communities.each do |community|
            if community.hasEntity?(subcommunity.name)
              list << community if !list.include?(community)
              getParentCommunities(community, list)
            end
          end
          return list
        end

        def property_to_xml(xml=nil, indent = 0)
          xml ||= []
          xml << " "*indent+"<Community Name='#{name}'>"
          each_attribute do |id, value|
             xml << " "*indent+"  <Attribute ID='#{id}' Value='#{value}' />"
          end
        end

        class Entity
          attr_accessor :name, :entity_type

          def initialize(name, entity_type=nil)
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

          def each_role
            @roles.each { |role| yield role }
          end

          def to_xml(xml=nil, indent = 0)
            xml ||= []
            if @entity_type && @entity_type == "Agent" && @roles.length == 1 && @roles[0] == "Member" && @attributes.length == 0
               xml << " "*indent + "<Entity Name='#{@name}' />"
            else
              xml << " "*indent+"<Entity Name='#{@name}' >"
              xml << " "*indent+"  <Attribute ID='EntityType' Value='#{@entity_type}' />" if @entity_type && @entity_type != "Agent"
              @roles.each do |role|
                xml << " "*indent+"  <Attribute ID='Role' Value='#{role}' />" if role != "Member"
              end
              each_attribute do |id, value|
                xml << " "*indent+"  <Attribute ID='#{id}' Value='#{value}' />"
              end
              xml << " "*indent+"</Entity>"
            end
            xml.to_s
          end

          def add_role(role)
            @roles << role
          end
        end # Entity
      end # Community
    end # Communities

    class Node
      def to_community_xml
          @myCommunities = []
          @parentCommunities = []
          xml = ['<?xml version="1.0" encoding="UTF-8"?>',
          '<!DOCTYPE Communities [',
          '<!ELEMENT Communities (Community+)>',
          '<!ELEMENT Community (Attribute+, Entity*)>',
          '<!ATTLIST Community Name CDATA #REQUIRED>',
          '<!ELEMENT AttributeID EMPTY>',
          '<!ATTLIST AttributeID ID CDATA #REQUIRED>',
          '<!ELEMENT Entity (Attribute*)>',
          '<!ATTLIST Entity Name CDATA #REQUIRED>',
          '<!ELEMENT Attribute EMPTY>',
          '<!ATTLIST Attribute ID CDATA #REQUIRED>',
          '<!ATTLIST Attribute Value CDATA #REQUIRED>',
          ']>']
          xml << "<Communities>"
          # fast check which community should be included in the file
          @host.society.communities.each do |community|
            if community.hasEntity?(name)
              @myCommunities << community
              @parentCommunities = community.getParentCommunities(community,
@parentCommunities)
            else
              each_agent do |agent|
                if community.hasEntity?(agent.name)
                  @myCommunities << community
                  @parentCommunities = community.getParentCommunities(community,
@parentCommunities)
                  break
                end
              end
            end
          end # @host.society.communities.each

          # Get all communities who do not contain any agent of this node, but contain subcommunities who do contain.
          parentList = @parentCommunities - @myCommunities
          totalList = @myCommunities + parentList
          #@myCommunities.concat(parentList)

          parentList.each do |community|
            community.property_to_xml(xml, 2)
            community.each do |entity|
                if entity.entity_type == "Community"
                  totalList.each do |subcomm|
                    if entity.name == subcomm.name
                      entity.to_xml(xml, 4)
                    end
                  end
                end
            end
            xml << "  </Community>"
          end # parentList.each

          @myCommunities.each do |community|
            community.property_to_xml(xml, 2)
            community.each do |entity|
              if entity.entity_type.nil? or entity.entity_type == "Agent"
                if entity.name == @name
                  entity.to_xml(xml, 4)
                else
                  each_agent do |agent|
                    if entity.name == agent.name
                      entity.to_xml(xml, 4)
                    end # entity.name == agent.name
                  end
                end
              end # entity.entity_type == "Agent"

              if entity.entity_type == "Node"
                if entity.name == @name
                  entity.to_xml(xml, 4)
                end
              end # entity.entity_type == "Node"

              if entity.entity_type == "Community"
                totalList.each do |subcomm|
                  if subcomm.name == entity.name
                    entity.to_xml(xml, 4)
                  end
                end
              end
            end # community.each

            xml << "  </Community>"
          end # @myCommunities.each

          xml << "</Communities>"
          xml.join("\n")
      end # to_community_xml
    end # Node

  end # Model
end # Cougaar
