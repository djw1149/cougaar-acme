module ACME ; module Plugins

class Kickstart
  extend FreeBASE::StandardPlugin

  def Kickstart.start(plugin)
    Kickstart.new(plugin)
    plugin.transition(FreeBASE::RUNNING)
  end
  
  attr_reader :plugin
  def initialize(plugin)
    @plugin = plugin
    @plugin["/plugins/acme_host_jabber_service/commands/kickstart/description"].data=
      "Rebuilds machine.  Params: kickstartFile.cfg rebootTime"
    @plugin["/plugins/acme_host_jabber_service/commands/kickstart"].set_proc do |message, command| 
          file, minutes = command.split(" ")
          begin
            minutes = minutes.to_i
          rescue
            minutes = 0
          end
          message.reply.set_body("Kickstarting #{@hostname} in #{minutes} minutes").send
          `/mnt/software/Kickstart/Install/reinstall.sh -f -c #{command} -t #{minutes} &> /dev/null &`
          @plugin["/system/shutdown"].call(3)
    end
  end
end
      
end ; end
