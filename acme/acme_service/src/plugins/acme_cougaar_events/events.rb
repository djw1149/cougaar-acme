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
      @counter = {}
      @plugin["/plugins/acme_host_jabber_service/commands/event_count/description"].data = 
        "Returns number of events sent to an experiment. Params: experiment name"
      @plugin["/plugins/acme_host_jabber_service/commands/event_count"].set_proc do |message, command| 
        count = @counter[command]
        count = 0 unless count
        message.reply.set_body(count.to_s).send
      end
      @jabber = @plugin["/plugins/acme_host_jabber_service/session"]
      @plugin["instance"].data=self
      @plugin["event"].queue
      @plugin["event"].subscribe do |event, slot|
        if event == :notify_queue_join
          event = slot.leave
          count = @counter[event.experiment]
          count = 0 unless count
          count += 1
          #puts count
          @counter[event.experiment] = count
          message = @jabber.manager.new_chat_message("acme_console@#{@jabber.manager.host}/expt-#{event.experiment}")
          message.subject="COUGAAR_EVENT"
          message.body="#{event.node}\n#{event.event_type}\n#{event.cluster_identifier}\n#{event.component}\n#{event.data}"
          message.send
          parentNotified = true
        end
      end
      @service = Cougaar::CougaarEventService.new(5300)
      @service.start do |event|
        @plugin["event"] << event
      end
    end
    
    def stop
      @service.stop
    end
    
    
  end
      
end ; end
