##
#  <copyright>
#  Copyright 2003 BBN Technologies, LLC
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

module Cougaar
  module Actions
  
    class FullInventory < Cougaar::Action
      PRIOR_STATES = ["SocietyRunning"]

      # Take the asset to get the inventory for at this agent
      def initialize(run, modifier)
        super(run)
        @modifier = modifier
      end
      
      def to_s
        return super.to_s+"(#{@modifier})"
      end
      
      def perform
	#Check to see if @modifier is a subdirectory of INV
	#if it is not create it
	Dir.mkdir("INV/#{@modifier}") if Dir["INV/#{@modifier}"].empty?


        # Get some inventory charts
        get_inventory  "1-35-ARBN", "120MM APFSDS-T M829A1:DODIC/C380", "INV/#{@modifier}/INV#{@modifier}-1-35-ARBN-DODIC-C380.xml"
        get_inventory  "1-35-ARBN", "120MM HEAT-MP-T M830:DODIC/C787", "INV/#{@modifier}/INV#{@modifier}-1-35-ARBN-DODIC-C787.xml"
        get_inventory  "1-35-ARBN", "MEAL READY-TO-EAT  :NSN/8970001491094", "INV/#{@modifier}/INV#{@modifier}-1-35-ARBN-MRE.xml"
        get_inventory  "1-35-ARBN", "FRESH FRUITS  :NSN/891501F768439", "INV/#{@modifier}/INV#{@modifier}-1-35-ARBN-FRUIT.xml"
      #  get_inventory  "1-35-ARBN", "UNITIZED GROUP RATION - HEAT AND SERVE BREAKFAST :NSN/897UGRHSBRKXX", "INV/#{@modifier}/INV#{@modifier}-1-35-ARBN-BREAKFAST.xml"

        # 1-36-INFBN inventories
      #  get_inventory  "1-36-INFBN", "120MM APFSDS-T M829A1:DODIC/C380", "INV/#{@modifier}/INV#{@modifier}-1-36-INFBN-DODIC-C380.xml"
      #  get_inventory  "1-36-INFBN", "120MM HEAT-MP-T M830:DODIC/C787", "INV/#{@modifier}/INV#{@modifier}-1-36-INFBN-DODIC-C787.xml"
        get_inventory  "1-36-INFBN", "MEAL READY-TO-EAT  :NSN/8970001491094", "INV/#{@modifier}/INV#{@modifier}-1-36-INFBN-MRE.xml"
        get_inventory  "1-36-INFBN", "FRESH FRUITS  :NSN/891501F768439", "INV/#{@modifier}/INV#{@modifier}-1-36-INFBN-FRUIT.xml"
      #  get_inventory  "1-36-INFBN", "UNITIZED GROUP RATION - HEAT AND SERVE BREAKFAST :NSN/897UGRHSBRKXX", "INV/#{@modifier}/INV#{@modifier}-1-36-INFBN-BREAKFAST.xml"
      
        # 47-FSB inventories
        get_inventory  "47-FSB", "120MM APFSDS-T M829A1:DODIC/C380", "INV/#{@modifier}/INV#{@modifier}-47-FSB-DODIC-C380.xml" 
        get_inventory  "47-FSB", "120MM HEAT-MP-T M830:DODIC/C787", "INV/#{@modifier}/INV#{@modifier}-47-FSB-DODIC-C787.xml"
      
        get_inventory  "47-FSB", "MEAL READY-TO-EAT  :NSN/8970001491094", "INV/#{@modifier}/INV#{@modifier}-47-FSB-MRE.xml"
        get_inventory  "47-FSB", "FRESH FRUITS  :NSN/891501F768439", "INV/#{@modifier}/INV#{@modifier}-47-FSB-FRUIT.xml"
      #  get_inventory  "47-FSB", "UNITIZED GROUP RATION - HEAT AND SERVE BREAKFAST :NSN/897UGRHSBRKXX", "INV/#{@modifier}/INV#{@modifier}-47-FSB-BREAKFAST.xml"
        get_inventory  "47-FSB", "DF2:NSN/9140002865294", "INV/#{@modifier}/INV#{@modifier}-47-FSB-DF2.xml"
        get_inventory  "47-FSB", "JP8:NSN/9130010315816", "INV/#{@modifier}/INV#{@modifier}-47-FSB-JP8.xml"
        get_inventory  "47-FSB", "GREASE,GENERAL PURP:NSN/9150001806383", "INV/#{@modifier}/INV#{@modifier}-47-FSB-GREASE.xml"
        get_inventory  "47-FSB", "PETROLATUM,TECHNICA:NSN/9150002500926", "INV/#{@modifier}/INV#{@modifier}-47-FSB-PETROLATUM.xml"
        get_inventory  "47-FSB", "GLOW PLUG:NSN/2920011883863", "INV/#{@modifier}/INV#{@modifier}-47-FSB-GLOWPLUG.xml"
        get_inventory  "47-FSB", "BELT,VEHICULAR SAFE:NSN/2540013529175", "INV/#{@modifier}/INV#{@modifier}-47-FSB-BELT.xml"
        get_inventory  "47-FSB", "BRAKE SHOE:NSN/2530013549427", "INV/#{@modifier}/INV#{@modifier}-47-FSB-BRAKESHOE.xml"
        get_inventory  "47-FSB", "Level2BulkPOL:BulkPOL", "INV/#{@modifier}/INV#{@modifier}-47-FSB-Level2BulkPOL.xml"
        get_inventory  "47-FSB", "Level2Ammunition:Ammunition", "INV/#{@modifier}/INV#{@modifier}-47-FSB-Level2Ammunition.xml"
      
        # 125-FSB inventories
        get_inventory  "125-FSB", "120MM APFSDS-T M829A1:DODIC/C380", "INV/#{@modifier}/INV#{@modifier}-125-FSB-DODIC-C380.xml"
        get_inventory  "125-FSB", "120MM HEAT-MP-T M830:DODIC/C787", "INV/#{@modifier}/INV#{@modifier}-125-FSB-DODIC-C787.xml"
      
        get_inventory  "125-FSB", "MEAL READY-TO-EAT  :NSN/8970001491094", "INV/#{@modifier}/INV#{@modifier}-125-FSB-MRE.xml"
        get_inventory  "125-FSB", "FRESH FRUITS  :NSN/891501F768439", "INV/#{@modifier}/INV#{@modifier}-125-FSB-FRUIT.xml"
      #  get_inventory  "125-FSB", "UNITIZED GROUP RATION - HEAT AND SERVE BREAKFAST :NSN/897UGRHSBRKXX", "INV/#{@modifier}/INV#{@modifier}-125-FSB-BREAKFAST.xml"
        get_inventory  "125-FSB", "DF2:NSN/9140002865294", "INV/#{@modifier}/INV#{@modifier}-125-FSB-DF2.xml"
        get_inventory  "125-FSB", "JP8:NSN/9130010315816", "INV/#{@modifier}/INV#{@modifier}-125-FSB-JP8.xml"
        get_inventory  "125-FSB", "GREASE,GENERAL PURP:NSN/9150001806383", "INV/#{@modifier}/INV#{@modifier}-125-FSB-GREASE.xml"
        get_inventory  "125-FSB", "PETROLATUM,TECHNICA:NSN/9150002500926", "INV/#{@modifier}/INV#{@modifier}-125-FSB-PETROLATUM.xml"
        get_inventory  "125-FSB", "GLOW PLUG:NSN/2920011883863", "INV/#{@modifier}/INV#{@modifier}-125-FSB-GLOWPLUG.xml"
        get_inventory  "125-FSB", "BELT,VEHICULAR SAFE:NSN/2540013529175", "INV/#{@modifier}/INV#{@modifier}-125-FSB-BELT.xml"
        get_inventory  "125-FSB", "BRAKE SHOE:NSN/2530013549427", "INV/#{@modifier}/INV#{@modifier}-125-FSB-BRAKESHOE.xml"
        get_inventory  "125-FSB", "Level2BulkPOL:BulkPOL", "INV/#{@modifier}/INV#{@modifier}-125-FSB-Level2BulkPOL.xml"
        get_inventory  "125-FSB", "Level2Ammunition:Ammunition", "INV/#{@modifier}/INV#{@modifier}-125-FSB-Level2Ammunition.xml"
      
      
        # 127-DASB inventories
        get_inventory  "127-DASB", "120MM APFSDS-T M829A1:DODIC/C380", "INV/#{@modifier}/INV#{@modifier}-127-DASB-DODIC-C380.xml"
        get_inventory  "127-DASB", "120MM HEAT-MP-T M830:DODIC/C787", "INV/#{@modifier}/INV#{@modifier}-127-DASB-DODIC-C787.xml"
      
        get_inventory  "127-DASB", "MEAL READY-TO-EAT  :NSN/8970001491094", "INV/#{@modifier}/INV#{@modifier}-127-DASB-MRE.xml"
        get_inventory  "127-DASB", "FRESH FRUITS  :NSN/891501F768439", "INV/#{@modifier}/INV#{@modifier}-127-DASB-FRUIT.xml"
      #  get_inventory  "127-DASB", "UNITIZED GROUP RATION - HEAT AND SERVE BREAKFAST :NSN/897UGRHSBRKXX", "INV/#{@modifier}/INV#{@modifier}-127-DASB-BREAKFAST.xml"
        get_inventory  "127-DASB", "DF2:NSN/9140002865294", "INV/#{@modifier}/INV#{@modifier}-127-DASB-DF2.xml"
        get_inventory  "127-DASB", "JP8:NSN/9130010315816", "INV/#{@modifier}/INV#{@modifier}-127-DASB-JP8.xml"
        get_inventory  "127-DASB", "GREASE,GENERAL PURP:NSN/9150001806383", "INV/#{@modifier}/INV#{@modifier}-127-DASB-GREASE.xml"
        get_inventory  "127-DASB", "PETROLATUM,TECHNICA:NSN/9150002500926", "INV/#{@modifier}/INV#{@modifier}-127-DASB-PETROLATUM.xml"
        get_inventory  "127-DASB", "GLOW PLUG:NSN/2920011883863", "INV/#{@modifier}/INV#{@modifier}-127-DASB-GLOWPLUG.xml"
        get_inventory  "127-DASB", "BELT,VEHICULAR SAFE:NSN/2540013529175", "INV/#{@modifier}/INV#{@modifier}-127-DASB-BELT.xml"
        get_inventory  "127-DASB", "Level2BulkPOL:BulkPOL", "INV/#{@modifier}/INV#{@modifier}-127-DASB-Level2BulkPOL.xml"
        get_inventory  "127-DASB", "Level2Ammunition:Ammunition", "INV/#{@modifier}/INV#{@modifier}-127-DASB-Level2Ammunition.xml"
      
        # 501-FSB inventories
        get_inventory  "501-FSB", "120MM APFSDS-T M829A1:DODIC/C380", "INV/#{@modifier}/INV#{@modifier}-501-FSB-DODIC-C380.xml" 
        get_inventory  "501-FSB", "120MM HEAT-MP-T M830:DODIC/C787", "INV/#{@modifier}/INV#{@modifier}-501-FSB-DODIC-C787.xml"
      
        get_inventory  "501-FSB", "MEAL READY-TO-EAT  :NSN/8970001491094", "INV/#{@modifier}/INV#{@modifier}-501-FSB-MRE.xml"
        get_inventory  "501-FSB", "FRESH FRUITS  :NSN/891501F768439", "INV/#{@modifier}/INV#{@modifier}-501-FSB-FRUIT.xml"
      #  get_inventory  "501-FSB", "UNITIZED GROUP RATION - HEAT AND SERVE BREAKFAST :NSN/897UGRHSBRKXX", "INV/#{@modifier}/INV#{@modifier}-501-FSB-BREAKFAST.xml"
        get_inventory  "501-FSB", "DF2:NSN/9140002865294", "INV/#{@modifier}/INV#{@modifier}-501-FSB-DF2.xml"
        get_inventory  "501-FSB", "JP8:NSN/9130010315816", "INV/#{@modifier}/INV#{@modifier}-501-FSB-JP8.xml"
        get_inventory  "501-FSB", "GREASE,GENERAL PURP:NSN/9150001806383", "INV/#{@modifier}/INV#{@modifier}-501-FSB-GREASE.xml"
        get_inventory  "501-FSB", "PETROLATUM,TECHNICA:NSN/9150002500926", "INV/#{@modifier}/INV#{@modifier}-501-FSB-PETROLATUM.xml"
        get_inventory  "501-FSB", "GLOW PLUG:NSN/2920011883863", "INV/#{@modifier}/INV#{@modifier}-501-FSB-GLOWPLUG.xml"
        get_inventory  "501-FSB", "BELT,VEHICULAR SAFE:NSN/2540013529175", "INV/#{@modifier}/INV#{@modifier}-501-FSB-BELT.xml"
        get_inventory  "501-FSB", "BRAKE SHOE:NSN/2530013549427", "INV/#{@modifier}/INV#{@modifier}-501-FSB-BRAKESHOE.xml"
        get_inventory  "501-FSB", "Level2BulkPOL:BulkPOL", "INV/#{@modifier}/INV#{@modifier}-501-FSB-Level2BulkPOL.xml"
        get_inventory  "501-FSB", "Level2Ammunition:Ammunition", "INV/#{@modifier}/INV#{@modifier}-501-FSB-Level2Ammunition.xml"
      
        # 123-MSB inventories
        get_inventory  "123-MSB", "120MM APFSDS-T M829A1:DODIC/C380", "INV/#{@modifier}/INV#{@modifier}-123-MSB-DODIC-C380.xml"
        get_inventory  "123-MSB", "120MM HEAT-MP-T M830:DODIC/C787", "INV/#{@modifier}/INV#{@modifier}-123-MSB-DODIC-C787.xml"
        get_inventory  "123-MSB", "MEAL READY-TO-EAT  :NSN/8970001491094", "INV/#{@modifier}/INV#{@modifier}-123-MSB-MRE.xml"
        get_inventory  "123-MSB", "FRESH FRUITS  :NSN/891501F768439", "INV/#{@modifier}/INV#{@modifier}-123-MSB-FRUIT.xml"
        get_inventory  "123-MSB", "UNITIZED GROUP RATION - HEAT AND SERVE BREAKFAST :NSN/897UGRHSBRKXX", "INV/#{@modifier}/INV#{@modifier}-123-MSB-BREAKFAST.xml"
        get_inventory  "123-MSB", "DF2:NSN/9140002865294", "INV/#{@modifier}/INV#{@modifier}-123-MSB-DF2.xml"
        get_inventory  "123-MSB", "JP8:NSN/9130010315816", "INV/#{@modifier}/INV#{@modifier}-123-MSB-JP8.xml"
        get_inventory  "123-MSB", "GREASE,GENERAL PURP:NSN/9150001806383", "INV/#{@modifier}/INV#{@modifier}-123-MSB-GREASE.xml"
        get_inventory  "123-MSB", "PETROLATUM,TECHNICA:NSN/9150002500926", "INV/#{@modifier}/INV#{@modifier}-123-MSB-PETROLATUM.xml"
        get_inventory  "123-MSB", "GLOW PLUG:NSN/2920011883863", "INV/#{@modifier}/INV#{@modifier}-123-MSB-GLOWPLUG.xml"
        get_inventory  "123-MSB", "BELT,VEHICULAR SAFE:NSN/2540013529175", "INV/#{@modifier}/INV#{@modifier}-123-MSB-BELT.xml"
        get_inventory  "123-MSB", "Level2BulkPOL:BulkPOL", "INV/#{@modifier}/INV#{@modifier}-123-Level2BulkPOL.xml"
        get_inventory  "123-MSB", "Level2Ammunition:Ammunition", "INV/#{@modifier}/INV#{@modifier}-123-Level2Ammunition.xml"
        get_inventory  "123-MSB", "BRAKE SHOE:NSN/2530013549427", "INV/#{@modifier}/INV#{@modifier}-123-MSB-BRAKESHOE.xml"
      
        # 191-ORDBN Inventory
        get_inventory  "191-ORDBN", "120MM APFSDS-T M829A1:DODIC/C380", "INV/#{@modifier}/INV#{@modifier}-191-ORDBN-DODIC-C380.xml"
        get_inventory  "191-ORDBN", "120MM HEAT-MP-T M830:DODIC/C787", "INV/#{@modifier}/INV#{@modifier}-191-ORDBN-DODIC-C787.xml"
        get_inventory  "191-ORDBN", "Level2Ammunition:Ammunition", "INV/#{@modifier}/INV#{@modifier}-191-Level2Ammunition.xml"
      
        # 592-ORDCO Inventory
        get_inventory  "592-ORDCO", "120MM APFSDS-T M829A1:DODIC/C380", "INV/#{@modifier}/INV#{@modifier}-592-ORDCO-DODIC-C380.xml"
        get_inventory  "592-ORDCO", "120MM HEAT-MP-T M830:DODIC/C787", "INV/#{@modifier}/INV#{@modifier}-592-ORDCO-DODIC-C787.xml"
        get_inventory  "592-ORDCO", "Level2Ammunition:Ammunition", "INV/#{@modifier}/INV#{@modifier}-592-Level2Ammunition.xml"
      
        # 343-SUPPLYCO Inventory
        get_inventory  "343-SUPPLYCO", "MEAL READY-TO-EAT  :NSN/8970001491094", "INV/#{@modifier}/INV#{@modifier}-343-SUPPLYCO-MRE.xml"
        get_inventory  "343-SUPPLYCO", "FRESH FRUITS  :NSN/891501F768439", "INV/#{@modifier}/INV#{@modifier}-343-SUPPLYCO-FRUIT.xml"
        get_inventory  "343-SUPPLYCO", "UNITIZED GROUP RATION - HEAT AND SERVE BREAKFAST :NSN/897UGRHSBRKXX", "INV/#{@modifier}/INV#{@modifier}-343-SUPPLYCO-BREAKFAST.xml"
      
        # 227-SUPPLYCO Inventory
        get_inventory  "227-SUPPLYCO", "MEAL READY-TO-EAT  :NSN/8970001491094", "INV/#{@modifier}/INV#{@modifier}-227-SUPPLYCO-MRE.xml"
        get_inventory  "227-SUPPLYCO", "FRESH FRUITS  :NSN/891501F768439", "INV/#{@modifier}/INV#{@modifier}-227-SUPPLYCO-FRUIT.xml"
        get_inventory  "227-SUPPLYCO", "UNITIZED GROUP RATION - HEAT AND SERVE BREAKFAST :NSN/897UGRHSBRKXX", "INV/#{@modifier}/INV#{@modifier}-227-SUPPLYCO-BREAKFAST.xml"
      
        # 110-POL-SUPPLYCO Inventory
        get_inventory  "110-POL-SUPPLYCO", "DF2:NSN/9140002865294", "INV/#{@modifier}/INV#{@modifier}-110-POL-SUPPLYCO-DF2.xml"
        get_inventory  "110-POL-SUPPLYCO", "JP8:NSN/9130010315816", "INV/#{@modifier}/INV#{@modifier}-110-POL-SUPPLYCO-JP8.xml"
        get_inventory  "110-POL-SUPPLYCO", "GREASE,GENERAL PURP:NSN/9150001806383", "INV/#{@modifier}/INV#{@modifier}-110-POL-SUPPLYCO-GREASE.xml"
        get_inventory  "110-POL-SUPPLYCO", "PETROLATUM,TECHNICA:NSN/9150002500926", "INV/#{@modifier}/INV#{@modifier}-110-POL-SUPPLYCO-PETROLATUM.xml"
        get_inventory  "110-POL-SUPPLYCO", "Level2BulkPOL:BulkPOL", "INV/#{@modifier}/INV#{@modifier}-110-Level2BulkPOL.xml"
      
        # 102-POL-SUPPLYCO Inventory
        get_inventory  "102-POL-SUPPLYCO", "DF2:NSN/9140002865294", "INV/#{@modifier}/INV#{@modifier}-102-POL-SUPPLYCO-DF2.xml"
        get_inventory  "102-POL-SUPPLYCO", "JP8:NSN/9130010315816", "INV/#{@modifier}/INV#{@modifier}-102-POL-SUPPLYCO-JP8.xml"
        get_inventory  "102-POL-SUPPLYCO", "GREASE,GENERAL PURP:NSN/9150001806383", "INV/#{@modifier}/INV#{@modifier}-102-POL-SUPPLYCO-GREASE.xml"
        get_inventory  "102-POL-SUPPLYCO", "PETROLATUM,TECHNICA:NSN/9150002500926", "INV/#{@modifier}/INV#{@modifier}-102-POL-SUPPLYCO-PETROLATUM.xml"
        get_inventory  "102-POL-SUPPLYCO", "Level2BulkPOL:BulkPOL", "INV/#{@modifier}/INV#{@modifier}-102-Level2BulkPOL.xml"
      
        # 565-RPRPTCO Inventory
        get_inventory  "565-RPRPTCO", "GLOW PLUG:NSN/2920011883863", "INV/#{@modifier}/INV#{@modifier}-565-RPRPTCO-GLOWPLUG.xml"
        get_inventory  "565-RPRPTCO", "BELT,VEHICULAR SAFE:NSN/2540013529175", "INV/#{@modifier}/INV#{@modifier}-565-RPRPTCO-BELT.xml"
        get_inventory  "565-RPRPTCO", "BRAKE SHOE:NSN/2530013549427", "INV/#{@modifier}/INV#{@modifier}-565-RPRPTCO-BRAKESHOE.xml"

      end
      
      def get_inventory(agent, asset, file)
	cougaar_agent = @run.society.agents[agent]
        if cougaar_agent
          list, uri = Cougaar::Communications::HTTP.get("#{cougaar_agent.uri}/list")
          if uri
            resp = Cougaar::Communications::HTTP.put("#{uri.scheme}://#{uri.host}:#{uri.port}/$#{agent}/log_inventory", asset)
            File.open(file, "wb") do |f|
              f.puts resp
            end
            @run.archive_and_remove_file(file, "Inventory for agent: #{agent} asset: #{asset}")
          else
            @run.error_message "Inventory failed to redirect to agent: #{agent}"
          end
        else
          @run.error_message "Inventory failed, unknown agent: #{agent}"
        end
      end
    end
  
    # Sample the inventory of a society in predefined places
    class SampleInventory < Cougaar::Action
      PRIOR_STATES = ["SocietyRunning"]

      attr_accessor :asset, :agent, :protocol, :society, :runport, :runhost

      # Take the asset to get the inventory for at this agent
      def initialize(run, agent, asset, file)
        super(run)
          @file = file
          @asset = asset
          @agent = agent
          @protocol = "http" 
      end

      def save(result)
        File.open(@file, "wb") do |file|
          file.puts result
        end
        @run.archive_and_remove_file(@file, "Inventory for agent: #{@agent} asset: #{@asset}")
      end

      def perform
        cougaar_agent = @run.society.agents[@agent]
        if cougaar_agent
          list, uri = Cougaar::Communications::HTTP.get("#{cougaar_agent.uri}/list")
          if uri
            #puts "SampleInventory: About to do put to: #{uri.scheme}://#{uri.host}:#{uri.port}/$#{@agent}/log_inventory for #{@asset}"
            resp = Cougaar::Communications::HTTP.put("#{uri.scheme}://#{uri.host}:#{uri.port}/$#{@agent}/log_inventory", @asset)
            save(resp)
          else
            @run.error_message "Inventory failed to redirect to agent: #{@agent}"
          end
        else
          @run.error_message "Inventory failed, unknown agent: #{@agent}"
        end
      end
    end
  end
end

