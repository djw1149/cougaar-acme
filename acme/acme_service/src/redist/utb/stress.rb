module UTB

class Stress
  attr_reader :plugin
  @isOn = false
  @level = ""
  
  def update_status
    if @isOn
      @plugin["/plugins/acme_host_jabber_service/status/add"].call(@plugin.properties["command"], @level.to_s)
    else
      @plugin["/plugins/acme_host_jabber_service/status/delete"].call(@plugin.properties["command"])
    end
  end

  def initialize(plugin)
    @plugin = plugin

    cmd = @plugin.properties["command"]
    desc = @plugin.properties["description"]

    @plugin["/plugins/acme_host_jabber_service/commands/#{cmd}/description"].data=desc + 
        " Param=setLevel(25),red,yellow,green,stop"

    @plugin["/plugins/acme_host_jabber_service/commands/#{cmd}"].set_proc do |msg,command|
      case command
        when "stop"
          stop()
          @isOn = false
          reply = "#{cmd} stop"
          update_status

        when "red"
          @level = @plugin.properties["red"]
          @isOn = true
          setLevel( @level )
          reply = "#{cmd} #{@level}"
          update_status

        when "yellow"
          @level = @plugin.properties["yellow"]
          @isOn = true
          setLevel( @level )
          reply = "#{cmd} #{@level}"
          update_status

        when "green"
          @level = @plugin.properties["green"]
          @isOn = true
          setLevel( @level )
          reply = "#{cmd} #{@level}"
          update_status

        when "info"
          reply = "Cmd: #{command()}\nDesc: #{description()}\n" +
                  "Active: #{@isOn}\n"
          if (@isOn)
            reply = reply + "Level: #{@level}"
          end 
        when /setLevel\((.*)\)/
          @level = $1
          @isOn = true
          reply = "#{cmd} #{@level}" 
          setLevel( @level )
          update_status

        else
          reply = "#{cmd} unknown-#{command}"
      end
      msg.reply.set_body(reply).send
    end
  end 
end

end



