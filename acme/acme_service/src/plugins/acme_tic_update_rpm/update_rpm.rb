module ACME ; module Plugins

class UpdateRPM
  extend FreeBASE::StandardPlugin

  def UpdateRPM.start(plugin)
    UpdateRPM.new(plugin)
    plugin.transition(FreeBASE::RUNNING)
  end
  
  attr_reader :plugin
  def initialize(plugin)
    @plugin = plugin
    @plugin["/plugins/acme_host_communications/commands/rpm/description"].data=
      "Reinstalls RPM.  Params: none"
    @plugin["/plugins/acme_host_communications/commands/rpm"].set_proc do |message, command| 
          exec "nohup /mnt/software/AcmeRPM/update_rpm_acme &>/dev/null &"
    end
  end
end
      
end ; end
