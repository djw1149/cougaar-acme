require 'cougaar/scripting'
require 'net/http'

module Cougaar
  module States

  class SanityCheck < Cougaar::State
    DOCUMENTATION = Cougaar.document {
      @description = "Verify that agents have completed a certain number of tasks."
    }

    def initialize(run, agent, tasks, timeout=nil, &block)
       super(run, timeout, &block)
       @agent = agent
       @tasks = tasks
    end

    def process
      host = @run.society.agents[@agent].node.host
      port = @run.society.agents[@agent].node.cougaar_port
      tasks = 0

      server = Net::HTTP.new( host.uri_name, port )
      resp, data = server.get("/$#{@agent}/completion?format=xml");
      doc = REXML::Document.new data
      doc.elements.each("SimpleCompletion/NumTasks") {
         |element|
         tasks = element.text.to_i         
      }

      @run.info_message "Checking #{@agent} for #{@tasks} tasks.  Found #{tasks}"
      if (tasks < @tasks) 
        handle_timeout
        @sequence.interrupt
      end
    end

    def unhandled_timeout
      @run.do_action "StopSociety"
      @run.do_action "StopCommunications"
    end
  end
  end
end
