#!/usr/bin/ruby

#
# This script reads the XML file which defines the
# network, and will set up the Router to route
# between each VLAN.
#
require "rexml/document"
require "utb/failure.rb"
require "vlan.rb"

module ACME; module Plugins

class Shaper < UTB::Failure
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
    super( plugin )
    @network = VlanSupport::Network.new( plugin.properties["config"] )
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
