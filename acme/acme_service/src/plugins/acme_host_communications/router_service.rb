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
    unless @account
      @account = `hostname`.strip.downcase
    end
    start_service
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
    @client.add_message_listener do |message|
      dispatch_command(message) unless message.from.nil?
    end
  end
  
  def new_message(experiment)
    @client.new_message(experiment)
  end
  
  def disconnect
    @client.stop
    @server.stop
  end
end

end; end