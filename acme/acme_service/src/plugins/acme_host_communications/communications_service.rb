module ACME ; module Plugins 

class CommunicationsService
  extend FreeBASE::StandardPlugin

  def self.start(plugin)
    if plugin.properties["service_type"]=="router"
      require 'acme_host_communications/router_service'
      plugin["client"].data = RouterService.new(plugin)
    else # use Jabber
      require 'acme_host_communications/jabber_service'
      plugin["client"].data = JabberService.new(plugin)
    end
    plugin.transition(FreeBASE::RUNNING)
  end

  def self.stop(plugin)
    begin
      plugin["client"].data.disconnect
    rescue
    end
    plugin.transition(FreeBASE::LOADED)
  end
end

module CommandHandler
  def mount_commands
    @plugin["commands/shutdown/description"].data = "Shuts down ACME. Params: none"
    @plugin["commands/shutdown"].set_proc do |message, command|
        @plugin["/system/shutdown"].call(4)
        message.reply.set_body("ACME on #{@hostname} shutting down in 4 seconds").send
    end

    @plugin["commands/help/description"].data = "Display help info. Params: none"
    @plugin["commands/help"].set_proc do |message, command|
        base = @plugin["commands"]
        result = "\n"
        base.each_slot do |command_slot|
          command_slot.each_slot do |slot|
            if slot.name=="description"
              result << "command[#{command_slot.name}] - #{slot.data}\n"
            end
          end
        end
        message.reply.set_body(result).send
    end
  end
  
  def dispatch_command(message)
    if message.body[0..7]=="command["
      if closeBracket = message.body.index("]")
        command = message.body[8...closeBracket]
        @plugin['log/info'] << "Processing command #{message.body}"
        slot = @plugin["commands/#{command}"]
        if slot.is_proc_slot?
          begin
            slot.call(message, message.body[(closeBracket+1)..-1])
          rescue StandardError => error
            message.reply.set_body("Exception caught in executing: #{message.body}\n\n#{error}").send
          end
        else
          message.reply.set_body("Unregistered command: #{command}").send
        end
      else
        message.reply.set_body("Invalid command syntax: #{message.body}").send
      end
    else
      message.reply.set_body("Command format: command[name]params").send
    end
  end
end


end ; end 

