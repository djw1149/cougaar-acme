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
    class StartSociety < Cougaar::Action
      PRIOR_STATES = ["CommunicationsRunning"]
      RESULTANT_STATE = "SocietyRunning"
      def perform
        pids = {}
        @run.society.each_active_host do |host|
          host.each_node do |node|
            node.add_parameter("-Dorg.cougaar.event.host=127.0.0.1")
            node.add_parameter("-Dorg.cougaar.event.port=5300")
            node.add_parameter("-Dorg.cougaar.event.experiment=#{@run.name}")
            result = @run.comms.new_message(host).set_body("command[start_node]#{node.parameters.join("\n")}").request(30)
            if result.nil?
              raise_failure "Could not start node #{node.name} on host #{host.host_name}"
            end
            pids[node.name] = result.body
          end
        end
        @run['pids'] = pids
      end
    end
    
    class StopSociety <  Cougaar::Action
      PRIOR_STATES = ["SocietyRunning"]
      RESULTANT_STATE = "SocietyStopped"
      def perform
        pids = @run['pids']
        @run.society.each_host do |host|
          host.each_node do |node|
            result = @run.comms.new_message(host).set_body("command[stop_node]#{pids[node.name]}").request(60)
            if result.nil?
              raise_failure "Could not stop node #{node.name}(#{pids[node.name]}) on host #{host.host_name}"
            end
          end
        end
      end
    end
  end
  
  module States
    class SocietyLoaded < Cougaar::NOOPState
    end
    
    class SocietyRunning < Cougaar::NOOPState
    end
    
    class SocietyStopped < Cougaar::NOOPState
    end
    
    class RunStopped < Cougaar::State
      DEFAULT_TIMEOUT = 20.minutes
      PRIOR_STATES = ["SocietyStopped"]
      def process
        while(true)
          return if @run.stopped?
          sleep 2
        end
        puts "Run Stopped"
      end
    end
  end
  
end

  
