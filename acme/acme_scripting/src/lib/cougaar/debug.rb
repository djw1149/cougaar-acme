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
#
# NOTE: This file is loaded if the first param to start up a script 
# is DEBUG.  In this case, the classes/methods in this file override
# the default behavior of the scripts...allowing debugging of scripts
# without being connected to Cougaar.
#

puts "Debugging script --------------------------"
Thread.abort_on_exception=true

module Cougaar

  class MockJabberSession
    def initialize(server, controller)
      @controller = controller
      @controller.logger.debug "Connecting to the Jabber server at #{server}"
      @myThread = Thread.new {
        while(true)
          sleep 2
        end
      }
    end
    
    def close
      @myThread.kill
      @controller.logger.debug "Closing Jabber Session"
    end
    
  end
  
  class MockGLSConnection
    def initialize(controller)
      @controller = controller
      @controller.logger.debug "Connected to GLS servlet"
    end
    def finish
      @controller.logger.debug "GLS connection finished"
    end
    def close
      @controller.logger.debug "GLS connection closed"
    end
  end

  class Controller
    @@timer_factor = .01
    
    alias_method :orig_start_society, :start_society
    def start_society(thread_block=true)
      $DEBUG_CONTROLLER = self
      orig_start_society(false)        
      start_timers
      @run_thread = Thread.current
      Thread.new {
        sleep 2
        self.gls_connect
        self.ready_for_oplan
        sleep 3
        self.ready_for_gls
        sleep 3
        event = Cougaar::CougaarEvent.new
        event.node="FWD-C"
        event.event_type="STATUS"
        event.cluster_identifier="1-35-ARBN"
        event.component="AgentMsgRatePlugin"
        event.data="Added=23 Changed=5 Removed=50 MSG_RATE=850.0"
        self.inject_cougaar_event(event)
        sleep 3
        event = Cougaar::CougaarEvent.new
        event.node="REAR-E"
        event.event_type="STATUS"
        event.cluster_identifier="191-ORDBN"
        event.component="AgentMsgRatePlugin"
        event.data="Added=100 Changed=175 Removed=50 MSG_RATE=8001.0"
        self.inject_cougaar_event(event)
        
        self.planning_complete
      }
      Thread.stop
      $DEBUG_CONTROLLER = nil
      sleep 2
    end
    
    def connect_to_jabber(acme_server, retry_count = JABBER_RETRY_COUNT)
      @acme_server = acme_server
      @acme_session = MockJabberSession.new(acme_server, self)
    end
    
    def acme_command(host, cmd, *args)
      @logger.debug "Sending to #{host.host_name}*#{@acme_server}/acme: command[#{cmd}]#{args.join('')}" 
      case cmd
      when 'start_node'
        return "1234"
      when 'stop_node'
        return "SUCCESS"
      else
        return 'mock response'
      end
    end

    def inject_cougaar_event(event)
      @event_listeners.each {|listener| listener.call(event)}      
    end
    
    def gls_connect
      @logger.debug "GLS connect"
      @gls_connection = MockGLSConnection.new(self)
      @oplan_name="OplanName"
      @oplan_id="OplanID"
      @gls_connected = true
      @can_send_oplan = true
    end
    
  end
  
  class Util
    def Util.do_http_request(uri, *otherstuff)
      return uri
    end
    def Util.do_http_put(uri, *otherstuff)
      return uri
    end
    def Util.do_http_post(uri, *otherstuff)
      return uri
    end
  end
  
end

module UltraLog
  
  class FreezeControl
    def initialize(society)
      @society = society
      @controller = society.controller
    end
    
    def freeze
      @controller.logger.debug "Freezing society"
      return self
    end
    
    def thaw
      @controller.logger.debug "Thawing society"
      return self
    end
    
    def frozen?
      return true
    end
    
    def running?
      return true
    end
    
    def wait_until_frozen(maxtime=nil)
      @controller.logger.debug "Waiting until frozen"
      return self
    end
    
    def wait_until_running(maxtime=nil)
      @controller.logger.debug "Waiting until thawed"
      return self
    end
  end
  
  module Assessment
    class MockCnCrun
      def initialize(controller)
        @controller = controller
        @controller.logger.debug "New CnCstart run created"
        Thread.new {
          sleep 3
          event = Cougaar::CougaarEvent.new
          event.node="NCA-NODE"
          event.event_type="STATUS"
          event.cluster_identifier="NCA"
          event.component="CnCcalcPlugin"
          event.data="state=LOGGING_COMPLETE"
          @controller.inject_cougaar_event(event)
        }
      end
      def wait_for_completion
        @controller.logger.debug "CnCstart run waiting until completion"
      end
      def completed?
        @controller.logger.debug "CnCstart run check completion"
        return true
      end
    end
    
    class CnCcalc
      def CnCcalc.new_run(type, expt, desc)
        return "NewRun - type: #{type} expt: #{expt} desc: #{desc}"
      end
      
      def CnCcalc.start(society, use_jabber=false)
        return MockCnCrun.new(society.controller)
      end
    end
  end
  
  class DataGrabber
  
    def initialize(host, port=7000)
      @host = host
      @port = port
    end
    
    def new_run
      MockRun.new
    end
    
    class MockRun
      def id
        return 'debug'
      end
      def wait_for_completion
      end
    end
  end
  
  class Operator
    def initialize(host='u049')
      @service = Proc.new {|*param| puts "Calling operator: #{param.join(', ')}"}
      @baseName = Time.now.strftime('%y-%m-%d_%H_')
    end
  end
  
  class Topology
    def self.sync_society(current)
      puts "Sync'ed society"
    end
  end
  
  ##
  # The CompletionControl class wraps access the data generated by the completion servlet
  #
  class CompletionControl
    def initialize(host)
      @host = host
      yield self if block_given?
    end
    
    def update
      Thread.new {  
        sleep 3
        $DEBUG_CONTROLLER.planning_complete
      }
      params = get_params.join("&")
      puts "Updating completion control with #{params}"
      return "DEBUG CompletionControl: #{params}"
    end
  end

  class GLMStimulator
    @@updateThread = nil
    def initialize(agent, host)
      @agent = agent
      @host = host
      @inputFileName = ""
      @forPrep = ""
      @format = "html"
      yield self if block_given?
    end
    
    def update(format = nil)
      @format = format.to_s if format
      params = get_params
      result = "GLMStimulator: http://#{@host}:8800/$#{@agent}/stimulator?#{params.join('&')}"
      puts result
      unless @@updateThread
        @@updateThread = Thread.new {  
          sleep 3
          $DEBUG_CONTROLLER.planning_complete
          @@updateThread = nil
        }
      end
      result
    end
  end
  
  class Oplan
    def initialize(host)
      @host = host
    end
    
    def [](name)
      return MockOrganization.new(name)
    end
    
    def publish
      puts "Publishing new Oplan"
      Thread.new {  
        sleep 3
        $DEBUG_CONTROLLER.planning_complete
      }
    end
    
    class MockOrganization
      attr_reader :name
      def initialize(name)
        @name = name
      end
      def [](activity)
        return MockOrgActivity.new(self, activity)
      end
    end
    
    class MockOrgActivity
      def initialize(org, activity)
        @org = org
        @activity = activity
      end
      def save(op_tempo, start_offset, end_offset)
        puts "Oplan: Updating #{@org.name} with activity: #{@activity} optempo: #{op_tempo}, start: #{start_offset}, end: #{end_offset}"
      end
    end
  end
  
end
