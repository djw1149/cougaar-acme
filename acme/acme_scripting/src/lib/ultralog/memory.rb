##
#  <copyright>
#  Copyright 2002-2004 InfoEther, LLC & BBN Technologies, LLC
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

module Cougaar; module Actions
  class WasteMemory < Cougaar::Action
    PRIOR_STATES = ["SocietyRunning"]
    def initialize(run, memory, *nodes)
      super( run )
      @memory = memory
      @nodes = nodes
    end

    def perform
      if @nodes.empty? then
	@run.society.each_node do |cougaar_node|
          data, uri = Cougaar::Communications::HTTP.get("#{cougaar_node.uri}/$#{cougaar_node.name}/mem-waster?size=#{@memory}")
        end
      else
        @nodes.each do |nodename|
          cougaar_node = @run.society.nodes[nodename]
          if cougaar_node
            data, uri = Cougaar::Communications::HTTP.get("#{cougaar_node.uri}/$#{nodename}/mem-waster?size=#{@memory}")
          else
            @run.error_message "WasteMemory Could not find node: #{nodename}"
          end
        end
      end
    end
  end
   
  class DisableMemWasterLogging < Cougaar::Action
    PRIOR_STATES = ["SocietyRunning"]
    
    # Take the asset to get the inventory for at this agent
    def initialize(run, *nodes)
      super(run)
      @nodes = nodes
    end
    
    def perform
      if @nodes.empty? then
	@run.society.each_node do |cougaar_node|
          data, uri = Cougaar::Communications::HTTP.get("#{cougaar_node.uri}/$#{cougaar_node.name}/mem-waster?log=disable")
        end
      else
        @nodes.each do |nodename|
          cougaar_node = @run.society.nodes[nodename]
          if cougaar_node
            data, uri = Cougaar::Communications::HTTP.get("#{cougaar_node.uri}/$#{nodename}/mem-waster?log=disable")
          else
            @run.error_message "DisableMemWasterLogging Could not find node: #{nodename}"
          end
        end
      end
    end
  end 

  class EnableMemWasterLogging < Cougaar::Action
    PRIOR_STATES = ["SocietyRunning"]
    
    # Take the asset to get the inventory for at this agent
    def initialize(run, *nodes)
      super(run)
      @nodes = nodes
    end
    
    def perform
      if @nodes.empty? then
        @run.society.each_node do |cougaar_node|
          data, uri = Cougaar::Communications::HTTP.get("#{cougaar_node.uri}/$#{cougaar_node.name}/mem-waster?log=enable")
        end
      else
        @nodes.each do |nodename|
          cougaar_node = @run.society.nodes[nodename]
          if cougaar_node
            data, uri = Cougaar::Communications::HTTP.get("#{cougaar_node.uri}/$#{nodename}/mem-waster?log=enable")
          else
            @run.error_message "EnableMemWasterLogging Could not find node: #{nodename}"
          end
        end
      end
    end
  end 
end; end