=begin
 * <copyright>  
 *  Copyright 2001-2004 InfoEther LLC  
 *  Copyright 2001-2004 BBN Technologies
 *
 *  under sponsorship of the Defense Advanced Research Projects  
 *  Agency (DARPA).  
 *   
 *  You can redistribute this software and/or modify it under the 
 *  terms of the Cougaar Open Source License as published on the 
 *  Cougaar Open Source Website (www.cougaar.org <www.cougaar.org> ).   
 *   
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
 *  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
 *  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR 
 *  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT 
 *  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
 *  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT 
 *  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
 *  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY 
 *  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
 *  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
 *  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 * </copyright>  
=end

require 'cougaar/scripting'

module Cougaar
  module Actions
    # Set the log4j log level at runtime
    class SetLogging < Cougaar::Action
      DOCUMENTATION = Cougaar.document {
        @description = "Sets the Log4j log level of a component on a set of nodes."
        @parameters = [
          {:category => "Log4J category (package or class name usually, possibly root) for which to change the log level."},
          {:level => "New log level. One of DETAIL, DEBUG, INFO, WARN, ERROR, or SHOUT."},
          {:nodes => "*parameters, Name of node(s) in which to change the log level. If none specified, sets it on all nodes"}
        ]
        @example = "do_action 'SetLogging', 'org.cougaar.mlm.plugin.organization', 'INFO', 'OSD-NODE', 'REAR-A-NODE'"
      }

      def initialize(run, category, level, *nodes)
        super(run)
        @level = level
        @category = category
        @nodes = nodes
      end

      def perform
        log_nodes = Array.new
        if @nodes.nil? || @nodes.size == 0
          @run.society.each_node do |node|
            log_nodes << node
          end
        else
          @nodes.each do |node|
            log_nodes << @run.society.nodes[node]
          end
        end

        log_nodes.each do |node|
          node.override_parameter("-Dorg.cougaar.core.logging.log4j.category.#{@category}", "\"#{@level}\"")
        end
      end
    end

    class ChangeLogging < Cougaar::Action
      PRIOR_STATES = ["SocietyRunning"]
      DOCUMENTATION = Cougaar.document {
        @description = "Sets the Log4j log level of a component in one agent."
        @parameters = [
          {:agent => "default=All, Name of agent (or node) in which to change the log level."},
          {:category => "default=root, Log4J category (package or class name usually, possibly root) for which to change the log level."},
          {:level => "default=WARN, New log level. One of DETAIL, DEBUG, INFO, WARN, ERROR, or SHOUT."}
        ]
        @example = "do_action 'ChangeLogging', 'NCA', 'org.cougaar.mlm.plugin.organization', 'INFO'"
      }

      attr_accessor :agent, :category, :level

      def initialize(run, agent = "All", category = "root", level = "WARN")
        super(run)
          @level = level
          @category = category
          @agent = agent
      end

      def perform
        # Empty component means the root level
        if @category == nil || @category == "" || @category == "Root" || @category == "ROOT"
          @category = "root"
        end

        # Note that a typo in the category will not be noticed

        # Empty level makes no sense.
        if @level == nil || @level == ""
          @run.error_message "No log level given. Making no change."
          return
        end

        # Ensure a known log level is supplied. Note that the log servlet
        # notices such things later too. We could let it do it....
        unless @level == "DETAIL" || @level == "DEBUG" || @level == "INFO" || @level == "WARN" || @level == "ERROR" || @level == "SHOUT"
          @run.error_message "Unknown log level #{@level}. Making no change."
          return
        end

        if @agent == nil || @agent == "" || @agent == "ALL"
          @agent = "All"
        end

        # FIXME: allow agent == "All" to do all of the society
        if @agent == "All"
          @run.society.each_node do |node|
            do_agent node.name
          end
        else
          do_agent @agent
        end
      end

      # Process a single agent (node)
      def do_agent(one_agent)
        # FIXME: Do a transform_society for any reason?
        cougaar_agent = @run.society.agents[one_agent]

        # If didn't find it as an agent, try as a node
        unless cougaar_agent
          cougaar_agent = @run.society.nodes[one_agent]
        end
      
        if cougaar_agent
          list, uri = Cougaar::Communications::HTTP.get("#{cougaar_agent.uri}/list")
          if uri
            # Get the current level
            lev = process_return(get_level(uri, one_agent))
            if lev
              if lev == @level
                @run.info_message "Log level at #{one_agent} for #{@category} is already #{@level}."
                return
              else
                @run.info_message "Changing log level at #{one_agent} for #{@category} from #{lev} to #{@level}...."
              end
            else
              @run.error_message "Unable to get old log level at #{one_agent} for #{@category}..."
              # This indicates something really wrong, so just abort.
              return
            end
            # Now set the new level and check to see if the change went OK
            lev = process_return(set_level(uri, one_agent))
            unless lev
              @run.error_message " ..... FAILED log level change!"
              return
            end
	    
            if lev != @level
              @run.error_message " .... FAILED! Log level at #{lev} instead of #{@level}!"
            else
              @run.info_message " .... Succeeded."
            end
          else
            @run.error_message "ChangeLogging failed to redirect to agent: #{one_agent}"
          end
        else
          @run.error_message "ChangeLogging failed. Unknown agent: #{one_agent}"
        end
      end
      
      def get_level (uri, one_agent)
        return Cougaar::Communications::HTTP.get("#{uri.scheme}://#{uri.host}:#{uri.port}/$#{one_agent}/log?action=Get&getlog=#{@category}")
      end

      # Parse the log config servlet body. Return the log level or nil on error
      def process_return(resp)
        # 1 is cat, 2 is level
        #	@run.info_message " - Comparing #{resp}...."
        match = /.*Level for \"([^\"]*)\" is ([^ <]+)/.match(resp.to_s)
        if match
          cat, lev = match[1,2]
          if lev && lev != nil
            return lev
          end
        end

        # 1 is cat, 2 is failure reason
        match2 = /.*Unable to \S+ logging level of \"([^\"]*)\": ([^\n\r<]*)/.match(resp.to_s)
        if match2
          cat, err = match2[1,2]
          if err && err != nil
            @run.error_message "Error processing log level of #{cat}: #{err}"
            return nil
          end
        end
        
        match3 = /.*Set \"([^\"]*)\" to ([^ <]+)/.match(resp.to_s)
        if match3
          cat, lev = match3[1,2]
          if lev && lev != nil
            if lev == "null"
              @run.error_message "Error setting log level for #{cat}. Unknown log level."
              return nil
            else
              return lev
            end
          end
        end

        @run.error_message "No match processing log servlet return"
        return nil
      end

      def set_level (uri, one_agent)
        return Cougaar::Communications::HTTP.get("#{uri.scheme}://#{uri.host}:#{uri.port}/$#{one_agent}/log?action=Set&setlog=#{@category}&level=#{@level}")
      end
    end
  end
end
