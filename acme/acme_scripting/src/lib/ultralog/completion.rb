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

require 'rexml/document'

module Cougaar
  module Actions
    class GetAgentCompletion < Cougaar::Action
      PRIOR_STATES = ["SocietyRunning"]
      DOCUMENTATION = Cougaar.document {
        @description = "Gets an individual agent's completion statistics."
        @parameters = [
          {:agent => "required, The name of the agent."}
        ]
        @block_yields = [
          {:stats => "The completion statistics object (UltraLog::Completion)."}
        ]
        @example = "
          do_action 'GetAgentCompletion', 'NCA' do |stats|
            puts stats
          end
        "
      }
      def initialize(run, agent_name, &block)
        super(run)
        @agent_name = agent_name
        @action = block
      end
      def perform
        @action.call(::UltraLog::Completion.status(@run.society.agents[@agent_name]))
      end
    end
  
    class SaveSocietyCompletion < Cougaar::Action
      PRIOR_STATES = ["SocietyRunning"]
      DOCUMENTATION = Cougaar.document {
        @description = "Gets all agent's completion statistics and writes them to a file."
        @parameters = [
          {:file => "required, The file name to write to."}
        ]
        @example = "do_action 'SaveSocietyCompletion', 'completion.xml'"
      }
      def initialize(run, file)
        super(run)
        @file = file
      end
      def perform
        agent_list = []
        total_tasks = 0 
        @run.society.each_agent {|agent| agent_list << agent.name}
        agent_list.sort!
        xml = "<CompletionSnapshot>\n"
        agent_list.each do |agent|
          begin
            stats = ::UltraLog::Completion.status(@run.society.agents[agent])
            if stats
              xml += stats.to_s
              total_tasks = total_tasks + stats.total
            else
              xml += "<SimpleCompletion agent='#{agent}' status='Error: Could not access agent.'\>\n"
              @run.error_message "Error accessing completion data for Agent #{agent}."
            end
          rescue
            xml += "<SimpleCompletion agent='#{agent}' status='Error: Parse exception.'\>\n"
            @run.error_message "Error parsing completion data for Agent #{agent}."
          end
        end
        xml += "<TotalSocietyTasks>" + total_tasks.to_s + "</TotalSocietyTasks>\n"
        xml += "</CompletionSnapshot>"
        save(xml)
      end
      def save(result)
        File.open(@file, "wb") do |file|
          file.puts result
        end
        @run.archive_and_remove_file(@file, "Society completion data.")
      end
    end

    class InstallCompletionMonitor < Cougaar::Action
      PRIOR_STATES = ["SocietyLoaded"]
      RESULTANT_STATE = "CompletionMonitorInstalled"
      DOCUMENTATION = Cougaar.document {
        @description = ""
        @parameters = []
        @example = " do_action 'InstallCompletionMonitor' "
      }
      def initialize(run, debug=false)
        super(run)
        @debug = debug
      end
      def perform
        @monitor = UltraLog::SocietyCompletionMonitor.new(run, @debug)
        run["completion_monitor"] = @monitor
      end
    end

  end  # Module Actions

  module States

    class CompletionMonitorInstalled < Cougaar::NOOPState
      DOCUMENTATION = Cougaar.document {
        @description = "Society quiescence is being actively monitored."
      }
    end
    
    class SocietyQuiesced < Cougaar::State
      DEFAULT_TIMEOUT = 60.minutes
      PRIOR_STATES = ["CompletionMonitorInstalled"]
      DOCUMENTATION = Cougaar.document {
        @description = "Waits for ACME to report that the society has quiesced ."
        @parameters = [
          {:timeout => "default=nil, Amount of time to wait in seconds."},
          {:block => "The timeout handler (unhandled: StopSociety, StopCommunications)"}
        ]
        @example = "
          wait_for 'SocietyQuiesced', 2.hours do
            puts 'Did not get Society Quiesced!!!'
            do_action 'StopSociety'
            do_action 'StopCommunications'
          end
        "
      }
      
      def initialize(run, timeout=nil, &block)
        super(run, timeout, &block)
      end
      
      def process
        comp = @run["completion_monitor"] 
	if (comp.getSocietyStatus() == "COMPLETE")
	  # Put this in the log file only...
#	  @run.info_message "Society is already quiescent. About to block waiting for society to go non-quiescent, then quiescent again...."
	  Cougaar.logger.info  "[#{Time.now}]      INFO: Society is already quiescent. About to block waiting for society to go non-quiescent, then quiescent again...."
	end
        comp.wait_for_change_to_state("COMPLETE")
      end
      
      def unhandled_timeout
        @run.do_action "StopSociety"
        @run.do_action "StopCommunications"
      end
    end

  end  # Module States
