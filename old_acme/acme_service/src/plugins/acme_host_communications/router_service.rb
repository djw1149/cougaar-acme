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

require 'webrick'
require 'cougaar/message_router'

module ACME ; module Plugins 

class RouterService

  class PluginLogger
    def initialize(plugin)
      @plugin = plugin
    end
    
    def info(message)
      @plugin.log_info << message
    end
    
    def debug(message)
      @plugin.log_debug << message
    end
    
    def error(message)
      @plugin.log_error << message
    end
  end

  include CommandHandler
  attr_reader :plugin

  def initialize(plugin)
    @plugin = plugin
    @port = plugin.properties["port"] || InfoEther::MessageRouter::DEFAULT_PORT
    @account = @plugin.properties["account"]
    @host = @plugin.properties["host"]
    @start_router_service = @plugin.properties["start_router_service"]
    @start_router_service = true if @start_router_service.nil?
    unless @account
      if @host.strip.downcase == "localhost"
        @account = "localhost"
      else
        @account = `hostname`.strip.downcase
      end
    end
    start_service if @start_router_service
    start_client
    mount_commands
  end
  
  def start_service
    begin
      @service = InfoEther::MessageRouter::Service.new(@port)
      @service.logger = PluginLogger.new(@plugin)
      @service.start
      puts "Message Router Service started on port: #{@port}"
      @plugin.log_info << "Message Router Service started on port: #{@port}"
      sleep 1
    rescue
      puts "Message Router Service failed to start on port: #{@port}"
      @plugin.log_error << "Message Router Service failed to start on port: #{@port}"
    end
  end
  
  def start_client
    @client = InfoEther::MessageRouter::Client.new(@account, @host, @port)
    @client.start_and_reconnect
    @client.add_message_listener do |message|
      dispatch_command(message) unless message.from.nil?
    end
  end
  
  def new_message(experiment)
    @client.new_message(experiment)
  end
  
  def disconnect
    @client.stop
    @service.stop
  end
end

end; end
