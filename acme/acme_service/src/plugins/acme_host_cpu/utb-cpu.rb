module ACME ; module Plugins

require "utb/stress.rb"

class CPU < UTB::Stress
  extend FreeBASE::StandardPlugin
  
  def self.load(plugin)
    begin
      require 'utb/UTB.rb'
      plugin.transition(FreeBASE::LOADED)
    rescue
      plugin.transition_failure
    end
  end
  
  def CPU.start(plugin)
    plugin["instance"].data = CPU.new(plugin)
    plugin.transition(FreeBASE::RUNNING)
  end
  
  def CPU.stop(plugin)
    plugin["instance"].data.stop()
    plugin.transition(FreeBASE::LOADED)
  end
  
  def initialize( plugin )
    @PID = -1
    super( plugin )
  end
  
  def stop()
    if (@PID > 0) then
      UTB.stop_cpu_sucker( @PID )
      @PID = -1
    end    
  end

  def setLevel( level )
    perc = level.to_f / 100.0
    stop()
    if ( perc >= 0.005 ) then
      wholePie = 100000
      onTime = perc * wholePie
      offTime = (1 - perc) * wholePie
      @PID = UTB.cpu_sucker_ruby( onTime, offTime )
    end    
  end
end
      
end ; end





