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

require 'cougaar/communities'

#
# This is an alternative to using "LoadSocietyFromXML".  Here
# we create an empty society and add the agents using Ruby.
#
module Cougaar
  module Actions
    class BuildSocietyFromScratch < Cougaar::Action
      RESULTANT_STATE = "SocietyLoaded"
      DOCUMENTATION = Cougaar.document {
        @description = "Create an empty society definition."
        @parameters = [
          :name => "required, The name of the society"
        ]
        @example = "do_action 'BuildSocietyFromScratch', 'MiniPing'"
      }
      def initialize(run, name)
        super(run)
        @name = name
      end
      def perform
        @run.society = Cougaar::Model::Society.new(@name) do |society|
          society.add_host('localhost') do |host|
            host.add_facet({'enclave' => 'EnclaveA'})
            host.add_facet({'service' => 'nfs'})
            host.add_facet({'service' => 'smtp'})
            host.add_facet({'service' => 'jabber'})
            host.add_facet({'service' => 'message-router'})
            host.add_facet({'service' => 'operator'})
            host.add_facet({'service' => 'acme'})
    
            host.add_node('NodeA') do |node|
              node.add_agent('AgentA')
            end
            host.add_node('NodeB') do |node|
              node.add_agent('AgentB')
            end
            host.add_node('NodeC') do |node|
              node.add_agent('AgentC')
            end
            host.add_node('NodeD');
          end
        end
      end
    end
  end
end
