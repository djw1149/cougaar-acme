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
  class CyclicStress < Cougaar::Action
    DOCUMENTATION = Cougaar.document {
      @description = "Abstract Action.  This action will apply a stress in a cyclical pattern."
      @example = "do_action 'CyclicStress', 'ugga', 1.seconds, 3.seconds"
    }

    @@threads = {}

    attr_accessor :pid

    def initialize( run, name, on_time, off_time ) 
      @run = run
      super( run )
      @@threads[name] = self
      @on_time = on_time
      @off_time = off_time
    end

    def perform
      @running = true
      trap ("SIGUSR1") {
        @running = false
      }

      @pid = fork {
         i = 0 
         while (@running) do
           stress_on
           sleep( @on_time )
           stress_off
           sleep( @off_time )
           i += 1
           if (i > 20) then
             @run.error_message("WARNING!  Killing the thread because it hasn't stopped.")
             @running = false
           end 
         end
      }
    end

    def stress_on
      @run.info_message("#{@name}: ON")
    end

    def stress_off
      @run.info_message("#{@name}: OFF")
    end

    def self.threads
      @@threads
    end
  end

  class StopCyclicStress < Cougaar::Action
    def initialize( run, name ) 
      super( run )
      @run = run
      @name = name
    end

    def perform
      cs = CyclicStress.threads[@name]
      Process.kill( "SIGUSR1", cs.pid )
      Process.waitpid( cs.pid )
    end
  end

end; end
