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

module Cougaar
  module Actions
    class InitCnCCalcBaselineRun < Cougaar::Action
      RESULTANT_STATE = "CnCCalcInitialized"
      DOCUMENTATION = Cougaar.document {
        @description = "Initialize a baseline run entry in the CnCCalc database."
        @parameters = [
          {:desc => "required, The run description."}
        ]
        @example = "do_action 'InitCnCCalcBaselineRun', 'AL-398 base run'"
      }
      def initialize(run, desc=nil)
        @desc = desc
        @desc = @run.name unless @desc
      end
      def perform
        ::UltraLog::CnCcalc.new_run("base", @run.name, @desc)
      end
    end
    
    class InitCnCCalcStressRun < Cougaar::Action
      RESULTANT_STATE = "CnCCalcInitialized"
      DOCUMENTATION = Cougaar.document {
        @description = "Initialize a stress run entry in the CnCCalc database."
        @parameters = [
          {:desc => "required, The run description."}
        ]
        @example = "do_action 'InitCnCCalcStressRun', 'AL-398 stress run'"
      }
      def initialize(run, desc=nil)
        @desc = desc
        @desc = @run.name unless @desc
      end
      def perform
        ::UltraLog::CnCcalc.new_run("stress", @run.name, @desc)
      end
    end
    
    class RunCnCCalc < Cougaar::Action
      PRIOR_STATES = ["CnCCalcInitialized", "PlanningComplete"]
      RESULTANT_STATE = "CnCCalcRunning"
      DOCUMENTATION = Cougaar.document {
        @description = "Starts the CnCCalculator to collect data."
        @example = "do_action 'RunCnCCalc'"
      }
      def perform
        ##TODO
      end
    end
  end
  
  module States
    class CnCCalcInitialized < Cougaar::NOOPState
      DOCUMENTATION = Cougaar.document {
        @description = "Indicates that the CnCCalc run is initialized."
      }
    end
    
    class CnCCalcRunning < Cougaar::NOOPState
      DOCUMENTATION = Cougaar.document {
        @description = "Indicates that the CnCCalc is running."
      }
    end
    
    class CnCCalcComplete < Cougaar::State
      DEFAULT_TIMEOUT = 50.minutes
      PRIOR_STATES = ["CnCCalcRunning"]
      DOCUMENTATION = Cougaar.document {
        @description = "Wait until the CnCCalc run is complete."
      }
      def process
        ##TODO
      end
    end
  end
end

require 'cougaar/communications'
require 'xmlrpc/client'

module UltraLog
    
  ##
  # Wraps access to the CnCcalc mechanism.  There are two aspects
  # to CnCcalc, database (table) updates and Servlet invocation.  This
  # Class wraps both capabilities.
  #
  class CnCcalc
    TYPE_BASE = "base"
    TYPE_STRESS = "stress"
      
    ##
    # Static method to create a new run in the CnCcalc Postgres database
    #
    # type:: [TYPE_BASE | TYPE_STRESS] The type of run
    # expt:: [String] The name of the experiment
    # desc:: [String] The description of the experiment
    # return:: [String] The result of invoking the CnCcalc perl script
    #
    def self.new_run(type, expt, desc)
      service = XMLRPC::Client.new2("http://10.254.1.47:8989")
      service.set_parser(XMLRPC::XMLParser::REXMLStreamParser.new)
      return service.call('assessment.newrun', type, expt, desc) 
    end
    
    ##
    # Starts a CnCcalc run by invoking the servlets across all logistics agents
    #
    # society:: [Cougaar::Society] The society model to use to identify agents to invoke
    # use_jabber:: [Boolean=true] If set to true, this uses jabber to determine completness, otherwise it does not
    # return:: [Cougaar::Assessment::CnCcalc::CnCrun] The newly created run
    #
    def self.start(society, use_jabber=false)
      new_run = CnCrun.new(society)
      new_run.use_jabber if use_jabber
      society.each_agent do |agent|
        print agent.name+"  "
#          Cougaar.logger.info "#{agent.name}: "
        result, uri = Cougaar::Communications::HTTP.get("http://#{agent.host.host_name}:8800/$#{agent.name}/list")
        if result && result.include?("cnccalc")
          result2, uri2 = Cougaar::Communications::HTTP.get("http://#{agent.host.host_name}:8800/$#{agent.name}/cnccalc?command=start")
          #puts result2 if result2
#            Cougaar.logger.info "#{result2}" if result2
          if result2 && result2.include?("Received start<")
            new_run.total_started += 1 
          end
          sleep 3
#          else
#            Cougaar.logger.error "Could not access agent #{agent.name} on host #{agent.host.host_name}"
        end
      end
      print "\n"
      return new_run
    end
    
    ##
    # Encapsultes the behavior of pushing the execution of the CnC servlet
    #
    class CnCrun
      attr_reader :agents
      attr_accessor :total_started
      LOGGING = "state=LOGGING"
      WAITING_FOR_NEXT_RUN = "state=WAITING_FOR_NEXT_RUN"
      
      ##
      # Constructs a CnCrun object
      # 
      # society:: [Cougaar::Society] The society model to use to identify agents to invoke
      #
      def initialize(society)
        @agents = {}
        @wait_thread = nil
        @society = society
        @total_started = 0
        @use_jabber = false
      end
      
      ##
      # Monitors jabber events to determine completeness
      #
      def use_jabber
        @use_jabber = true
        @society.controller.on_cougaar_event do |event|
          if event.component == "CnCcalcPlugin"
            case event.data
            when LOGGING
              @agents[event.cluster_identifier]=LOGGING
            when WAITING_FOR_NEXT_RUN
              @agents.delete(event.cluster_identifier)
              if @agents.size == 0
                @wait_thread.wakeup if @wait_thread
              end
            end
          end
        end
      end
      
      ##
      # If jabber is used, blocks until completion CougaarEvent is received from all agents
      #
      def wait_for_completion
        raise "Cannot wait for completion unless jabber is used" unless use_jabber
        Thread.stop
      end
      
      ##
      # Returns whether the CnCcalc run has beed completed
      #
      # return:: [Boolean] True if the CnCcalc is complete, otherwise false
      #
      def completed?
        raise "Cannot check for completion unless jabber is used" unless use_jabber
        return (@agents.size==0)
      end
      
    end
  end

end


