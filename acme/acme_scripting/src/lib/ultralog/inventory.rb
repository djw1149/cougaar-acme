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
    # Sample the inventory of a society in predefined places
    class SampleInventory < Cougaar::Action
      PRIOR_STATES = ["SocietyRunning"]

      attr_accessor :asset, :agent, :protocol, :society, :runport, :runhost

      # Take the asset to get the inventory for at this agent
      def initialize(run, asset, agent, file)
        super(run)
	@file = file
	@asset = asset
	@agent = agent
	@protocol = "http" # it would be nice to support https
      end

      def save(result)
        File.open(@file, "wb") do |file|
          file.puts result
        end
      end

      def perform
	# Get the http port set earlier for this society
	@runport = @run.society.cougaar_port 
	# find the host this agent is running on (at config time)
	@runhost = @run.society.agents[@agent].node.host.host_name

	#puts "using port #{@runport}"
	#puts "and host #{@runhost}"

	puts "SampleInventory: About to do put to: #{@protocol}://#{@runhost}:#{@runport}/$#{@agent}/log_inventory   of #{@asset}"
	resp = Cougaar::Communications::HTTP.put("#{@protocol}://#{@runhost}:#{@runport}/$#{@agent}/log_inventory", @asset)

	# FIXME: Perhaps we need to handle redirects?

	# do something with the response - write to a file?
	puts "Response: " + resp

	save(resp)
      end
    end
  end
end

