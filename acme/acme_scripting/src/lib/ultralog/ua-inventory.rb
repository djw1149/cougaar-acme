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
        get_inventory  "FCS-C2V-0.1-PLT-HQ.INFCO-A.1-CABN.1-UA.ARMY.MIL", "JP8:NSN/9130010315816:FCS-C2V-0.1-PLT-HQ.INFCO-A.1-CABN.1-UA.ARMY.MIL", "INV/#{@modifier}/INV#{@modifier}FCS-C2V-0.1-PLT-HQ.INFCO-A.1-CABN.1-UA.ARMY.MIL.xml"
        get_inventory  "FCS-ARV-A-0.1-PLT-HQ.INFCO-A.1-CABN.1-UA.ARMY.MIL", "JP8:NSN/9130010315816:FCS-ARV-A-0.1-PLT-HQ.INFCO-A.1-CABN.1-UA.ARMY.MIL", "INV/#{@modifier}/INV#{@modifier}-FCS-ARV-A-0.1-PLT-HQ.INFCO-A.1-CABN.1-UA.ARMY.MIL.xml"
        get_inventory  "FCS-ARV-R-0.1-PLT.RECON-DET.1-CABN.1-UA.ARMY.MIL", "JP8:NSN/9130010315816:FCS-ARV-R-0.1-PLT.RECON-DET.1-CABN.1-UA.ARMY.MIL", "INV/#{@modifier}/INV#{@modifier}-FCS-ARV-R-0.1-PLT.RECON-DET.1-CABN.1-UA.ARMY.MIL.xml"
        get_inventory  "FCS-ARV-A-0.1-PLT-HQ.INFCO-A.2-CABN.1-UA.ARMY.MIL", "JP8:NSN/9130010315816:FCS-ARV-A-0.1-PLT-HQ.INFCO-A.2-CABN.1-UA.ARMY.MIL", "INV/#{@modifier}/INV#{@modifier}FCS-ARV-A-0.-1-PLT-HQ.INFCO-A.2-CABN.1-UA.ARMY.MIL.xml"
        get_inventory  "FCS-MCS-0.2-PLT.MCSCO-B.2-CABN.1-UA.ARMY.MIL", "JP8:NSN/9130010315816:FCS-MCS-0.2-PLT.MCSCO-B.2-CABN.1-UA.ARMY.MIL", "INV/#{@modifier}/INV#{@modifier}-FCS-MCS-0.2-PLT.MCSCO-B.2-CABN.1-UA.ARMY.MIL.xml"
        get_inventory  "FCS-ICV-0.MCG1.1-UA.ARMY.MIL", "JP8:NSN/9130010315816:FCS-ICV-0.MCG1.1-UA.ARMY.MIL", "INV/#{@modifier}/INV#{@modifier}-FCS-ICV-0.MCG1.1-UA.ARMY.MIL-FCS-ICV-0.xml"

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

