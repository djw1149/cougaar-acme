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

module Cougaar; module Actions
  class StartMessageGenerator < Cougaar::Action
    DOCUMENTATION = Cougaar.document {
        @description = "Starts the Message Generator with specified nodes, rate, and size."
        @parameters = [
          {:send=> "Host which sends messages" },
          {:recv=> "Host which receives messages"},
          {:rate=> "Number of UDP packets/second" }
        ]
        @example = "do_action 'StartMessageGenerator', 'sv036', 'sv024', 10"
    }

    def initialize(run, sendHost, recvHost, rate)
      super(run)
      @sendHostName = sendHost
      @recvHostName = recvHost
      @rate = rate
    end

    def perform
      recvHost = @run.society.hosts[@recvHostName]
      sendHost = @run.society.hosts[@sendHostName]
      if sendHost
        puts "MGEN: #{recvHost.ip} => #{sendHost.ip} @ #{@rate} msg/sec"
        @run.comms.new_message(sendHost).set_body("command[mgen]go(#{recvHost.ip},#{@rate})").send
      else
        raise_failure "Cannot start MGEN on #{@sendHost}."
      end
    end
  end

  class StopMessageGenerator < Cougaar::Action
    DOCUMENTATION = Cougaar.document {
      @description = "Stop traffic generation."
      @parameters = [
         {:host=>"required, Hostname which is initiating the traffic."}
      ]
      @example = "do_action 'StopMessageGenerator', 'sv023'"
    }

    def initialize( run, hostname )
      super( run )
      @hostname = hostname
    end

    def perform
      host = @run.society.hosts[@hostname]
      @run.comms.new_message(host).set_body("command[mgen]stop").send
    end
  end

end; end

 



