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

require 'uri'

module UltraLog
  class GLSClient
    attr_reader :oplan_name, :oplan_id, :c0_date, :next_stage
    
    def initialize(run)
      @run = run
      @gls_connected = false
      @can_get_oplan = false
      @oplan_name = nil
      @oplan_id = nil
      @c0_date=nil
      @next_stage = nil
      @next_stage_count = 0
      @stages = []
      connect
    end
    
    def connect(uri = nil)
      if uri.nil?
        @run.society.each_agent do |agent|
          if (agent.has_facet?(:role) && agent.get_facet(:role) == "LogisticsCommanderInChief")
            uri = agent.uri
            break
          end
        end
      end      

      uri = URI.parse(uri)
      @gls_connection = Net::HTTP.new(uri.host, uri.port)
      @gls_connection.read_timeout = 1000.hours # no reason for this to ever timeout
      @gls_thread = Thread.new do
        begin
          req = Net::HTTP::Get.new("/$NCA/glsreply?command=connect")
          Cougaar::Communications::HTTP.authenticate_request(req)
          @gls_connection.request(req) do |resp|
            #puts "#{resp.code} #{resp.message}"
            return connect(resp['location']) if resp.code=='302'
            @gls_connected = true
	    @run.info_message "Set gls_connected"
            resp.read_body do |data|
              #puts "DATA: #{CGI.escape(data)}"
              data.each_line do |line|
                @run.info_message "DATA: #{CGI.escape(line.strip)}" if $COUGAAR_DEBUG_GLS
                case line.strip
                when /^<oplan name=.* id=[0-9A-F]* c0_date=[0-9\/]* nextStage=.* stageDesc=.*>/
                  match = /^<oplan name=(.*) id=([0-9A-F]*) c0_date=([0-9\/]*) nextStage=(.*) stageDesc=.*>/.match(data)
                  @oplan_name = match[1]
                  @oplan_id = match[2]
                  @c0_date = match[3]
                  unless match[4]==@next_stage
                    @next_stage = match[4]
                    @stages << @next_stage
                  end
                when /^<oplan name=.* id=[0-9A-F]* c0_date=[0-9\/]* nextStage=.*>/
                  match = /^<oplan name=(.*) id=([0-9A-F]*) c0_date=([0-9\/]*) nextStage=(.*)>/.match(data)
                  @oplan_name = match[1]
                  @oplan_id = match[2]
                  @c0_date = match[3]
                  unless match[4]==@next_stage
                    @next_stage = match[4]
                    @stages << @next_stage
                  end
                end # end while block
#		@run.info_message "Finishing each_line block"
              end # end each_line handle

	      # Mark this after we've processed the return data to avoid
	      # threading issues
	      unless @can_get_oplan
		@can_get_oplan = true
		@run.info_message "Set can_get_oplan"
	      end

#	      @run.info_message "Finishing read_body block"
            end # end response.read_body block
	    # I believe we never get here!
          end # end req.resp
        rescue
          Cougaar.logger.error $!
          Cougaar.logger.error $!.backtrace.join("\n")
          Cougaar.logger.info "GLS Connection Closed"
        end
      end
    end
    
    def wait_for_next_stage
      @next_stage_count += 1
      Cougaar::ExperimentMonitor.notify(Cougaar::ExperimentMonitor::InfoNotification.new("Waiting for stage: #{@next_stage_count}" )) if $COUGAAR_DEBUG_GLS
      while @next_stage_count != @stages.size
        sleep 2
      end
    end
    
    def auto_publish_gls
      cmd_uri = nil
      @run.society.each_agent do |agent|
        if (agent.has_facet?(:role) && agent.get_facet(:role) == "LogisticsCommanderInChief")
          cmd_uri = agent.uri
          break
        end
      end

      result = Cougaar::Communications::HTTP.get("#{cmd_uri}/glsinit?command=publishgls&oplanID=#{@oplan_id}&c0_date=#{@c0_date}")
    end

    def can_get_oplan?
      @can_get_oplan
    end
    
    def gls_connected?
      @gls_connected
    end
    
    def close
      begin
        @gls_connection.finish
        @gls_thread.kill if @gls_thread
      rescue
        Cougaar.logger.error "Error shutting down gls connection"
        Cougaar.logger.error $!
        Cougaar.logger.error $!.backtrace.join("\n")
      end
    end

  end
end

module Cougaar  
  module States

    class GLSConnection < Cougaar::State
      DEFAULT_TIMEOUT = 30.minutes
      PRIOR_STATES = ["SocietyRunning"]
      DOCUMENTATION = Cougaar.document {
        @description = "Waits for the GLS connection."
        @parameters = [
          {:await_oplan => "default=true, true to await oplan cougaar event prior to connecting to GLS."},
          {:timeout => "default=nil, Amount of time to wait in seconds."},
          {:block => "The timeout handler (unhandled: StopSociety, StopCommunications"}
        ]
        @example = "
          wait_for 'GLSConnection' # connect immediately
            or
          wait_for 'GLSConnection', true # wait for OPlan event
        "
      }
      def initialize(run, await_oplan=true, timeout=nil, &block)
        super(run, timeout, &block)
        @await_oplan = await_oplan
      end
      
      def process
        if @await_oplan
