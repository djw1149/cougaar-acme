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

require 'cgi'

module Cougaar
  module Actions
    class CompletionControl < Cougaar::Action
      PRIOR_STATES = ["SocietyRunning"]
      RESULTANT_STATE = 'SocietyPlanning'
      DOCUMENTATION = Cougaar.document {
        @description = "Adjusts the completion control (advancing clock, etc) for the running society."
        @block_yields = [
          {:cc => "The completion control object (UltraLog::CompletionControl)."}
        ]
        @example = "
          do_action 'CompletionControl' do |cc|
            cc.numberOfSteps = 2
            cc.update
          end
        "
      }
      def initialize(run, &block)
        super(run)
        @action = block
      end
      def perform
        @action.call(::UltraLog::CompletionControl.for_society(@run.society))
      end
    end
  end
end

module UltraLog

  ##
  # The CompletionControl class wraps access the data generated by the completion servlet
  #
  class CompletionControl
  
    attr_accessor :initialDelay, :normalDelay, :advanceDelay, :timeStep,
                  :numberOfSteps, :refreshInterval
                  
    attr_reader   :scenarioTime, :completionAction
  
    def initialize(host, port)
      @host = host
      @port = port
      query_defaults
      yield self if block_given?
    end
    
    def self.for_host(host, port)
      return self.new(host, port)
    end
    
    def self.for_society(society)
      return self.new(society.agents["NCA"].node.host.host_name, society.cougaar_port)
    end
    
    def update
      params = get_params.join("&")
      result = Cougaar::Communications::HTTP.post(@post_uri, params)
      result
    end
    
    def to_s
      get_params.join("\n")
    end
    
    private
    
    def get_params
      params = []
      params << "initialDelay=#{@initialDelay}"
      params << "normalDelay=#{@normalDelay}"
      params << "advanceDelay=#{@advanceDelay}"
      params << "timeStep=#{@timeStep}"
      params << "nSteps=#{@numberOfSteps}"
      params << "refreshInterval=#{@refreshInterval}"
      params << "submit=Submit"
      params
    end
    
    def query_defaults
      value = /value="(\w+)"/
      data, uri = Cougaar::Communications::HTTP.get("http://#{@host}:#{@port}/$NCA/completionControl", 300)
      # get the scenario time
      match = /Time<\/td><td>(.*)<\/td>/.match(data)
      @scenarioTime = match[1] if match
      # get completion action
      match = /GLS\)<\/td><td>(\w*)<\/td>/.match(data)
      @completionAction = match[1] if match
      @post_uri = uri.to_s
      values = data.scan(value)
      @initialDelay = values[0][0].to_i
      @normalDelay = values[1][0].to_i
      @advanceDelay = values[2][0].to_i
      @timeStep = values[3][0].to_i
      @numberOfSteps = values[4][0].to_i
      @refreshInterval = values[5][0].to_i
    end
    
  end
  
end

if $0==__FILE__
  cc = UltraLogCompletionControl.for_host("u192", 8800) #test code
  cc.numberOfSteps=2
  puts cc.update
end
