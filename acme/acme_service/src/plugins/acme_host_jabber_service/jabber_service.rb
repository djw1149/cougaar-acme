require 'jabber4r/jabber4r'
require 'jabber4r/rexml_1.8_patch'

require 'socket'



module ACME ; module Plugins 



class JabberService

  extend FreeBASE::StandardPlugin

  

  def JabberService.start(plugin)

    plugin["client"].data = JabberService.new(plugin)

    plugin.transition(FreeBASE::RUNNING)

  end

  

  def JabberService.stop(plugin)

    plugin["client"].data.disconnect

    plugin.transition(FreeBASE::LOADED)

  end

  

  attr_reader :plugin

  

  def initialize(plugin)

    @hostname = Socket.gethostname.downcase

    @plugin = plugin

    @status = {}

    puts "Jabber Service started"

    @account = @plugin.properties["account"]

    @host = @plugin.properties["host"]

    unless @account

      @account = Socket.gethostname.downcase

    end

    @password = @plugin.properties['password']

    @password ||= "#{@account}_password"

    verify_account(@account, @host)

    mount_commands

    @plugin["status/add"].set_proc do |key, value|

      @status[key]=value

      update_status

    end

    @plugin["status/delete"].set_proc do |key|

      @status.delete key

      update_status

    end

    connect

  end

  

  def connect

    puts "connecting to #{@account}@#{@host}/acme : #{@password}"

    @session = nil
    while not @session 
      begin
        @session = Jabber::Session.bind_digest("#{@account}@#{@host}/acme", @password)

        @session.on_session_failure do
          puts "Lost connection.  Will retry."
          sleep 10 
          connect
        end
        @plugin["session"].data=@session

        handle_subscriptions

        handle_messages

      rescue 
        #puts "OOPS! connection exception #{$!}"
        sleep 30
      end
    end
    puts "Send the chat message 'command[shutdown]' to #{@session.jid.to_s}."

  end

  

  def update_status

    statusList = []

    @status.each {|key, value| statusList << "#{key}: #{value}" }

    status = statusList.size==0 ? nil : statusList.join(", ")

    #@session.announce_normal status

  end

  

  def mount_commands

    @plugin["commands/shutdown/description"].data =

      "Shuts down ACME. Params: none"

    @plugin["commands/shutdown"].set_proc do |message, command|

        @plugin["/system/shutdown"].call(4)

        message.reply.set_body("ACME on #{@hostname} shutting down in 4 seconds").send

    end

    @plugin["commands/help/description"].data = "Display help info. Params: none"

    @plugin["commands/help"].set_proc do |message, command|

        base = @plugin["commands"]

        result = "\n"

        base.each_slot do |command_slot|

          command_slot.each_slot do |slot|

            if slot.name=="description"

              result << "command[#{command_slot.name}] - #{slot.data}\n"

            end

          end

        end

        message.reply.set_body(result).send

    end

  end

  

  def handle_messages

    listenerid = @session.add_message_listener do |message|

      unless message.type == "groupchat" or message.type == "error"

        if message.body[0..7]=="command["

          if closeBracket = message.body.index("]")

            command = message.body[8...closeBracket]

            @plugin['log/info'] << "Processing command #{message.body}"

            slot = @plugin["commands/#{command}"]

            if slot.is_proc_slot?

              begin

                slot.call(message, message.body[(closeBracket+1)..-1])

              rescue StandardError => error

                message.reply.set_body("Exception caught in executing: #{message.body}\n\n#{error}").send

              end

            else

              message.reply.set_body("Unregistered command: #{command}").send

            end

          else

            message.reply.set_body("Invalid command syntax: #{message.body}").send

          end

        else

          message.reply.set_body("Command format: command[name]params").send

        end

      end

    end

  end

  

  def handle_subscriptions

    @session.set_subscription_handler do |subscription|

      case subscription.type

      when :subscribe

        subscription.accept

      when :unsubscribe

        subscription.accept

      end

    end

  end



  def verify_account(account, host)

    t = Thread.current

    begin

      session = Jabber::Session.bind_digest("#{account}@#{host}/acme", @password)

    rescue

      begin 
        if Jabber::Session.register("#{account}@#{host}/acme", @password, "#{account}@#{host}", "host #{account}")

          session = Jabber::Session.bind_digest("#{account}@#{host}/acme", @password)

        else

          return false

        end
      rescue
        return false
      end

    end

    item = session.roster["acme_console@#{host}"]

    if item and (item.subscription == "from" or item.subscription == "both")

      puts "already registered"

      session.release

      return true

    end

    session.set_subscription_handler do |subscription|

      puts subscription.type

      if subscription.type==:subscribe

        puts "subscription request from #{subscription.from}"

        subscription.accept

        t.wakeup

      end

    end

    listenerid = session.add_message_listener do |message|

      puts message.body

      if message.body=="shutdown"

        t.wakeup

      end

    end

    puts "#{account} waiting..."

    session.new_chat_message("acme_console@#{host}/subscription_mgr").set_body("subscribe me").send

    puts "completed #{host}"

    sleep 2

    session.release

    return true

  end



  def disconnect

    @session.release

  end

end

      

end ; end 

