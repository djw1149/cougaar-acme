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

