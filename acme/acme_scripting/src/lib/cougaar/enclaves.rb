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
  module Model
  
    class Society
      def each_enclave
        enclaves = []
        @hostList.each { |host| enclaves << host.enclave if host.enclave && !enclaves.include?(host.enclave) }
        enclaves.each { |enclave| yield enclave }
      end
      
      def each_enclave_host(enclave)
        each_host { |host| yield host.enclave if host.enclave == enclave }
      end
      
      def each_enclave_node(enclave)
        each_node { |node| yield node if node.host.enclave == enclave }
      end
      
      def each_enclave_agent(enclave, include_node_agent=false)
        each_agent(include_node_agent) { |agent| yield agent if agent.node.host.enclave == enclave }
      end
    end
    
    class Host
      def enclave
        return get_facet(:enclave)
      end
      
      def enclave=(enclave)
        each_facet(:enclave) do |facet|
          facet[:enclave] = enclave
        end
      end
    end
    
  end
end