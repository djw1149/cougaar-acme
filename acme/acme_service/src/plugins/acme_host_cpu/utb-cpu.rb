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
    @plugin["/plugins/acme_host_jabber_service/commands/cpu/description"].data = 
      "Start a CPU cycle waster at the given percentage load.  PARAM: %load (0 - 99)"
    @plugin["/plugins/acme_host_jabber_service/commands/cpu"].set_proc do |message, command| 
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
      @num_processors = ENV["NUMBER_OF_PROCESSORS"]
    end

    puts "CPU_WASTER PLATFORM IS #{@platform}.  #{@num_processors} processor(s)"
  end

  def get_waster()
    return @current_load
  end

  def set_waster(percent)
    perc = percent.to_f / 100.0
    stop()
    if ( perc >= 0.005 ) && (perc <= 0.90) then
      wholePie = 1000
      onTime = perc * wholePie
      offTime = (1 - perc) * wholePie
      @num_processors.times do |p| 
        @cmdline = "#{@cmd} #{onTime} #{offTime}"
        puts "Starting CPU stressor: #{@cmdline}"
        @PIDs << IO.popen("#{@cmdline}")
      end
      @current_load = perc
    end    
  end

  def stop()
    @PIDs.each do |p|
      puts "Killing CPU stressor: #{p.pid}"
      Process.kill(9, p.pid) if (p.pid)
      p.close
    end
    @PIDs = []
    @current_load = 0
  end

end
      
end ; end





