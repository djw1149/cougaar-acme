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

require 'cougaar/scripting'
require 'rexml/document'

module Cougaar
  module Actions
    class GetAgentShortfall < Cougaar::Action
      PRIOR_STATES = ["SocietyRunning"]
      DOCUMENTATION = Cougaar.document {
        @description = "Gets an individual agent's shortfall statistics."
        @parameters = [
                       {:agent => "required, The name of the agent."}
                     ]
        @block_yields = [
                         {:agentInvs => "The shortfall AgentInventories object (UltraLog::Shortfall)."}
                       ]
        @example = "
          do_action 'GetAgentShortfall', 'NCA' do |agentInvs|
            puts agentInvs
          end
        "
      }
      def initialize(run, agent_name, &block)
        super(run)
        @agent_name = agent_name
        @action = block
      end
      def perform
        @action.call(::UltraLog::Shortfall.status(@run.society.agents[@agent_name]))
      end
    end
    
    class SaveSocietyShortfall < Cougaar::Action
      PRIOR_STATES = ["SocietyRunning"]
      DOCUMENTATION = Cougaar.document {
        @description = "Gets all agent's shortfall statistics and writes them to a file."
        @parameters = [
                       {:file => "required, The file name to write to."}
                     ]
        @example = "do_action 'SaveSocietyShortfall', 'shortfall.xml'"
      }
      def initialize(run, file)
        super(run)
        @file = file
      end
      def perform
        agent_list = []
        total_agents = 0
        total_shortfall = 0 
        total_temp =0
        total_agents_unexpected = 0
        total_agents_all_temp = 0
        total_unexpected = 0
        all_effected = []
        any_in_user_mode = false
        @run.society.each_agent {|agent| agent_list << agent.name}
        agent_list.sort!
        xml = "<ShortfallSnapshot>\n"
        agent_list.each do |agent|
          begin
            agentInvs = ::UltraLog::Shortfall.status(@run.society.agents[agent])
            if agentInvs
              any_in_user_mode = any_in_user_mode || agentInvs.inUserMode?
              if(agentInvs.shortfall?)
                xml += agentInvs.to_s
                total_agents +=1
                total_shortfall = total_shortfall + agentInvs.numShortfall.to_i
                if(!any_in_user_mode)
                    total_temp = total_temp + agentInvs.numTemp.to_i
                    total_unexpected = total_unexpected + agentInvs.numUnexpected.to_i
                end
                all_effected = all_effected | agentInvs.supplyTypes
                if(!any_in_user_mode)
                  if(agentInvs.unexpectedShortfall?)
                    total_agents_unexpected+=1
                  end
                  if(agentInvs.allTempShortfall?)
                    total_agents_all_temp+=1
                  end
                end
                #Dir.mkdir("SHORTFALL") unless File.exist?("SHORTFALL")
                #modifier = @file.chop.chop.chop.chop
                #invDir = "SHORTFALL/" + modifier.upcase + "_INV"
                #Dir.mkdir(invDir) unless File.exist?(invDir)
                #agentInvs.getShortfallInventories.each { | inventoryItem |
                #  sampleInv = SampleInventory.new(@run,agent,inventoryItem,
                #                                  "#{invDir}/#{agent}-#{invenotryItem}.xml")
                #  sampleInv.perform
                #}                  
              end               
            else
              xml += "<SimpleShortfall agent='#{agent}' status='Error: Could not access agent.'\>\n"
              @run.error_message "Error accessing Shortfall data for Agent #{agent}."
            end
          rescue Exception => failure
            xml += "<SimpleShortfall agent='#{agent}' status='Error: Parse exception.'\>\n"
            @run.error_message "Error parsing shortfall data for Agent #{agent}: #{failure}."
          end
        end
        xml += "<TotalAgentsWShortfall>" + total_agents.to_s + "</TotalAgentsWShortfall>\n"
        xml += "<TotalInventoryShortfall>" + total_shortfall.to_s + "</TotalInventoryShortfall>\n"
        if(!any_in_user_mode) 
          xml += "<TotalAgentsWUnexpected>" + total_agents_unexpected.to_s + "</TotalAgentsWUnexpected>\n"
          xml += "<TotalTempShortfall>" + total_temp.to_s + "</TotalTempShortfall>\n"
          xml += "<TotalAgentsWAllTemp>" + total_agents_all_temp.to_s + "</TotalAgentsWAllTemp>\n"
          xml += "<TotalUnexpectedShortfall>" + total_unexpected.to_s + "</TotalUnexpectedShortfall>\n"
        end
        xml += "<AllEffectedSupplyTypes>\n"
        all_effected.each { |supplyType| xml += "<SupplyType>#{supplyType}</SupplyType>\n" }
        xml += "</AllEffectedSupplyTypes>\n"
        xml += "</ShortfallSnapshot>"
        save(xml)
      end
      def save(result)
        Dir.mkdir("SHORTFALL") unless File.exist?("SHORTFALL")
        File.open(File.join("SHORTFALL", @file), "wb") do |file|
          file.puts result
        end
        @run.archive_and_remove_file(File.join("SHORTFALL", @file), "Society shortfall data.")
      end
    end #Save society Actions
  end  # Module Actions
