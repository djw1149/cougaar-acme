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
    #Org provider schedule 
    class RelationshipServlet < Cougaar::Action
      PRIOR_STATES = ["SocietyRunning"]

      attr_accessor :asset, :agent, :protocol, :society, :runport, :runhost

      # Take the asset to get the inventory for at this agent
      def initialize(run, agent, asset, file)
        super(run)
          @file = file
          @asset = asset
          @agent = agent
          @protocol = "http" 
      end

      def save(result)
        File.open(@file, "wb") do |file|
          file.puts result
        end
        @run.archive_and_remove_file(@file, "Relationship schedule for agent: #{@agent} asset: #{@asset}")
      end

      def perform
        cougaar_agent = @run.society.agents[@agent]
        if cougaar_agent
          list, uri = Cougaar::Communications::HTTP.get("#{cougaar_agent.uri}/list")
          if uri
            @run.info_message "OrgRelationship Schedule: About to do put to: #{uri.scheme}://#{uri.host}:#{uri.port}/$#{@agent}/relationship_schedule for #{@asset}"
            resp = Cougaar::Communications::HTTP.put("#{uri.scheme}://#{uri.host}:#{uri.port}/$#{@agent}/relationship_schedule", @asset)
            save(resp)
          else
            @run.error_message "Relationship Servlet failed to redirect to agent: #{@agent}"
          end
        else
          @run.error_message "Relationship Servlet failed, unknown agent: #{@agent}"
        end
      end
    end
  end
end

