module ACME ; module Plugins

require "utb/failure.rb"

class NIC < UTB::Failure
  extend FreeBASE::StandardPlugin
  
  def self.load(plugin)
    begin
      require 'utb/UTB.rb'
      plugin.transition(FreeBASE::LOADED)
    rescue
      plugin.transition_failure
    end
  end
  
  def self.start(plugin)
    plugin["instance"].data = NIC.new(plugin)
    plugin.transition(FreeBASE::RUNNING)
  end
  
  def self.stop(plugin)
    plugin["instance"].data.reset()
    plugin.transition(FreeBASE::LOADED)
  end
  
  attr_reader :plugin

  def initialize( plugin )
    super( plugin )
    @interface = @plugin.properties["interface"]
  end

  def trigger()
     if (!@isOn) then
      `ifdown eth0`
       #UTB.nic_close(@interface)
       @isOn = true
     end
  end

  def reset()
    if (@isOn) then
      `ifup eth0`
      #UTB.nic_open(@interface)
      @isOn = false
    end
  end
  
end
      
end ; end


