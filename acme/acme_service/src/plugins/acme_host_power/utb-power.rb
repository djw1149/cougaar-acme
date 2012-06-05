=begin
 * <copyright>  
 *  Copyright 2001-2004 InfoEther LLC  
 *  Copyright 2001-2004 BBN Technologies
 *
 *  under sponsorship of the Defense Advanced Research Projects  
 *  Agency (DARPA).  
 *   
 *  You can redistribute this software and/or modify it under the 
 *  terms of the Cougaar Open Source License as published on the 
 *  Cougaar Open Source Website (www.cougaar.org <www.cougaar.org> ).   
 *   
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
 *  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
 *  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR 
 *  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT 
 *  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
 *  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT 
 *  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
 *  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY 
 *  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
 *  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
 *  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 * </copyright>  
=end

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


