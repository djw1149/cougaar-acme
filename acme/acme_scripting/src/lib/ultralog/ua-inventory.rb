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
        get_inventory  "1-CA-BN-MCS-CO-A-1-PLT-FCS-MCS-0", "JP8:NSN/9130010315816:1-CA-BN-MCS-CO-A-1-PLT-FCS-MCS-0-FCS-MCS-1", "INV/#{@modifier}/INV#{@modifier}-1-CA-BN-MCS-CO-A-1-PLT-FCS-MCS-0.xml"
        get_inventory  "1-CA-BN-MCS-CO-A-1-PLT-FCS-ARV-R-0", "JP8:NSN/9130010315816:1-CA-BN-MCS-CO-A-1-PLT-FCS-ARV-R-0-FCS-ARV-R-1", "INV/#{@modifier}/INV#{@modifier}-1-CA-BN-MCS-CO-A-1-PLT-FCS-ARV-R-0.xml"
        get_inventory  "1-CA-BN-RECON-DET-1-PLT-FCS-ARV-R-0", "JP8:NSN/9130010315816:1-CA-BN-RECON-DET-1-PLT-FCS-ARV-R-0-ARV-R-1", "INV/#{@modifier}/INV#{@modifier}-1-CA-BN-RECON-DET-1-PLT-FCS-ARV-R-0.xml"
        get_inventory  "2-CA-BN-INF-CO-A-1-PLT-FCS-ICV-1", "JP8:NSN/9130010315816:2-CA-BN-INF-CO-A-1-PLT-FCS-ICV-1-FCS-ICV-1", "INV/#{@modifier}/INV#{@modifier}-2-CA-BN-INF-CO-A-1-PLT-FCS-ICV-1.xml"
        get_inventory  "2-CA-BN-MCS-CO-A-1-PLT-FCS-MCS-0", "JP8:NSN/9130010315816:2-CA-BN-MCS-CO-A-1-PLT-FCS-MCS-0-FCS-MCS-1", "INV/#{@modifier}/INV#{@modifier}2-CA-BN-MCS-CO-A-1-PLT-FCS-MCS-0.xml"
        get_inventory  "UA-MCG2-FCS-ICV-0", "JP8:NSN/9130010315816:UA-MCG2-FCS-ICV-0-FCS-ICV-1", "INV/#{@modifier}/INV#{@modifier}UA-MCG2-FCS-ICV-0.xml"

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

