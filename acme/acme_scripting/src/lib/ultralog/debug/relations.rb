##
#  <copyright>
#  Copyright 2003 BBN Technologies
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

$:.unshift "../.." if $0 == __FILE__

require 'cougaar/scripting'
require 'rexml/document'


module Cougaar
  module Actions

    ##
    # This action checks to make sure that all relationships are 
    # symmetric.  Basically
    # For each agent
    #   For each relationship
    #     make sure the other agent has the reciprocal relationship
    #
    class CheckRelations < Cougaar::Action
		  @debug = true
      def initialize(run, show_missing_agents=false)
        super(run)
        @show_missing_agents = show_missing_agents
      end
      
      def perform
        rc = UltraLog::Debug::RelationCheck.new(@run.society, @show_missing_agents)
        print "Checking relationships..."
        d = rc.check()
        puts "DONE"
      end
    end # class

  end # module Actions
end # module Cougaar

module UltraLog
module Debug

  class Relation
    attr_accessor :org, :rel
    def initialize(org, rel)
      @org = org
      @rel = rel
    end
    def to_s()
      return "#{@org}:#{rel}"
    end
  end

  class RelationCheck
    
    def init_converse(r1, r2)
      @converse[r1] = r2
      @converse[r2] = r1
    end

    def initialize(society, show_missing=true)
      @converse = {}
      init_converse("Superior", "Subordinate")
      init_converse("ConstructionProvider", "ConverseOfConstructionProvider")
      init_converse("ConstructionSupplyProvider", "ConverseOfConstructionSupplyProvider")
      init_converse("ShipPackingTransportationProvider", "ConverseOfShipPackingTransportationProvider")
      init_converse("OrganicAirTransportationProvider", "ConverseOfOrganicAirTransportationProvider")
      init_converse("TheaterStrategicTransportationProvider", "ConverseOfTheaterStrategicTransportationProvider")
      init_converse("SeaTransportationProvider", "ConverseOfSeaTransportationProvider")
      init_converse("AirTransportationProvider", "ConverseOfAirTransportationProvider")
      init_converse("CONUSGroundTransportationProvider", "ConverseOfCONUSGroundTransportationProvider")
      
      @show_missing = show_missing
      @society = society
      @agents = {}
    end

    def check()
      build()
      verify()
    end


    def check_converse(agent, relation)
      conv = @converse[relation.rel]
      if (conv)
        list = @agents[relation.org]
        found = false
        if list
          list.each do |rel|
            found = true if rel.org == agent && rel.rel == conv
          end
        else
          puts "#{agent} has relation #{relation.rel} with #{relation.org} but #{relation.org} does not exist" if @show_missing
          found = true
        end
        puts "#{relation.org} is #{relation.rel} for #{agent} but #{agent} is not #{conv} for #{relation.org}" unless found
        #puts "#{relation.org} is #{relation.rel} for #{agent} and #{agent} is #{conv} for #{relation.org}" 
      end
    end

    def verify()
      @agents.each do |agent_name, agent_list|
        #puts "REL: #{agent_name} --- #{agent_list}"

        agent_list.each do |relation|
          check_converse(agent_name, relation)
        end
      end
    end

    def add_converse(rel)
      base = /(.*)Customer/.match(rel)
      base = /(.*)Provider/.match(rel) unless base
      if base
        @converse["#{base[1]}Provider"] = "#{base[1]}Customer"
        @converse["#{base[1]}Customer"] = "#{base[1]}Provider"
      end
    end

    def build
      @society.each_node do |node| 
        node.each_agent do |agent|
          begin
            this_agent = []
            @agents[agent.name] = this_agent
            myuri = "http://#{node.host.name}:8800/$#{agent.name}/hierarchy?recurse=false&allRelationships=true&format=xml&Display=Submit+Query"
            data, uri = Cougaar::Communications::HTTP.get(myuri)
            doc = REXML::Document.new(data)
            doc.elements.each("Hierarchy/Org/Rel") do |element|
              org = element.attributes["OrgID"]
              rel = element.attributes["Rel"]
            
              this_agent << Relation.new(org, rel)
              add_converse(rel) unless @converse[rel]
            end
          rescue Exception
            puts "Exception checking agent #{agent.name}: #{$!}"
          end
        end
      end
    end
  end

end # module Debug
end # module Ultralog

if $0==__FILE__

  file = ARGV[0]
  show_missing = ARGV.length == 1
  if (File.basename(file)!=File.basename(file, ".xml"))
    builder = Cougaar::SocietyBuilder.from_xml_file(file)
  else
    builder = Cougaar::SocietyBuilder.from_ruby_file(file)
  end

  soc = builder.society

  rc = UltraLog::Debug::RelationCheck.new(soc, show_missing)
  d = rc.check()

end
