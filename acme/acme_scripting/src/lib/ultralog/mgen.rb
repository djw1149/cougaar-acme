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
        @description = "Starts the Message Generator with specified hosts, rate, and size."
        @parameters = [
          {:send=> "Host/Service which sends messages" },
          {:recv=> "Host/Service which receives messages"},
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
      unless recvHost
       @run.society.each_service_host(@recvHostName) {|h| recvHost = h}
      end
      unless sendHost
       @run.society.each_service_host(@sendHostName) {|h| sendHost = h}
      end
      if sendHost && recvHost
        @run.info_message "MGEN: #{recvHost.ip} => #{sendHost.ip} @ #{@rate} msg/sec"
        @run.comms.new_message(sendHost).set_body("command[mgen]go(#{recvHost.ip},#{@rate})").send
      else
        @run.error_message "Cannot find host (or host with service) named: #{@recvHostName} or #{@sendHostName}"
      end
    end
    
    def to_s
      super.to_s+"('#{@sendHostName}', '#{@recvHostName}', #{@rate})"
    end
  end

  class StopMessageGenerator < Cougaar::Action
    DOCUMENTATION = Cougaar.document {
      @description = "Stop traffic generation."
      @parameters = [
         {:host=>"required, Host/service name which is initiating the traffic."}
      ]
      @example = "do_action 'StopMessageGenerator', 'sv023'"
    }

    def initialize( run, hostname )
      super( run )
      @hostname = hostname
    end

    def perform
      host = @run.society.hosts[@hostname]
      unless host
       @run.society.each_service_host(@hostname) {|h| host = h}
      end
      if host
        @run.comms.new_message(host).set_body("command[mgen]stop").send
      else
        @run.error_message "Cannot find host (or host with service) named: #{@hostname}"
      end
    end
    def to_s
      super.to_s+"('#{@hostname}')"
    end
  end

end; end

 