end # Module Cougaar

module UltraLog
  ##
  # The Shortfall class wraps access the data generated by the shortfall servlet
  #
  class Shortfall
    
    def perform()
      self.query("localhost","1-35-ARBN.2-BDE.1-AD.ARMY.MIL",8800)
    end
    
    ##
    # Helper method that extracts the host and agent name to get shortfall for
    #
    # agent:: [Cougaar::Agent] The agent to get shortfall for
    # return:: [UltraLog::Shortfall::AgentInventories] The results of the query
    #
    def self.status(agent)
      data = Cougaar::Communications::HTTP.get("#{agent.uri}/shortfall?showTables=true&viewType=viewAgentBig&format=xml", 60)
      if data
        return AgentInventories.new(agent.name, data[0])
      else
        return nil
      end
    end
    
    ##
    # Gets shortfall AgentInventories for a host/agent
    #
    # host:: [String] Host name
    # agent:: [String] Agent name
    # return:: [UltraLog::Shortfall::AgentInventories] The results of the query
    #
    def self.query(host, agent, port)
      data = Cougaar::Communications::HTTP.get("http://#{host}:#{port}/$#{agent}/shortfall?showTables=true&viewType=viewAgentBig&format=xml", 60)
      if data
        return AgentInventories.new(agent, data[0])
      else
        return nil
      end
    end
    
    ##
    # The AgentInventories class holds the results of a shortfall query
    #
    class AgentInventories
      attr_reader :agent, :time, :geoLoc, :userMode, :numShortfall, :numTemp, :numUnexpected, :supplyTypes, :inventoriesByType
      
      ##
      # Parses the supplied XML data into the AgentInventories attributed
      #
      # data:: [String] A shortfall XML query
      #
      def initialize(agent, data)
        begin
          xml = REXML::Document.new(data)
        rescue REXML::ParseException
          raise "Could not construct AgentInventories object from supplied data."
        end
        root = xml.root
        @agent = agent
        @numShortfall = root.elements["NUM_SHORTFALL_INVENTORIES"].text.to_i
        @geoLoc = root.elements["GEO_LOC"].text
        @userMode = (root.elements["USER_MODE"].text == "true")
        @time = root.elements["TIME_MILLIS"].text.to_i
        @numTemp=nil
        @numUnexpected=nil
        if(!inUserMode?)         
          @numTemp = root.elements["NUM_TEMP_SHORTFALL_INVENTORIES"].text.to_i
          @numUnexpected = root.elements["NUM_UNEXPECTED_SHORTFALL_INVENTORIES"].text.to_i
        end
        if(@numShortfall > 0) 
          effectedSupplyTypes = root.elements["EFFECTED_SUPPLY_TYPES"]
          @supplyTypes = []
          effectedSupplyTypes.elements.each {|supplyTypeXML| supplyTypes << (supplyTypeXML.text.to_s)}

          @inventoriesByType = Hash.new
          xml.elements.each("Shortfall/INVENTORIES/INVENTORIES_TYPE") { |invType|
            classOfSupply = invType.attributes["ClassOfSupply"].to_s
            #puts invType.to_s
            theInventories = []
            invType.elements.each('INVENTORY') { |invElement| 
              id = invElement.attributes["ID"].to_s
              shortfallPeriods = []
              invElement.elements.each('SHORTFALL_PERIOD') { | period | shortfallPeriods << period }
              theInventories << Inventory.new(id,shortfallPeriods)
            }
            @inventoriesByType[classOfSupply] = theInventories
          }
        end
      end
      
      ##
      # Checks if agent has unexpected shortfall
      #
      # return:: [Boolean] true if unplanned and unestimated are zero, false otherwise
      #
      def unexpectedShortfall?
        return (@numUnexpected > 0)
      end


      ##
      # Checks if agent was produced by servlet in user mode
      #
      # return:: [Boolean] true if in userMode so no unexpected, etc
      #
      def inUserMode?
        return @userMode
      end
      
      ##
      # Return the shortfallInventories for this agent
      #
      # return:: [Array] of Inventory objects that qualify
      #
      def getShortfallInventories
        @inventoriesByType.values.flatten
      end



      ##
      # Checks if agent has unexpected shortfall
      #
      # return:: [Boolean] true if unplanned and unestimated are zero, false otherwise
      #
      def allTempShortfall?
        return (@numShortfall <= @numTemp)
      end
      
      ##
      # Checks if agent has failed tasks
      #
      # return:: [Boolean] true if failed > 0, false otherwise
      #
      def shortfall?
        return (@numShortfall > 0)
      end
      
      def to_s
        s =  "<SimpleShortfall agent='#{@agent}'>\n"
        s << "  <GeoLoc>#{@geoLoc}</GeoLoc>\n"
        s << "  <TimeMillis>#{@time}</TimeMillis>\n"
        s << "  <NumShortfall>#{@numShortfall}</NumShortfall>\n"
        if(!inUserMode?) 
          s << "  <NumTemp>#{@numTemp}</NumTemp>\n"
          s << "  <NumUnexpected>#{@numUnexpected}</NumUnexpected>\n"
        end
        s << "  <EffectedSupplyTypes>\n"
        @supplyTypes.each { |supplyType| s << "      <SupplyType>#{supplyType}</SupplyType>\n" }
        s << "  </EffectedSupplyTypes>\n"
        s << "  <Inventories>\n"
        @inventoriesByType.each {|classOfSupply, inventories| 
          s << "   <InventoriesByClass classOfSupply=\'" + classOfSupply + "\'>\n"
          inventories.each { |inventory| s << inventory.to_s }
          s << "   </InventoriesByClass>\n"
        }
        s << "  </Inventories>\n"
        s << "</SimpleShortfall>\n"
      end
    end #AgentInventories
    
    class Inventory
      attr_reader :id, :shortfallPeriods
      
      ##
      # Creates an inventory object from inventory id string and array of 
      # shortfall period strings 
      #
      # shortfall_periods:: [Array] shortfall period xml strings
      #
      def initialize(inv_id, shortfall_periods)
        @id = inv_id
        @shortfallPeriods = shortfall_periods
      end

      def to_s 
        s = "    <Inventory id=\'" + @id + "\'>\n"
        @shortfallPeriods.each{ | period | s << "      " + (period.to_s + "\n") }
        s << "    </Inventory>\n"
      end
      
    end #Inventory       
  end #Shortfall
end #Ultralog





