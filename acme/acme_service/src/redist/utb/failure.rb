module UTB

class Failure
  attr_reader :plugin
  @isOn = false

  def update_status
    if @isOn
      @plugin["/plugins/acme_host_jabber_service/status/add"].call(@plugin.properties["command"], "off")
    else
      @plugin["/plugins/acme_host_jabber_service/status/delete"].call(@plugin.properties["command"])
    end
  end

  def initialize(plugin)
    @plugin = plugin
  
    cmd = @plugin.properties["command"]
    desc = @plugin.properties["description"]

    @plugin["/plugins/acme_host_jabber_service/commands/#{cmd}/description"].data=desc +
         " Param=trigger,reset"

    @plugin["/plugins/acme_host_jabber_service/commands/#{cmd}"].set_proc do |msg,command|
      case command
        when "reset"
          reset()
          @isOn = false
          reply = "#{cmd} reset"
          update_status
        when "trigger"
          trigger()
          @isOn = true
          reply = "#{cmd} trigger"
          update_status
        when "info"
          reply = "Cmd: #{command()}\nDesc: #{description()}\nActive: #{@isOn}"
        else
          reply = "#{cmd} unknown-#{command}"
      end
      msg.reply.set_body(reply).send
    end
  end
end

end
