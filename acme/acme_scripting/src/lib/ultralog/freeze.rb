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
        @description = "Freeze the society using the Freeze servlet."
        @example = "do_action 'FreezeSociety'"
      }
      def initialize(run, &block)
        super(run)
        @action = block if block_given?
      end
      def perform
        freezeControl = ::UltraLog::FreezeControl.new(@run.society)
        freezeControl.freeze
        @action.call(freezeControl) if @action
      end
    end
  end
end

module UltraLog

  ##
  # Wraps the behavior of the UltraLog Freeze servlet exposing its
  # capabilities through a simple OO API:
  #
  #  Usage: 
  #  fc = UltraLog::FreezeControl.new(society)
  #  fc.freeze #Freeze the society
  #  fc.wait_until_frozen #Will not return until all nodes report frozen
  #
  class FreezeControl
    FREEZE_SERVLET = "/$NCA/freezeControl"
    
    ##
    # Constructs a FreezeControl instance, verifying existence of society.
    #
    # society:: [Cougaar::Model::Society] The society which holds the NCA node
    #
    def initialize(society)
      nca = society.agents['NCA']
      data, uri = Cougaar::Communications::HTTP.get("http://#{nca.host.host_name}:#{society.cougaar_port}#{FREEZE_SERVLET}")
      raise "FreezeControl cannot access society" unless data
      @uri = uri
    end
    
    ##
    # Issues a freeze command to the Cougaar society
    #
    # return:: [UltraLog::FreezeControl] Reference to 'self' for chaining
    #
    def freeze
      return if frozen?
      return unless running?
      begin
      Net::HTTP.start( @uri.host, @uri.port ) do |http|
        response = http.post(FREEZE_SERVLET, "submit=Freeze")
      end
      rescue
        puts "Warning...could not freeze: #{$!}"
      end
      return self
    end
    
    ##
    # Issues a thaw command to the Cougaar society
    #
    # return:: [UltraLog::FreezeControl] Reference to 'self' for chaining
    #
    def thaw
      raise "Already running" if running?
      raise "Needs to be in the Frozen state to freeze" unless frozen?
      begin
      Net::HTTP.start( @uri.host, @uri.port ) do |http|
        response = http.post(FREEZE_SERVLET, "submit=Thaw")
      end
      rescue
        puts "Warning...could not thaw: #{$!}"
      end
      return self
    end
    
    ##
    # Checks if HTML response from Freeze servlet contains "Frozen", 
    # specifying that the society is frozen
    #
    # return:: [Boolean] true if society if frozen, otherwise false
    #
    def frozen?
      begin
      Net::HTTP.start( @uri.host, @uri.port ) do |http|
        response = http.post(FREEZE_SERVLET, "submit=Refresh")
        response = response[1]
        return false unless response.include? "Frozen"
        return true
      end
      rescue
        return false
      end
    end
    
    ##
    # Checks if HTML response from Freeze servlet contains "Running", 
    # specifying that the society is frozen
    #
    # return:: [Boolean] true if society if running, otherwise false
    #
    def running?
      begin
      Net::HTTP.start( @uri.host, @uri.port ) do |http|
        response = http.post(FREEZE_SERVLET, "submit=Refresh")
        response = response[1]
        return false unless response.include? "Running"
        return true
      end
      rescue
        return false
      end
    end
    
    ##
    # Polls up to (maxtime) seconds checking if the society is frozen
    #
    # maxtime:: [Integer=nil] Maximum poll time in seconds
    #
    def wait_until_frozen(maxtime=nil)
      count = 0
      until frozen?
        sleep 3
        count += 3
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
        sleep 3
        count += 3
        raise "Could not thaw society" if maxtime && count > maxtime
      end
      return self
    end
  end
end