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
    class DisableNetworkInterfaces < Cougaar::Action
      PRIOR_STATES = ["SocietyLoaded"]
      def initialize(run, *nodes)
        super(run)
        @nodes = nodes
      end
      def perform
        @nodes.each do |node|
          cougaar_node = @run.society.nodes[node]
          if cougaar_node
            @run.comms.new_message(cougaar_node.host).set_body("command[nic]trigger").send
          else
            raise_failure "Cannot disable nic on node #{node}, node unknown."
          end
        end
      end
    end
    class EnableNetworkInterfaces < Cougaar::Action
      PRIOR_STATES = ["SocietyLoaded"]
      def initialize(run, *nodes)
        super(run)
        @nodes = nodes
      end
      def perform
        @nodes.each do |node|
          cougaar_node = @run.society.nodes[node]
          if cougaar_node
            @run.comms.new_message(cougaar_node.host).set_body("command[nic]reset").send
          else
            raise_failure "Cannot enable nic on node #{node}, node unknown."
          end
        end
      end
    end
  end
end
