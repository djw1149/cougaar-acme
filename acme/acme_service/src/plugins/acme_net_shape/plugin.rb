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
    @network = VlanSupport::Network.new( plugin.properties["config"] )

    cmd = @plugin.properties["command"]
    desc = @plugin.properties["description"]
 
    @plugin["/plugins/acme_host_jabber_service/commands/#{cmd}/description"].data = desc
    @plugin["/plugins/acme_host_jabber_service/commands/#{cmd}"].set_proc do |msg, cmd|
       case cmd
         when "trigger"
           trigger()
           reply = "OK"
         when "reset"
           reset()
           reply = "OK"
         when /shape\((.*),(.*),(.*)\)/
           do_shape( $1, $2, $3 )
           reply = "shaping from #{$1} to #{$2} at #{$3}Mbit"
         when /enable_link\((.*),(.*)\)/
           do_enable_link( $1, $2 )
           reply = "enabled link from #{$1} to #{$2}"
         when /disable_link\((.*),(.*)\)/
           do_disable_link( $1, $2 )
           reply = "disabled link from #{$1} to #{$2}"
         else 
           reply = "#{cmd} unknown-#{command}"
       end
       msg.reply.set_body( reply ).send
    end           
  end

  def do_shape( from_vlan, to_vlan, bandwidth )
    @network.shape( from_vlan, to_vlan, bandwidth )  
  end 

  def do_disable_link( from_vlan, to_vlan )
    @network.disable_link( from_vlan, to_vlan )
  end

  def do_enable_link( from_vlan, to_vlan )
    @network.enable_link( from_vlan, to_vlan )
  end

  def trigger
    plugin['log/info'] << "ACME::Plugin::Shaper[trigger]"
    if (!@isOn) then
      @isOn = true
      @network.do_shaping
    end
  end

  def reset
    plugin['log/info'] << "ACME::Plugin::Shaper[reset]"
    if (@isOn) then
      @isOn = false
      @network.stop_shaping
    end
  end
end

end; end