# WARNING:  Calling "info_message" while Polaris is attached may cause
# GLS Client to die.
          @run.info_message "Waiting for OPlan Cougaar Event"
          loop = true
          while loop
            event = @run.get_next_event
            if event.event_type=="STATUS" && event.cluster_identifier=="NCA" && event.component=="OPlanDetector"
              loop = false
            end
          end
# WARNING:  Calling "info_message" while Polaris is attached may cause
# GLS Client to die.
	  @run.info_message "Got OPlan Cougaar Event"
        end

        gls_client = ::UltraLog::GLSClient.new(run)
        @run['gls_client'] = gls_client

	# Wait for the gls_client to get fully connected
# WARNING:  Calling "info_message" while Polaris is attached may cause
# GLS Client to die.
	@run.info_message "Waiting for can_get_oplan" unless gls_client.can_get_oplan?
	
        until gls_client.can_get_oplan?
          sleep 2
        end

	# On rehydrate we may already have the opinfo stuff, so
	# dont do it again
	if (gls_client.c0_date==nil)
# WARNING:  Calling "info_message" while Polaris is attached may cause
# GLS Client to die.
	  @run.info_message "Fetching Oplan from DB"
	  begin
            cmd_uri = nil
            @run.society.each_agent do |agent|
              if (agent.has_facet?(:role) && agent.get_facet(:role) == "LogisticsCommanderInChief")
                cmd_uri = agent.uri
                break
              end
            end

	    result = Cougaar::Communications::HTTP.get("#{cmd_uri}/glsinit?command=getopinfo")
	    @run.error_message "Error getting OPlan Info" unless result
	  rescue
	    @run.error_message  $!
	    @run.error_message  $!.backtrace.join
	  end
	else
	  @run.info_message "Rehydrated run with C0_date: #{gls_client.c0_date}"
	end
      end
      
      def unhandled_timeout
        @run.do_action "StopSociety" 
        @run.do_action "StopCommunications"
      end
    end
    
    class NextOPlanStage < Cougaar::State
      DEFAULT_TIMEOUT = 30.minutes
      PRIOR_STATES = ["SocietyRunning"]
      DOCUMENTATION = Cougaar.document {
        @description = "Waits for the OPlan stage."
        @parameters = [
          {:timeout => "default=nil, Amount of time to wait in seconds."},
          {:block => "The timeout handler (unhandled: StopSociety, StopCommunications"}
        ]
        @example = "
          wait_for 'NextOPlanStage'
        "
      }
      def initialize(run, timeout=nil, &block)
        super(run, timeout, &block)
      end
      
      def process
        gls_client = @run['gls_client']
        gls_client.wait_for_next_stage
      end
      
      def unhandled_timeout
        @run.do_action "StopSociety" 
        @run.do_action "StopCommunications"
      end
    end
    
    class SocietyPlanning < Cougaar::NOOPState
      DOCUMENTATION = Cougaar.document {
        @description = "Indicates that the society is planning."
      }
    end
      
  end
  
  module Actions
  
    class RehydrateSociety < Cougaar::Action
      PRIOR_STATES = ["SocietyRunning"]
      RESULTANT_STATE = "SocietyPlanning"
      DOCUMENTATION = Cougaar.document {
        @description = "This action is used in place of OPlan/GLS actions if you start a society from a persistent state."
        @example = "do_action 'RehydrateSociety'"
      }
      def perform
      end
    end

    class PublishNextStage < Cougaar::Action
      PRIOR_STATES = ["NextOPlanStage"]
      RESULTANT_STATE = "SocietyPlanning"
      DOCUMENTATION = Cougaar.document {
        @description = "Publishes the next stage of the GLS root task to the glsinit servlet."
        @example = "do_action 'PublishNextStage'"
      }
      
      def perform
        gls_client = @run['gls_client']
        begin
          cmd_uri = nil
          @run.society.each_agent do |agent|
            if (agent.has_facet?(:role) && agent.get_facet(:role) == "LogisticsCommanderInChief")
              cmd_uri = agent.uri
              break
            end
          end

          result = Cougaar::Communications::HTTP.get("#{cmd_uri}/glsinit?command=publishgls&oplanID=#{gls_client.oplan_id}&c0_date=#{gls_client.c0_date}")
          @run.error_message  "Error publishing next stage" unless result
        rescue
          @run.error_message "Could not publish next stage"
          @run.error_message  $!
          @run.error_message  $!.backtrace.join
        end
      end
    end
  end
end
