##
#  <copyright>
#  Copyright 2002 BBN Technologies
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

module Cougaar; module Actions
  class EnableNetworkShaping < Cougaar::Action
    DOCUMENTATION = Cougaar.document {
      @description = "Enable network shaping at the K level."
      @parameters = [
         {:host=>"required, Hostname which contains the router.}
      ]
      @example = "do_action 'EnableNetworkShaping', 'sv023'"
    }

    def initialize( run, hostname )
      super( run )
      @hostname = hostname
    end

    def perform
      host = @run.society.hosts[@hostname]
      @run.comms.new_message(host).set_body("command[shape]trigger")
    end
  end

  class DisableNetworkShaping < Cougaar:Action
    DOCUMENTATION = Cougaar.document {
      @description = "Disable network shaping at the K level."
      @parameters = [
         {:host=>"required, Hostname which contains the router.}
      ]
      @example = "do_action 'DisableNetworkShaping', 'sv023'"
    }

    def initialize( run, hostname )
      super( run )
      @hostname = hostname
    end

    def perform
      host = @run.society.hosts[@hostname]
      @run.comms.new_message(host).set_body("command[shape]reset")
    end
  end
end; end

