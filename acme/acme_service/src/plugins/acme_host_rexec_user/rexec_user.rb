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

  class RExecUser
    extend FreeBASE::StandardPlugin
    
    def RExecUser.start(plugin)
      RExecUser.new(plugin)
      plugin.transition(FreeBASE::RUNNING)
    end
    
    attr_reader :plugin
    def initialize(plugin)
      @plugin = plugin
      @config_mgr = plugin['/cougaar/config'].manager      
      
      @plugin["/plugins/acme_host_communications/commands/rexec_user/description"].data = 
        "Executes host command as the acme_config user. Params: host_command"
      @plugin["/plugins/acme_host_communications/commands/rexec_user"].set_proc do |message, command| 
        command = command.gsub(/\&quot;/, '"').gsub(/\&apos;/, "'")
        command = @config_mgr.cmd_wrap(command)
        Thread.new {
          status = "\n"
          begin
            res = `#{command}`
            status << res.gsub(/\&/, "&amp;").gsub(/\</, "&lt;")
          rescue
            @plugin.log_error << "host_rexec_user failed to do #{command}"
            status << "#{command} failed"
          end
          message.reply.set_body(status).send
        }
      end
    end
  end
      
end ; end 
