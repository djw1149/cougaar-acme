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

module Cougaar
  module Actions
     class StartMessageGenerator < Cougaar::Action
       PRIOR_STATES = ["SocietyLoaded"]
       DOCUMENTATION = Cougaar.document {
        @description = "Starts the Message Generator with specified nodes, rate, and size."
        @parameters = [
          {:Sendnode=> "node from which to send messages."},
          {:Recvnode=> "node which receives messages"},
	  {:Rate=> "number of UDP packets/second"},
          {:Size=> "size of UDP packet in bytes"},
          {:Duration=> "duration in seconds"}
        ]
        @example = "do_action 'StartMessageGenerator', 'FWD-A', 'REAR-A', 1.0, 100, 10"
      }

       def initialize(run, sendNode, recvNode, rate, size, duration)
        super(run)
 	@sendNode = sendNode
        @recvNode = recvNode
        @rate = rate
        @size = size
        @duration = duration
        end

        def perform
	@recvHost = @run.society.nodes[@recvNode].host
        cougaar_node = @run.society.nodes[@sendNode]
        if cougaar_node
            puts "/usr/local/bin/mgen -q -b #{@recvHost.ip}:5281 -s #{@size} -r #{@rate} -d #{@duration}&"
            @run.comms.new_message(cougaar_node.host).set_body("command[rexec]/usr/local/bin/mgen -q -b #{@recvHost.ip}:5281 -s #{@size} -r #{@rate} -d #{@duration}&").send
        else
          raise_failure "Cannot start MGEN on #{@sendNode}."
        end
      end
    end
  end
end

 



