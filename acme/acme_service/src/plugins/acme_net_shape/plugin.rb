#!/usr/bin/ruby

#
# This script reads the XML file which defines the
# network, and will set up the Router to route
# between each VLAN.
#
require "rexml/document"
require "acme_net_shape/vlan.rb"

module ACME; module Plugins

class Shaper
  extend FreeBASE::StandardPlugin

  def self.start(plugin)
    plugin["instance"].data = Shaper.new( plugin )
    plugin['log/info'] << "ACME::Plugin::Shaper[start]"

    plugin.transition(FreeBASE::RUNNING)
  end

  def self.stop(plugin)
    plugin["instance"].data.reset()
    plugin['log/info'] << "ACME::Plugin::Shaper[stop]"

    plugin.transition(FreeBASE::LOADED)
  end

  attr_reader :plugin

  def initialize( plugin )
    super( )
    @plugin = plugin
#     @network = VlanSupport::Network.new( plugin.properties["config"] )

    cmd = @plugin.properties["command"]
    desc = @plugin.properties["description"]
 
    @plugin["/plugins/acme_host_communications/commands/#{cmd}/description"].data = desc
    @plugin["/plugins/acme_host_communications/commands/#{cmd}"].set_proc do |msg, cmd|
       case cmd
         # shape( interface, kbps ) - This method will shape the specified
         # interface.
         when /shape\((.*),(.*)\)/
           plugin['log/info'] << "Shaping interface #{$1} to #{$2}Kbps"
           do_shape( $1, $2 )

           reply = "Interface #{$1} shaped to #{$2}Kbps"

         # unshape( interface ) - This method removes shaping on the specified
         # interface
         when /unshape\((.*)\)/
           plugin['log/info'] << "Removing shaping on interface #{$1}"
           do_unshape( $1 )

           reply = "Interface #{$1} no longer shaped"

         # reset( interface ) - This method will completely reset an interface
         # so it is enabled/not shaped.
         when /reset\((.*)\)/
           plugin['log/info'] << "Resetting interface #{$1}"
           do_reset( $1 )

           reply = "Interface #{$1} reset"

         # enable( interface ) - This method will enable a network interface.
         when /enable\((.*)\)/
           plugin['log/info'] << "Enabling Interface #{$1}"
           do_enable( $1 )
           reply = "Enabled Interface #{$1}"

         # disable( interface ) - This method will disable a network interface.
         when /disable\((.*)\)/
           plugin['log/info'] << "Disabling Interface #{$1}"
           do_disable( $1 )
           reply = "Disabled Interface #{$1}"
         else 
           reply = "#{cmd} unknown-#{command}"
       end
       msg.reply.set_body( reply ).send
    end           
  end

  def do_shape( interface, bandwidth )
      `/sbin/tc qdisc add dev #{interface} root handle 1:0 tbf limit #{bandwidth}Kbit rate #{bandwidth} burst 5k`
  end 

  def do_unshape( interface )
      `/sbin/tc qdisc del root dev #{interface}`
  end

  def do_disable( interface )
      `/sbin/ifdown #{interface}`
  end

  def do_enable( interface )
      `/sbin/ifup #{interface}`
  end

  def do_reset( interface )
      do_enable( interface )
      do_unshape( interface )
  end
end

end; end
