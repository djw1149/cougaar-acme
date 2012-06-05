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

module ACME; module Plugins

  class Reboot
  
    extend FreeBASE::StandardPlugin
    
    def Reboot.start(plugin)
      Reboot.new(plugin)
      plugin.transition(FreeBASE::RUNNING)
    end
  
    attr_reader :plugin
    def initialize(plugin)
      @plugin = plugin
      @plugin["/plugins/acme_host_jabber_service/commands/halt/description"].data =
        "Halt computer. Params: minutes"
      @plugin["/plugins/acme_host_jabber_service/commands/halt"].set_proc do |message, command|
          begin
            minutes = command.to_i
          rescue
            minutes = 0
          end
          message.reply.set_body("#{@hostname} halting in #{minutes} minutes").send
          `shutdown -h +#{minutes} &> /dev/null &`
          @plugin["/system/shutdown"].call(3)
      end
      @plugin["/plugins/acme_host_jabber_service/commands/reboot/description"].data =
        "Reboot computer. Params: minutes"
      @plugin["/plugins/acme_host_jabber_service/commands/reboot"].set_proc do |message, command|
          begin
            minutes = command.to_i
          rescue
            minutes = 0
          end
          message.reply.set_body("#{@hostname} rebooting in #{minutes} minutes").send
          `shutdown -r +#{minutes} &> /dev/null &`
          @plugin["/system/shutdown"].call(3)
      end
      
      
    end
  end
      
end ; end
