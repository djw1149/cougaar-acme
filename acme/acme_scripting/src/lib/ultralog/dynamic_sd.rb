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
    # Change the provider roles at an agent
    class DynamicSD < Cougaar::Action
      PRIOR_STATES = ["SocietyRunning"]

      attr_accessor :agent, :role, :availability, :startdate, :enddate

      # Take the role and end date to change at this agent
      def initialize(run, agent, role, availability, start_date, end_date)
        super(run)
          @role = role
          @availability = availability
          @startdate = start_date
          @enddate = end_date
          @agent = agent
          @add = "Add"
          @publish = "Publish+All+Rows"
          @protocol = "http"
      end

      def perform
        cougaar_agent = @run.society.agents[@agent]
        if cougaar_agent
          result = Cougaar::Communications::HTTP.get("#{cougaar_agent.uri}/availabilityServlet?role=#{@role}&Availability=#{@availability}&startdate=#{@startdate}&enddate=#{@enddate}&action=#{@add}") 
 @run.error_message "Failed to add role/availability SD_Use_Case on #{cougaar_agent.uri}" unless result
          result = Cougaar::Communications::HTTP.get("#{cougaar_agent.uri}/availabilityServlet?action=#{@publish}") 
          @run.error_message "Failed to publish rows in SD_Use_Case on #{cougaar_agent.uri}" unless result
        else
          @run.error_message "SD Use Case, unknown agent: #{@agent}"
        end
      end
    end
  end
end 