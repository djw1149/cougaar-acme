module ACME; module Plugins

  class RExec
    extend FreeBASE::StandardPlugin
    
    def RExec.start(plugin)
      RExec.new(plugin)
      plugin.transition(FreeBASE::RUNNING)
    end
    
    attr_reader :plugin
    def initialize(plugin)
      @plugin = plugin
      
      @plugin["/plugins/acme_host_jabber_service/commands/rexec/description"].data = 
        "Executes host command. Params: host_command"
      @plugin["/plugins/acme_host_jabber_service/commands/rexec"].set_proc do |message, command| 
        status = "\n"
        command = command.gsub(/\&quot;/, '"').gsub(/\&apos;/, "'")
        status << `#{command}`.gsub(/\&/, "&amp;").gsub(/\</, "&lt;")
        message.reply.set_body(status).send
      end
    end
  end
      
end ; end 