end

module UltraLog
  ##
  # The Completion class wraps access the data generated by the completion servlet
  #
  class Completion
  
    ##
    # Helper method that extracts the host and agent name to get completion for
    #
    # agent:: [Cougaar::Agent] The agent to get completion for
    # return:: [UltraLog::Completion::Statistics] The results of the query
    #
    def self.status(agent)
      data = Cougaar::Communications::HTTP.get("#{agent.uri}/completion?format=xml", 60)
      if data
        return Statistics.new(agent.name, data[0])
      else
        return nil
      end
    end
    
    ##
    # Gets completion statistics for a host/agent
    #
    # host:: [String] Host name
    # agent:: [String] Agent name
    # return:: [UltraLog::Completion::Statistics] The results of the query
    #
    def self.query(host, agent, port)
      data = Cougaar::Communications::HTTP.get("http://#{host}:#{port}/$#{agent}/completion?format=xml", 60)
      if data
        return Statistics.new(agent, data[0])
      else
        return nil
      end
    end
    
    ##
    # The statistics class holds the results of a completion query
    #
    class Statistics
      attr_reader :agent, :time, :total, :unplanned, :unestimated, :unconfident, :failed
      
      ##
      # Parses the supplied XML data into the statistics attributed
      #
      # data:: [String] A completion XML query
      #
      def initialize(agent, data)
        begin
          xml = REXML::Document.new(data)
        rescue REXML::ParseException
          raise "Could not construct Statistics object from supplied data."
        end
        root = xml.root
        @agent = agent
        @time = root.elements["TimeMillis"].text.to_i
        @ratio = root.elements["Ratio"].text.to_f
        @total = root.elements["NumTasks"].text.to_i
        @unplanned = root.elements["NumUnplannedTasks"].text.to_i
        @unestimated = root.elements["NumUnestimatedTasks"].text.to_i
        @unconfident = root.elements["NumUnconfidentTasks"].text.to_i
        @failed = root.elements["NumFailedTasks"].text.to_i
      end
      
      ##
      # Checks if agent is complete
      #
      # return:: [Boolean] true if unplanned and unestimated are zero, false otherwise
      #
      def complete?
        return (@unplanned==0 and @unestimated==0)
      end
      
      ##
      # Checks if agent has failed tasks
      #
      # return:: [Boolean] true if failed > 0, false otherwise
      #
      def failed?
        return (@failed > 0)
      end
      
      def to_s
        s =  "<SimpleCompletion agent='#{@agent}'>\n"
        s << "  <TimeMillis>#{@time}</TimeMillis>\n"
        s << "  <NumTasks>#{@total}</NumTasks>\n"
        if @total==0
          pct = 0
        else
          pct = (@total - @unplanned - @unestimated - @unconfident - @failed) * 100 / @total
        end
        s << "  <Ratio>#{@ratio}</Ratio>\n"
        s << "  <PercentComplete>#{pct}</PercentComplete>\n"
        s << "  <NumUnplannedTasks>#{@unplanned}</NumUnplannedTasks>\n"
        s << "  <NumUnestimatedTasks>#{@unestimated}</NumUnestimatedTasks>\n"
        s << "  <NumUnconfidentTasks>#{@unconfident}</NumUnconfidentTasks>\n"
        s << "  <NumFailedTasks>#{@failed}</NumFailedTasks>\n"
        s << "</SimpleCompletion>\n"
      end
      
    end

  end 

  class SocietyCompletionMonitor
    def initialize(run, debug)
      @run = run
      @debug = debug
      @society = run.society;
      @society_status = "INCOMPLETE"
      @run["completion_agent_status"] = {}
   	  @run.comms.on_cougaar_event do |event|
	      handleEvent(event) if (event.component == "QuiescenceReportServiceProvider")
	    end
    end

    def handleEvent(event)
      comp = @run["completion_agent_status"] 
      begin
        data = event.data.split(":")
        new_state = data[1].strip
        xml = REXML::Document.new(new_state)
      rescue Exception => failure
        ::Cougaar.logger.error "Exception: #{failure}"
        ::Cougaar.logger.error "Invalid xml Quiesence message in event: #{event}"
        puts "WARNING: Received bad event - more info in log file"
        return
      end
      root = xml.root
      node_name = root.attributes["name"]
      if root.attributes["quiescent"] == "true"
        root.each_element do |elem|
          agent_name = elem.attributes["name"]
          if agent_name != node_name
            comp[agent_name] = get_agent_data(elem, node_name)
          end
        end
      else
        node = @run.society.nodes[node_name]
        node.each_agent do |agent|
          comp[agent.name] = nil
        end
      end
      update_society_status()
    end

    def get_agent_data (data, node_name)
      agents = {}
      agents["receivers"] = get_messages(data.elements["receivers"], node_name)
      agents["senders"] = get_messages(data.elements["senders"], node_name)
      return agents
    end
      
    def get_messages (data, node_name)
      msgs = {}
      data.each_element do |elem|
        agent_name = elem.attributes["agent"]
        if agent_name != node_name
          msgs[agent_name] = elem.attributes["msgnum"]
        end
      end
      return msgs
    end

    def wait_for_change_to_state(wait_for_state)
      last_state = @society_status
      while true
        sleep 10
        if @society_status != last_state
          # We get some momentary state changes, make sure it stays changed
          sleep 10
          if @society_status != last_state
            last_state = @society_status
            if last_state == wait_for_state
              break
            end
          end
        end
      end
    end
      
    # Very verbose.  Only call if you really want to see this stuff
    def print_current_comp(comp)
      ::Cougaar.logger.info "*********************************************************"
      ::Cougaar.logger.info "PRINTING COMP INFO"
      ::Cougaar.logger.info "*********************************************************"
      comp.each_key do |agent|
        ::Cougaar.logger.info "Agent: #{agent}"
        info = comp[agent]
        next if !info
        ::Cougaar.logger.info "  Receivers:"
        print_messages(info["receivers"])
        ::Cougaar.logger.info "  Senders:"
        print_messages(info["senders"])
      end
    end

    def print_messages(msgs)
      msgs.each do |agent, msg|
        ::Cougaar.logger.info "    #{agent} => #{msg}"
      end
    end

    def update_society_status()
      comp = @run["completion_agent_status"] 
      soc_status = "COMPLETE"
      if @society.num_agents > comp.size
        soc_status = "INCOMPLETE"
        ::Cougaar.logger.info "Quiescence incomplete because not all agents have reported" if @debug
      else
        if soc_status != "INCOMPLETE"
          @society.each_agent do |agent|
            agentHash = comp[agent.name]
            if agentHash.nil?
              soc_status = "INCOMPLETE"
              ::Cougaar.logger.info "Quiescence incomplete because #{agent.name} is not quiescent" if @debug
              break
            end
            agentHash["receivers"].each do |destAgent, msg|
              if !(comp[destAgent])
                soc_status = "INCOMPLETE"
                ::Cougaar.logger.info "Quiescence incomplete because #{destAgent} is not quiescent" if @debug
                break
              elsif (destMsg = comp[destAgent]["senders"][agent.name]) && destMsg != msg
                soc_status = "INCOMPLETE"
                if @debug
                  ::Cougaar.logger.info "Quiescence incomplete because:" 
                  ::Cougaar.logger.info "   src message for #{agent.name} (#{destMsg}) != " 
                  ::Cougaar.logger.info "       dest message for #{destAgent} (#{msg})" 
                end
                break
              end
            end
            break if soc_status == "INCOMPLETE"

            agentHash["senders"].each do |srcAgent, msg|
              if !(comp[srcAgent])
                soc_status = "INCOMPLETE"
                ::Cougaar.logger.info "Quiescence incomplete because #{srcAgent} is not quiescent" if @debug
                break
              elsif (srcMsg = comp[srcAgent]["receivers"][agent.name]) && srcMsg != msg
                soc_status = "INCOMPLETE"
                if @debug
                  ::Cougaar.logger.info "Quiescence incomplete because:" 
                  ::Cougaar.logger.info "   dest message for #{agent.name} (#{srcMsg}) != " 
                  ::Cougaar.logger.info "       src message for #{srcAgent} (#{msg})" 
                end
                break
              end
            end
            break if soc_status == "INCOMPLETE"
          end
        end
      end
      unless @society_status == soc_status
        @society_status = soc_status
        puts "**** SOCIETY STATUS IS NOW: #{soc_status} ****"
        ::Cougaar.logger.info "**** SOCIETY STATUS IS NOW: #{soc_status} ****"
        print_current_comp(comp) if @debug
      end
    end
  
    def getSocietyStatus()
      return @society_status
    end
 
    def printIncomplete()
      line = "### Incomplete: " 
      comp = @run["completion_agent_status"] 
      comp.each do |agent, status|
        if status == "INCOMPLETE"
          line << "#{agent},"
        end
      end
      return line
    end

  end
end

