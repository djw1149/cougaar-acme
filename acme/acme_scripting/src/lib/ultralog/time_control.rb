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


require 'parsedate'

module Cougaar
  module Actions
    class AdvanceTime < Cougaar::Action
      DOCUMENTATION = Cougaar.document {
        @description = "Advances the scenario time and sets the execution rate."
        @parameters = [
          {:time_to_advance => "default=1.day, seconds to advance the cougaar clock total."},
          {:time_step => "default=1.day, seconds to advance the cougaar clock each step."},
          {:wait_for_quiescence => "default=true, if false, will return without waiting for quiescence after final step."},
          {:execution_rate => "default=1.0, The new execution rate (1.0 = real time, 2.0 = 2X real time)"},
          {:timeout => "default=1.hour, Timeout for waiting for quiescence"},
          {:debug => "default=false, Set 'true' to debug action"}
        ]
        @example = "do_action 'AdvanceTime', 24.days, 1.day, true, 1.0, 1.hour, false"
      }

      def initialize(run, time_to_advance=1.day, time_step=1.day, wait_for_quiescence=true, execution_rate=1.0, timeout=1.hour, debug=false)
        super(run)
        @debug = debug
        @time_to_advance = time_to_advance
        @time_step = time_step
        @wait_for_quiescence = wait_for_quiescence
        @execution_rate = execution_rate
        @timeout = timeout
        @seconds_in_future_time_advance_occurs = 10
        @seconds_to_wait_for_reaction_to_time_advance = 5
        @scenario_time = /Scenario Time<\/td><td>([^<]*)<\/td>/
      end
      
      def perform
        # true => include the node agent
        @run.info_message "Advancing time: #{@time_to_advance/3600} hours Step: #{@time_step/3600} hours Rate: #{@execution_rate}" if @debug

        # We'll advance step by step, then by the remaining seconds
        steps_to_advance = (@time_to_advance / @time_step).floor
        seconds_to_advance = @time_to_advance % @time_step
        
        if @debug
          @run.info_message "Going to step forward #{steps_to_advance} steps and #{seconds_to_advance} seconds."
        end
        
        if @expected_start_time
          start_time = @expected_start_time
        else
          start_time = get_society_time
        end
        
        steps_to_advance.times do | step |
          if @debug
            @run.info_message "About to step forward one step (#{@time_step/3600} hours)"
          end
          if get_society_time > (start_time + (step + 1) * @time_step)
            @run.info_message "Skipping time step #{step+1}...society time #{get_society_time} is past #{start_time + (step+1)*@time_step}"
            next
          end
          unless advance_and_wait(@time_step)
            @run.error_message "Timed out advancing time...society not quiescent."
            return
          end
        end
        if seconds_to_advance > 0 && get_society_time < (start_time + (steps_to_advance * @time_step) + seconds_to_advance)
          if @debug
            @run.info_message "About to step forward #{seconds_to_advance} seconds"
          end
          unless advance_and_wait(seconds_to_advance)
            @run.error_message "Timed out advancing time...society not quiescent."
            return
          end
        end
      end
      
      def get_society_time
        nca_node = nil
        @run.society.each_agent do |agent|
          if (agent.has_facet?(:role) && agent.get_facet(:role) == "LogisticsCommanderInChief")
            nca_node = agent.node.agent
            break
          end
        end
        result, uri = Cougaar::Communications::HTTP.get(nca_node.uri+"/timeControl")
        md = @scenario_time.match(result)
        if md
          return Time.utc(*ParseDate.parsedate(md[1]))
        end
      end

      def advance_and_wait(time_in_seconds)
        result = true
        change_time = Time.now + @seconds_in_future_time_advance_occurs + 0.5 * @run.society.num_nodes  # add 20 sec + .5 sec per node
        request_start_time = Time.now

        threads=[]
              
        @run.society.each_node do |each_node|
          threads << Thread.new(each_node) do |node|
            next unless node.active?
            myuri = node.agent.uri+"/timeControl?timeAdvance=#{time_in_seconds*1000}&executionRate=#{@execution_rate}&changeTime=#{change_time.to_i * 1000}"
            @run.info_message "URI: #{myuri}\n" if @debug
            data, uri = Cougaar::Communications::HTTP.get(myuri)
            md = @scenario_time.match(data)
            if md
              @run.info_message "#{node.name} OLD TIME: #{md[1]}" if @debug
            else
              @run.error_message "ERROR Accessing timeControl Servlet at node #{node.name}.  Data was #{data}"
            end

            society_request_time = (change_time - Time.now).ceil
            if (society_request_time <= 0.0)
              @run.error_message "ERROR: #{node.name} did not receive Advance Time message before sync time (late by #{society_request_time})"
            end
          end
        end
         
        threads.each { |aThread|  aThread.join }

        if @debug
        #if true
          @run.info_message "Servlet requests took #{Time.now.to_i - request_start_time.to_i} seconds"
        end

        # make sure we don't progress until the time we've told the society to put the new time into effect
        sleep_time = (change_time - Time.now).ceil
        if (sleep_time > 0.0)
          if @debug
            @run.info_message "sleeping #{sleep_time.to_i} seconds"
          end
          sleep sleep_time
        end

        # now wait for quiescence
        if @wait_for_quiescence
          comp = @run["completion_monitor"]
          if !comp
            @run.error_message "Completion Monitor not installed.  Cannot wait for quiescence"
            return false
          end
          if @debug
            @run.info_message "About to wait for quiescence"
          end
          sleep @seconds_to_wait_for_reaction_to_time_advance.seconds

          if comp.getSocietyStatus() == "INCOMPLETE"
            result = comp.wait_for_change_to_state("COMPLETE", @timeout)
          end
        end

        @run.info_message "Society time advanced to #{get_society_time} in #{Time.now.to_i - request_start_time.to_i} seconds"
        return result
      end
    end # class
    
    class AdvanceTimeFrom < AdvanceTime
      DOCUMENTATION = Cougaar.document {
        @description = "Advances the scenario time and sets the execution rate."
        @parameters = [
          {:expected_start_time => "required, date that the society is assumed to be on (mm/dd/yy hh:mm:ss)"},
          {:time_to_advance => "default=1.day, seconds to advance the cougaar clock total."},
          {:time_to_advance => "default=1.day, seconds to advance the cougaar clock total."},
          {:time_step => "default=1.day, seconds to advance the cougaar clock each step."},
          {:wait_for_quiescence => "default=true, if false, will return without waiting for quiescence after final step."},
          {:execution_rate => "default=1.0, The new execution rate (1.0 = real time, 2.0 = 2X real time)"},
          {:timeout => "default=1.hour, Timeout for waiting for quiescence"},
          {:debug => "default=false, Set 'true' to debug action"}
        ]
        @example = "do_action 'AdvanceTimeFrom', '11/08/05', 24.days, 1.day, true, 1.0, 1.hour, false"
      }
      
      def initialize(run, expected_start_time, time_to_advance=1.day, time_step=1.day, wait_for_quiescence=true, execution_rate=1.0, timeout=1.hour, debug=false)
        @expected_start_time = Time.utc(*ParseDate.parsedate(expected_start_time))
        super(time_to_advance, time_step, wait_for_quiescence, execution_rate, timeout, debug)
      end
    end
  
  end
end