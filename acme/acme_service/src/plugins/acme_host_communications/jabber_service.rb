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

require 'jabber4r/jabber4r'
require 'jabber4r/rexml_1.8_patch'
require 'socket'

module ACME ; module Plugins 

class JabberService
  include CommandHandler

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
  
  def new_message(experiment_name)
    @session.new_chat_message("acme_console@#{@host}/expt-#{experiment_name}")
  end

  def connect
    puts "Jabber service connecting to #{@account}@#{@host}/acme : #{@password}"
    @plugin.log_info << "Jabber service connecting to #{@account}@#{@host}/acme : #{@password}"
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

  def handle_messages
    listenerid = @session.add_message_listener do |message|
      unless message.type == "groupchat" or message.type == "error"
        dispatch_command(message)
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

