module ACME ; module Plugins

require "utb/failure.rb"

class Power < UTB::Failure
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
    plugin["instance"].data = Power.new(plugin)
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
       UTB.power_off
       @isOn = true
     end
  end

  def reset()
    if (@isOn) then
      # This shouldn't ever get called, but it might. . .
      @isOn = false
    end
  end
  
end
      
end ; end


