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
require 'xmlrpc/client'

module Cougaar
  module Actions
    class KillNodes < Cougaar::Action
      def initialize(run, *nodes)
        super(run)
        @nodes = nodes
      end
      def perform
        pids = @run['pids']
        
        node_type = ""
        if @run["loader"] == "XML"
          node_type = "xml_"
        end
        
        @nodes.each do |node|
          pid = pids[node]
          cougaar_node = @society.nodes[node]
          if pid && cougaar_node
            pids.delete(node)
            result = @run.comms.new_message(cougaar_node.host).set_body("command[stop_#{node_type}node]#{pid}").request(60)
            if result.nil?
              raise_failure "Could not kill node #{node}(#{pid}) on host #{cougaar_node.host.host_name}"
            end
          else
            raise_failure "Could not kill node #{node}...node unknown."
          end
        end
      end
    end
    class KillNode < KillNodes
      def initialize(run, node)
        super(run, node)
      end
    end
  end
end
