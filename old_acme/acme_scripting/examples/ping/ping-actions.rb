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
# Utility methods for creating a ping society
#

module Cougaar
  module Actions
    class AddPing < Cougaar::Action
      PRIOR_STATES = ["SocietyLoaded"]
      DOCUMENTATION = Cougaar.document {
        @description = "Transform society with added ping components"
        @parameters = [
          {:source=> "required, Source Agent"},
          {:dest=> "required, Destination Agent"},
          {:args=> "optional, hash of arguments"}
        ]
        @example = "do_action 'AddPing', 'AgentA', 'AgentB', {'eventMillis' => '10000'}"
      }
      def initialize(run, source, dest, args)
        super(run)
        @source = source
        @dest = dest
        @args = args
      end
      def perform
        srcAgent = @run.society.agents[@source]
        if !srcAgent
          raise "Agent #{@source} does not exist in society"
        end
        destAgent = @run.society.agents[@dest]
        if !destAgent
          raise "Agent #{@dest} does not exist in society"
        end

        srcAgent.add_component("org.cougaar.ping.PingAdderPlugin") do |c|
          c.classname = "org.cougaar.ping.PingAdderPlugin"
          c.add_argument("target=#{@dest}")
          @args.each_pair {|key, value|
            c.add_argument("#{key}=#{value}")
          }
        end
      end
    end
    class SetupPingTimers < Cougaar::Action
      PRIOR_STATES = ["SocietyLoaded"]
      DOCUMENTATION = Cougaar.document {
        @description = "Transform society with ping components"
        @parameters = [
          {:wake_time=> "required, Time between ping checks"}
        ]
        @example = "do_action 'SetupPingTimers', '1000'"
      }
      def initialize(run, wake_time)
        super(run)
        @wake_time = wake_time
      end
      def perform
        @run.society.each_agent do |agent|
          if agent.has_component?("org.cougaar.ping.PingAdderPlugin")
            unless agent.has_component?("org.cougaar.ping.PingTimerPlugin")
              c = agent.add_component("org.cougaar.ping.PingTimerPlugin")
              c.classname = "org.cougaar.ping.PingTimerPlugin"
              c.add_argument("#{@wake_time}")
            end
          end
        end
      end
    end
    class SetupCommunityPlugins < Cougaar::Action
      PRIOR_STATES = ["SocietyLoaded"]
      DOCUMENTATION = Cougaar.document {
        @description = "Transform society with community plugins"
        @parameters = []
        @example = "do_action 'SetupCommunityPlugins'"
      }
      def perform
        @run.society.each_agent(false) do |agent|
          unless agent.has_component?('org.cougaar.community.CommunityPlugin')
            agent.add_component('org.cougaar.community.CommunityPlugin') do |c|
              c.classname = 'org.cougaar.community.CommunityPlugin'
            end
          end
        end
      end
    end
  end
end
