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

module ACME ; module Plugins

class CPU 
  extend FreeBASE::StandardPlugin
  
  def CPU.start(plugin)
    plugin["instance"].data = CPU.new(plugin)
    plugin.transition(FreeBASE::RUNNING)
  end
  
  def CPU.stop(plugin)
    plugin["instance"].data.stop()
    plugin.transition(FreeBASE::LOADED)
  end
  
  def initialize( plugin )
    @PIDs = []
    @plugin = plugin
    @current_load = 0
    @cmd = @plugin.properties['command']
    @plugin["/plugins/acme_host_communications/commands/cpu/description"].data = 
      "Start a CPU cycle waster at the given percentage load.  PARAM: %load (0 - 99)"
    @plugin["/plugins/acme_host_communications/commands/cpu"].set_proc do |message, command| 
      set_waster(command)
      message.reply.set_body("CPU Load set to #{get_waster()}").send
    end
    detect_processors()
  end

  def detect_processors()
    @platform = "windows"
    if File::PATH_SEPARATOR == ":"
      @platform = "unix"
    end

    if (@platform == "unix")
      @num_processors = `grep ^processor /proc/cpuinfo|wc -l`.to_i
    else 
      @num_processors = ENV["NUMBER_OF_PROCESSORS"].to_i
    end

    @plugin['log/info'] << "CPU_WASTER PLATFORM IS #{@platform}.  #{@num_processors} processor(s)"
  end

  def get_waster()
    return @current_load
  end

  def set_waster(percent)
    perc = percent.to_f / 100.0
    stop()
    if ( perc >= 0.005 ) && (perc <= 0.90) then
      wholePie = 100000
      wholePie = 1000 if (@platform == "windows")
      onTime = perc * wholePie
      offTime = (1 - perc) * wholePie
      @num_processors.times do |p| 
        @cmdline = "#{@cmd} #{onTime} #{offTime}"
        @plugin['log/info'] << "Starting CPU stressor: #{@cmdline}"
        @PIDs << IO.popen("#{@cmdline}")
      end
      @current_load = perc
    end    
  end

  def stop()
    @PIDs.each do |p|
      @plugin['log/info'] << "Killing CPU stressor: #{p.pid}"
      Process.kill(10, p.pid) if (p.pid)
      p.close
    end

    #`killall -9 #{@cmd}` if @platform == "unix"

    @PIDs = []
    @current_load = 0
  end

end
      
end ; end





