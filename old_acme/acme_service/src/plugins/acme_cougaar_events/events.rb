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

require 'acme_cougaar_events/event_server'

module ACME; module Plugins
  
  class Events
    extend FreeBASE::StandardPlugin
    
    def Events.start(plugin)
      Events.new(plugin)
      plugin.transition(FreeBASE::RUNNING)
    end
    
    def Events.stop(plugin)
      instance = plugin["instance"].data.stop
      plugin.transition(FreeBASE::LOADED)
    end
    
    attr_reader :plugin
    
    def initialize(plugin)
      @plugin = plugin
      @comm_service =  @plugin["/plugins/acme_host_communications/client"].data

      @plugin["instance"].data=self
      @plugin["event"].queue
      @plugin["event"].subscribe do |event, slot|
        if event == :notify_queue_join
          event = slot.leave
          send_event(event)
          parentNotified = true
        end
      end

      @service = Cougaar::CougaarEventService.new(5300)
      @service.start do |event|
        send_event(event)
      end
    end
    
    def send_event(event)
      begin
        message = @comm_service.new_message(event.experiment)
        message.subject = "COUGAAR_EVENT"
        message.body = "#{event.node}`#{event.event_type}`#{event.cluster_identifier}`#{event.component}`#{event.data}"
        message.send
      rescue
        @plugin.log_info  << "Lost a CougaarEvent.  Failed talking to Jabber: #{message}"
      end
    end
    
    def stop
      @service.stop
    end
    
  end
      
end ; end

