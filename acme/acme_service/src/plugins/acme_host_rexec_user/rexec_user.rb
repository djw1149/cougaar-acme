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
