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
  
    class UAInventory < Cougaar::Action
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
	Dir.mkdir("INV") unless File.exist?("INV")
	Dir.mkdir("INV/#{@modifier}") if Dir["INV/#{@modifier}"].empty?


        # Get some inventory charts
        get_inventory  "FCS-ICV-0.2-PLT-3-INF-SQUAD.INFCO-A.3-CABN.1-UA.ARMY.MIL", "JP8:NSN/9130010315816:FCS-ICV-0.2-PLT-3-INF-SQUAD.INFCO-A.3-CABN.1-UA.ARMY.MIL", "INV/#{@modifier}/INV#{@modifier}-FCS-ICV-0.2-PLT-3-INF-SQUAD.INFCO-A.3-CABN.1-UA.ARMY.MIL-JP8.xml"

        get_inventory  "FCS-ICV-0.3-PLT-WPN-SQUAD.INFCO-B.1-CABN.1-UA.ARMY.MIL", "JP8:NSN/9130010315816:FCS-ICV-0.3-PLT-WPN-SQUAD.INFCO-B.1-CABN.1-UA.ARMY.MIL", "INV/#{@modifier}/INV#{@modifier}-FCS-ICV-0.3-PLT-WPN-SQUAD.INFCO-B.1-CABN.1-UA.ARMY.MIL-JP8.xml"

        get_inventory  "FCS-C2V-1.CO-HQ.INFCO-A.3-CABN.1-UA.ARMY.MIL", "JP8:NSN/9130010315816:FCS-C2V-1.CO-HQ.INFCO-A.3-CABN.1-UA.ARMY.MIL", "INV/#{@modifier}/INV#{@modifier}-FCS-C2V-1.CO-HQ.INFCO-A.3-CABN.1-UA.ARMY.MIL-JP8.xml"

        get_inventory  "FCS-RS-V-2.2-PLT.RECON-DET.2-CABN.1-UA.ARMY.MIL", "JP8:NSN/9130010315816:FCS-RS-V-2.2-PLT.RECON-DET.2-CABN.1-UA.ARMY.MIL", "INV/#{@modifier}/INV#{@modifier}-FCS-RS-V-2.2-PLT.RECON-DET.2-CABN.1-UA.ARMY.MIL-JP8.xml"

        get_inventory  "FCS-MCS-2.1-PLT.MCSCO-A.2-CABN.1-UA.ARMY.MIL", "JP8:NSN/9130010315816:FCS-MCS-2.1-PLT.MCSCO-A.2-CABN.1-UA.ARMY.MIL", "INV/#{@modifier}/INV#{@modifier}-FCS-MCS-2.1-PLT.MCSCO-A.2-CABN.1-UA.ARMY.MIL-JP8.xml"

        get_inventory  "FCS-MCS-2.2-PLT.MCSCO-B.3-CABN.1-UA.ARMY.MIL", "JP8:NSN/9130010315816:FCS-MCS-2.2-PLT.MCSCO-B.3-CABN.1-UA.ARMY.MIL", "INV/#{@modifier}/INV#{@modifier}-FCS-MCS-2.2-PLT.MCSCO-B.3-CABN.1-UA.ARMY.MIL-JP8.xml"

        get_inventory  "NLOS-Mortar-3.1-PLT.MORTAR-BTY.3-CABN.1-UA.ARMY.MIL", "JP8:NSN/9130010315816:NLOS-Mortar-3.1-PLT.MORTAR-BTY.3-CABN.1-UA.ARMY.MIL", "INV/#{@modifier}/INV#{@modifier}-NLOS-Mortar-3.1-PLT.MORTAR-BTY.3-CABN.1-UA.ARMY.MIL-JP8.xml"

        get_inventory  "NLOS-Cannon-2.BTY-C-1-CANNON-PLT.NLOS-BN.1-UA.ARMY.MIL", "JP8:NSN/9130010315816:NLOS-Cannon-2.BTY-C-1-CANNON-PLT.NLOS-BN.1-UA.ARMY.MIL", "INV/#{@modifier}/INV#{@modifier}-NLOS-Cannon-2.BTY-C-1-CANNON-PLT.NLOS-BN.1-UA.ARMY.MIL-JP8.xml"

        get_inventory  "FCS-ARV-A-5.SUPPORT-SECTION.1-CABN.1-UA.ARMY.MIL", "JP8:NSN/9130010315816:FCS-ARV-A-5.SUPPORT-SECTION.1-CABN.1-UA.ARMY.MIL", "INV/#{@modifier}/INV#{@modifier}-FCS-ARV-A-5.SUPPORT-SECTION.1-CABN.1-UA.ARMY.MIL-JP8.xml"

        get_inventory  "FCS-ARV-R-0.3-PLT.MCSCO-A.1-CABN.1-UA.ARMY.MIL", "JP8:NSN/9130010315816:FCS-ARV-R-0.3-PLT.MCSCO-A.1-CABN.1-UA.ARMY.MIL", "INV/#{@modifier}/INV#{@modifier}-FCS-ARV-R-0.3-PLT.MCSCO-A.1-CABN.1-UA.ARMY.MIL-JP8.xml"

        get_inventory  "FCS-MV-4.MED-PLT-EVAC-SECTION.3-CABN.1-UA.ARMY.MIL", "JP8:NSN/9130010315816:FCS-MV-4.MED-PLT-EVAC-SECTION.3-CABN.1-UA.ARMY.MIL", "INV/#{@modifier}/INV#{@modifier}-FCS-MV-4.MED-PLT-EVAC-SECTION.3-CABN.1-UA.ARMY.MIL-JP8.xml"

        get_inventory  "FCS-RMV-9.MAINT-PLT.FSB.1-UA.ARMY.MIL", "JP8:NSN/9130010315816:FCS-RMV-9.MAINT-PLT.FSB.1-UA.ARMY.MIL", "INV/#{@modifier}/INV#{@modifier}-FCS-RMV-9.MAINT-PLT.FSB.1-UA.ARMY.MIL-JP8.xml"

        get_inventory  "FTTS-U-C2-3.SIT-AWARE-TEAM.BIC.1-UA.ARMY.MIL", "JP8:NSN/9130010315816:FTTS-U-C2-3.SIT-AWARE-TEAM.BIC.1-UA.ARMY.MIL", "INV/#{@modifier}/INV#{@modifier}-FTTS-U-C2-3.SIT-AWARE-TEAM.BIC.1-UA.ARMY.MIL-JP8.xml"

        get_inventory  "FTTS-U-SPT-5.RADAR-SECTION.NLOS-BN.1-UA.ARMY.MIL", "JP8:NSN/9130010315816:FTTS-U-SPT-5.RADAR-SECTION.NLOS-BN.1-UA.ARMY.MIL", "INV/#{@modifier}/INV#{@modifier}-FTTS-U-SPT-5.RADAR-SECTION.NLOS-BN.1-UA.ARMY.MIL-JP8.xml"

        get_inventory  "FTTS-MS-36.DRY-CARGO-SECTION.FSB.1-UA.ARMY.MIL", "JP8:NSN/9130010315816:FTTS-MS-36.DRY-CARGO-SECTION.FSB.1-UA.ARMY.MIL", "INV/#{@modifier}/INV#{@modifier}-FTTS-MS-36.DRY-CARGO-SECTION.FSB.1-UA.ARMY.MIL-JP8.xml"

        get_inventory  "FTTS-AMB-3.AREA-SPT-EVAC-SECTION.FSB.1-UA.ARMY.MIL", "JP8:NSN/9130010315816:FTTS-AMB-3.AREA-SPT-EVAC-SECTION.FSB.1-UA.ARMY.MIL", "INV/#{@modifier}/INV#{@modifier}-FTTS-AMB-3.AREA-SPT-EVAC-SECTION.FSB.1-UA.ARMY.MIL-JP8.xml"

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
  
  end
end

