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

module UltraLog
  class GLSClient
    attr_reader :oplan_name, :oplan_id
    
    def can_send_oplan?
      @can_send_oplan
    end
    
    def gls_connected?
      @gls_connected
    end
    
    def close
      begin
        @gls_connection.finish
        @gls_thread.kill if @gls_thread
      rescue
        Cougaar.logger.error "Error shutting down gls connection: #{$!}"
      end
    end
    
    def initialize(run)
      @run = run
      @gls_connected = false
      @can_send_oplan = false
      @oplan_name = nil
      @oplan_id = nil
      
      @gls_connection = Net::HTTP.new(@run.society.agents['NCA'].node.host.host_name, @run.society.cougaar_port)
      @gls_thread = Thread.new do
        begin
          req = Net::HTTP::Get.new("/$NCA/glsreply?command=connect")
          Cougaar::Communications::HTTP.authenticate_request(req)
          @gls_connection.request(req) do |resp|
            resp.read_body do |data|
              case data.strip
              when /^<oplan name=.* id=[0-9A-F]*>/
                match = /^<oplan name=(.*) id=([0-9A-F]*)>/.match(data)
                @oplan_name = match[1]
                @oplan_id = match[2]
                @gls_connected = true
              when /^<GLS .*>/
                @can_send_oplan = true
              end
            end
          end
        rescue
          Cougaar.logger.error $!
          Cougaar.logger.error $!.backtrace.join("\n")
          Cougaar.logger.info "GLS Connection Closed"
        end
      end
    end
  end
end

module Cougaar  
  module States
  
    class OPlanReady < Cougaar::State
      DEFAULT_TIMEOUT = 30.minutes
      PRIOR_STATES = ["SocietyRunning"]
      def initialize(run, timeout=nil, &block)
        super(run, timeout, &block)
      end
      
      def process
        @reg = @run.comms.on_cougaar_event do |event| 
          if event.event_type=="STATUS" && event.cluster_identifier=="NCA" && event.component=="OPlanDetector"
            @run.comms.remove_on_cougaar_event(@reg)
            @currentThread.wakeup if @currentThread
          end
        end
        @currentThread = Thread.current
        Thread.stop
        gls_client = ::UltraLog::GLSClient.new(run)
        @run['gls_client'] = gls_client
        until gls_client.can_send_oplan?
          sleep 2
        end
      end
      
      def unhandled_timeout
        @run.do_action "StopSociety" 
        @run.do_action "StopCommunications"
      end
    end
    
    class GLSReady < Cougaar::State
      DEFAULT_TIMEOUT = 30.minutes
      PRIOR_STATES = ["OPlanSent"]
      
      def initialize(run, timeout=nil, &block)
        super(run, timeout, &block)
      end
      
      def process
        @reg = @run.comms.on_cougaar_event do |event| 
          if event.event_type=="STATUS" && event.cluster_identifier=="5-CORPS" && event.component=="OPlanDetector"
            @run.comms.remove_on_cougaar_event(@reg)
            @currentThread.wakeup if @currentThread
          end
        end
        @currentThread = Thread.current
        Thread.stop
        gls_client = @run['gls_client']
        until gls_client.gls_connected?
          sleep 2
        end
      end
      
      def unhandled_timeout
        @run.do_action "StopSociety"
        @run.do_action "StopCommunications"
      end
    end
    
    class PlanningComplete < Cougaar::State
      DEFAULT_TIMEOUT = 60.minutes
      PRIOR_STATES = ["SocietyPlanning"]
      
      def initialize(run, timeout=nil, &block)
        super(run, timeout, &block)
      end
      
      def process
        @reg = @run.comms.on_cougaar_event do |event| 
          if event.data.include?("Planning Complete")
            @run.comms.remove_on_cougaar_event(@reg)
            @currentThread.wakeup if @currentThread
          end
        end
        @currentThread = Thread.current
        Thread.stop
      end
      
      def unhandled_timeout
        @run.do_action "StopSociety"
        @run.do_action "StopCommunications"
      end
    end
    
    class OPlanSent < Cougaar::NOOPState
    end
    
    class SocietyPlanning < Cougaar::NOOPState
    end
      
  end
  
  module Actions
    class SendOPlan < Cougaar::Action
      PRIOR_STATES = ["OPlanReady"]
      RESULTANT_STATE = "OPlanSent"
      def perform
        begin
          result = Cougaar::Communications::HTTP.get("http://#{@run.society.agents['NCA'].node.host.host_name}:#{@run.society.cougaar_port}/$NCA/glsinit?command=sendoplan")
          raise_failure "Error sending OPlan" unless result
        rescue
          raise_failure "Could not send OPlan", $!
        end
      end
    end
    
    class PublishGLSRoot < Cougaar::Action
      PRIOR_STATES = ["GLSReady"]
      RESULTANT_STATE = "SocietyPlanning"
      def perform
        gls_client = @run['gls_client']
        begin
          result = Cougaar::Communications::HTTP.get("http://#{@run.society.agents['NCA'].node.host.host_name}:#{@run.society.cougaar_port}/$NCA/glsinit?command=publishgls&oplanID=#{gls_client.oplan_id}")
          raise_failure "Error publishing OPlan" unless result
        rescue
          raise_failure "Could not publish OPlan", $!
        ensure
          gls_client.close
        end
      end
    end
  end
end