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

module Cougaar
  module Actions
    
    class CleanupSociety < Cougaar::Action
      PRIOR_STATES = ["CommunicationsRunning"]
      DOCUMENTATION = Cougaar.document {
        @description = "Stop all Java processes and remove actives stressors on all hosts listed in the society."
        @example = "do_action 'CleanupSociety'"
      }
      
      def perform
        society = @run.society
        society = Ultralog::OperatorUtils::HostManager.new.load_society unless society
        
        society.each_service_host("acme") do |host|
          @run.info_message "Shutting down acme on #{host}\n" if @debug
          @run.comms.new_message(host).set_body("command[nic]reset").send
          @run.comms.new_message(host).set_body("command[rexec]killall -9 java").request(30)
          # kills don't always work first time, try again to be sure
          @run.comms.new_message(host).set_body("command[rexec]killall -9 java").request(30)
          @run.comms.new_message(host).set_body("command[cpu]0").send()
          @run.comms.new_message(host).set_body("command[shutdown]").send()
        end
 
        society.each_service_host("operator") do |host|
          @run.info_message "Shutting down acme on #{host}\n" if @debug
          @run.comms.new_message(host).set_body("command[nic]reset").send
          @run.comms.new_message(host).set_body("command[rexec]killall -9 java").request(30)
          # kills don't always work first time, try again to be sure
          @run.comms.new_message(host).set_body("command[rexec]killall -9 java").request(30)
          @run.comms.new_message(host).set_body("command[cpu]0").send()
        end         
        @run.info_message "Waiting for ACME services to restart"
	
        sleep 20 # wait for all acme servers to start back up
      end
    end  
  end
end