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

$:.unshift ".." if $0 == __FILE__

require 'uri'
require 'net/http'

module Cougaar
  module Actions

    class FreezeSociety < Cougaar::Action
      PRIOR_STATES = ["SocietyRunning"]
      DOCUMENTATION = Cougaar.document {
        @description = "Freeze the society using the 2003 version of the Freeze servlet. This action blocks until the freeze is complete."
        @example = "do_action 'FreezeSociety'"
      }
      def initialize(run, timeout=nil, &block)
        super(run)
        @timeout = timeout
        @timeout = 3600 if @timeout.nil?
        @action = block if block_given?
      end
      def perform
        freezeControl = ::UltraLog::FreezeControl.new(@run.society)
        begin
          freezeControl.freeze
          freezeControl.wait_until_frozen(@timeout)
          @action.call(freezeControl) if @action
        rescue
          @run.error_message "Could not freeze society in #{@timeout} seconds"
        end
      end
   end

    class ThawSociety < Cougaar::Action
      PRIOR_STATES = ["SocietyRunning"]
      DOCUMENTATION = Cougaar.document {
        @description = "Thaw the society using the 2003 version of the Freeze servlet. This action blocks until the thaw is complete."
        @example = "do_action 'ThawSociety'"
      }
      def initialize(run, &block)
        super(run)
        @action = block if block_given?
      end
      def perform
        freezeControl = ::UltraLog::FreezeControl.new(@run.society)
        begin
          freezeControl.thaw
          freezeControl.wait_until_running
          @action.call(freezeControl) if @action
        rescue
          @run.error_message "Could not thaw society"
        end
      end

    end
  end
end

