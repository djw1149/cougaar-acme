=begin
 * <copyright>  
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

require "utb/stress.rb"

class MGEN 
  extend FreeBASE::StandardPlugin
    
  def self.load(plugin)
    begin
      plugin.transition(FreeBASE::LOADED)
    rescue LoadError
      plugin.transition_failure
    end
  end
  
  def MGEN.start(plugin)
    plugin["instance"].data = MGEN.new(plugin)
    plugin.transition(FreeBASE::RUNNING)
  end
  
  def MGEN.stop(plugin)
    plugin["instance"].data.stop()
    plugin.transition(FreeBASE::LOADED)
  end

  
  def initialize( plugin )
    @PID = -1
    super( )
    @plugin = plugin
    
    cmd = @plugin.properties["command"]
    desc = @plugin.properties["description"]

    @plugin["/plugins/acme_host_communications/commands/#{cmd}/description"].data = desc

    @plugin["/plugins/acme_host_communications/commands/mgen"].set_proc do |msg, cmd|
       case cmd
         when "stop"
           stop()
           @isOn = false
           reply = "mgen stop"

         when /go\((.*),(.*)\)/
           @isOn = true
           go( $1, $2 )
           reply = "mgen: #{@PID}"

         else
           reply = "#{cmd} unknown-#{command}"
       end
       msg.reply.set_body( reply ).send
     end
  end
  
  def stop()
    if (@PID > 0) then
      `killall -9 mgen`
      @PID = -1
    end    
  end

  def go( ip, rate )
    stop()
    @PID = fork {
      `/usr/local/bin/mgen -q -b #{ip}:5281 -r #{rate} -s 1024`
    }
  end    
end

end; end
