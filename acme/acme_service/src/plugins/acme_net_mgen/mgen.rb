
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

    @plugin["/plugins/acme_host_jabber_service/commands/#{cmd}/description"].data = desc

    @plugin["/plugins/acme_host_jabber_service/commands/mgen"].set_proc do |msg, cmd|
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