module UltraLog

  ##
  # Wraps the behavior of the UltraLog 2003 Freeze servlet exposing its
  # capabilities through a simple OO API:
  #
  #  Usage: 
  #  fc = UltraLog::FreezeControl.new(society)
  #  fc.freeze #Freeze the society
  #  fc.wait_until_frozen #Will not return until all agents are frozen
  #
  # This leaves the node agent(s) un-frozen.
  #
  class FreezeControl
    FREEZE_SERVLET = "/freezeControl"
    RUNNING = "running"
    FREEZING = "freezing"
    FROZEN = "frozen"
    THAWING = "thawing"
    INCONSISTENT = "inconsistent"
    
    
    
    ##
    # Constructs a FreezeControl instance, verifying existence of society.
    #
    # society:: [Cougaar::Model::Society] The society to be frozen
    #
    def initialize(society, debug=false)
      @debug = debug
      @society_state = RUNNING
      @agent_state = {}
      @society = society
      @society.each_agent do |agent|
        @agent_state[agent] = RUNNING
      end
    end
    
    ##
    # Issues a freeze command to the Cougaar society
    #
    # return:: [UltraLog::FreezeControl] Reference to 'self' for chaining
    #
    def freeze
      begin
        Cougaar::ExperimentMonitor.notify(Cougaar::ExperimentMonitor::InfoNotification.new("Freezing starts")) if @debug
        start = Time.now
        @society.each_agent do |agent|
          freeze_agent(agent)
        end
        done = Time.now
        Cougaar::ExperimentMonitor.notify(Cougaar::ExperimentMonitor::InfoNotification.new("Freezing initiated in #{done - start} seconds")) if @debug
      rescue
        Cougaar::ExperimentMonitor.notify(Cougaar::ExperimentMonitor::ErrorNotification.new("Warning...could not freeze: #{$!}"))
      end
      @society_state = FREEZING
      return self
    end
    
    ##
    # Issues a thaw command to the Cougaar society
    #
    # return:: [UltraLog::FreezeControl] Reference to 'self' for chaining
    #
    def thaw
      begin
        @society.each_agent do |agent|
          thaw_agent(agent)
        end
      rescue
        Cougaar::ExperimentMonitor.notify(Cougaar::ExperimentMonitor::ErrorNotification.new("Warning...could not thaw: #{$!}"))
      end
      @society_state = THAWING
      return self
    end
    
    ##
    # Checks if the society is frozen
    #
    # return:: [Boolean] true if society if frozen, otherwise false
    #
    def frozen?
      update_state()
      return @society_state == FROZEN
    end
    
    ##
    # Checks if the society is running
    #
    # return:: [Boolean] true if society if running, otherwise false
    #
    def running?
      update_state()
      return @society_state == RUNNING
    end
    
    ##
    # Polls up to (maxtime) seconds checking if the society is frozen
    #
    # maxtime:: [Integer=nil] Maximum poll time in seconds
    #
    def wait_until_frozen(maxtime=nil)
      count = 0
      until frozen?
        sleep 10 unless frozen?
        count += 10
        raise "Could not freeze society" if maxtime && count > maxtime
      end
      return self
    end
    
    ##
    # Polls up to (maxtime) seconds checking if the society is running
    #
    # maxtime:: [Integer=nil] Maximum poll time in seconds
    #
    def wait_until_running(maxtime=nil)
      count = 0
      until running?
        sleep 10 unless running?
        count += 10
        raise "Could not thaw society" if maxtime && count > maxtime
      end
      return self
    end

    ##
    # Freeze one agent
    #private
    def freeze_agent(agent)
      Cougaar::ExperimentMonitor.notify(Cougaar::ExperimentMonitor::InfoNotification.new("Telling agent #{agent.name} to freeze")) if @debug
      agent_uri = "#{agent.uri}#{FREEZE_SERVLET}?action=freeze"
      data, uri = Cougaar::Communications::HTTP.get(agent_uri)
      unless data && data.index("Freezing initiated")
        Cougaar::ExperimentMonitor.notify(Cougaar::ExperimentMonitor::ErrorNotification.new("Error freezing agent #{agent.name}.  Data recvd: #{data}"))
        # assume that it's frozen
        @agent_state[agent] = FROZEN 
        return
      end
      @agent_state[agent] = FREEZING
    end

    ##
    # Thaw one agent
    private
    def thaw_agent(agent)
      Cougaar::ExperimentMonitor.notify(Cougaar::ExperimentMonitor::InfoNotification.new("Telling agent #{agent.name} to thaw")) if @debug
      agent_uri = "#{agent.uri}#{FREEZE_SERVLET}?action=thaw"
      data, uri = Cougaar::Communications::HTTP.get(agent_uri)
      unless data && data.index("Thawing initiated")
        Cougaar::ExperimentMonitor.notify(Cougaar::ExperimentMonitor::ErrorNotification.new("Error freezing agent #{agent.name}.  Data recvd: #{data}"))
        # assume that it's thawed
        @agent_state[agent] = RUNNING
        return
      end
      @agent_state[agent] = THAWING
    end

    ##
    # Check one agent's state
    private
    def check_agent(agent)
      agent_uri = "#{agent.uri}#{FREEZE_SERVLET}"
      data, uri = Cougaar::Communications::HTTP.get(agent_uri)
      unless data 
        Cougaar::ExperimentMonitor.notify(Cougaar::ExperimentMonitor::ErrorNotification.new("Communications error contacting agent #{agent.name}."))
        raise "Could not check agent #{agent.name}" 
      end
      ret = RUNNING if data.index("Thawed")
      ret = FROZEN if data.index("Frozen")
      ret = FREEZING if data.index("Freezing")
      ret = THAWING if data.index("Thawing")
        Cougaar::ExperimentMonitor.notify(Cougaar::ExperimentMonitor::InfoNotification.new("Agent #{agent.name} is #{ret}")) if @debug
      unless ret 
        Cougaar::ExperimentMonitor.notify(Cougaar::ExperimentMonitor::ErrorNotification.new("Error checking agent #{agent.name}.  Data recvd: #{data}"))
        raise "Could not check agent #{agent.name}" 
      end
      @agent_state[agent] = ret
      return ret
    end

    ##
    # Poll all agents and update society state
    private 
    def update_state()
      expected_state = nil
      tmp_state = INCONSISTENT
      @society.each_agent do |agent|
        begin 
          check_agent(agent)

          # init expected_state to agent[0] state
          expected_state = @agent_state[agent] unless expected_state 

          # if this agent state != the first agent state, society is inconsistent
          unless expected_state == @agent_state[agent]
            tmp_state = INCONSISTENT
            break
          end

          tmp_state = @agent_state[agent]
        rescue
          Cougaar::ExperimentMonitor.notify(Cougaar::ExperimentMonitor::ErrorNotification.new("Warning...error checking freeze state for #{agent} : #{$!}"))
        end
      end
      Cougaar::ExperimentMonitor.notify(Cougaar::ExperimentMonitor::InfoNotification.new("**** Society state is #{tmp_state}")) if @debug
      @society_state = tmp_state
    end
  end
end
