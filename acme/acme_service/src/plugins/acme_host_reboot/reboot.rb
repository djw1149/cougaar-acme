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
