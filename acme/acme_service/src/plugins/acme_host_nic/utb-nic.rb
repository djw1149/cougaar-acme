module ACME ; module Plugins

require "utb/failure.rb"

class NIC < UTB::Failure
  extend FreeBASE::StandardPlugin
  
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
      `ifdown #{@interface}`
       @isOn = true
     end
  end

  def reset()
    if (@isOn) then
      `ifup  #{@interface}`
      @isOn = false
    end
  end
  
end
      
end ; end


