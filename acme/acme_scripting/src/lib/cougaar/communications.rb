##
#  <copyright>
#  Copyright 2002 InfoEther, LLC
#  under sponsorship of the Defense Advanced Research Projects Agency (DARPA).
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the Cougaar Open Source License as published by
#  DARPA on the Cougaar Open Source Website (www.cougaar.org).
#
#  THE COUGAAR SOFTWARE AND ANY DERIVATIVE SUPPLIED BY LICENSOR IS
#  PROVIDED 'AS IS' WITHOUT WARRANTIES OF ANY KIND, WHETHER EXPRESS OR
#  IMPLIED, INCLUDING (BUT NOT LIMITED TO) ALL IMPLIED WARRANTIES OF
#  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, AND WITHOUT
#  ANY WARRANTIES AS TO NON-INFRINGEMENT.  IN NO EVENT SHALL COPYRIGHT
#  HOLDER BE LIABLE FOR ANY DIRECT, SPECIAL, INDIRECT OR CONSEQUENTIAL
#  DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE OF DATA OR PROFITS,
#  TORTIOUS CONDUCT, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
#  PERFORMANCE OF THE COUGAAR SOFTWARE.
# </copyright>
#

require 'jabber4r/jabber4r'
require 'uri'
require 'net/http'
require 'rexml/document'
require 'jabber4r/rexml_1.8_patch'
require 'cougaar/curl'

module Cougaar

  module States
    class CommunicationsRunning < Cougaar::NOOPState
      DOCUMENTATION = Cougaar.document {
        @description = "Indicates that the Communications was started."
      }
    end
    
    class Command < Cougaar::State
      PRIOR_STATES = ["CommunicationsRunning"]
      DOCUMENTATION = Cougaar.document {
        @description = "Puts the script in a wait state to await an instant message to continue."
        @parameters = [
          {:command => "required, The string command to wait for."},
          {:timeout => "default=nil, Number of seconds to timeout."}
        ]
        @example = "wait_for 'Command', 'continue'"
      }
      def initialize(run, command, timeout=nil, &block)
        super(run, timeout, &block)
        @command = command
      end
      def to_s
        return super.to_s + "('#{@command}')"
      end
      def process
        @myThread = Thread.current
        id = @run.comms.acme_session.add_message_listener do |message|
          if message.body == @command
            @myThread.wakeup
          end
        end
        Thread.stop
        @run.comms.acme_session.delete_message_listener(id)
      end
      
      def on_interrupt
        @myThread.exit
        @run.comms.acme_session.delete_message_listener(id)
      end
      
    end
  end
  
  module Actions
  
    class StartJabberCommunications < Cougaar::Action
      PRIOR_STATES = ["SocietyLoaded"]
      RESULTANT_STATE = "CommunicationsRunning"
      DOCUMENTATION = Cougaar.document {
        @description = "Starts the Jabber communications subsystem and connects to the Jabber server."
        @parameters = [
          {:username => "default='acme_console', The username of the account used to control the experiment."},
          {:server => "default='acme', The Jabber server name."},
          {:pwd => "default='c0ns0le', The password for the Jabber account."}
        ]
        @example = "do_action 'StartJabberCommunications', 'acme_console', 'myjabberserver'"
      }
      def initialize(run, username="acme_console", server=nil, pwd="c0ns0le")
        super(run)
        @username = username
        @server = server
        @pwd = pwd
      end
      def to_s
        return super.to_s + "('#{@username}', '#{@server}', '#{@pwd}')"
      end
      def perform
        unless @server
          ohost = @run.society.get_service_host("jabber")
          if ohost==nil
            ohost = @run.society.get_service_host("Jabber")
          end
          if ohost==nil
            @run.info_message "Could not locate jabber service host (host with <facet service='jabber'/>)...defaulting to 'acme'"
            @server = 'acme'
          else
            @server = ohost.host_name
          end
        end
        @run.comms = Cougaar::Communications::JabberMessagingService.new(@run) do |jabber|
          jabber.username = @username
          jabber.password = @pwd
          jabber.jabber_server = @server
        end
        begin
          @run.comms.start
        rescue
          @run.error_message "Could not start Jabber Communications:\n#{$!}"
          @sequence.interrupt
        end
      end
    end
    
    class AddScriptCommand < Cougaar::Action
      DOCUMENTATION = Cougaar.document {
        @description = "Adds a command that can be invoked on the running script."
        @parameters = [
          {:command => "required, command name."},
          {:help => "optional, Help text returned in 'command[help]'."},
          {:block => "required |message, params| The block to process the command"}
        ]
        @example = "do_action 'AddScriptCommand', 'say_hello', 'Say howdy ho!' 
          {|message, params| message.reply.set_body('Howdy ho!').send}"
      }
      
      def initialize(run, command, help=nil, &block)
        super(run)
        @command = command
        @help = help
        @handler = block
      end
      
      def perform
        @run.comms.add_command(@command, @help, &@handler)
      end
      
    end
    
    class StopCommunications <  Cougaar::Action
      PRIOR_STATES = ["CommunicationsRunning"]
      DOCUMENTATION = Cougaar.document {
        @description = "Stops the current communications system."
        @example = "do_action 'StopCommunications'"
      }
      def perform
        @run.comms.stop if @run.comms
      end
    end
    
    class SetHTTPBasicAuth <  Cougaar::Action
      DOCUMENTATION = Cougaar.document {
        @description = "Sets the userid and password for basic HTTP authentication."
        @parameters = [
          {:username => "required, The username for basic HTTP authentication."},
          {:pwd => "required, The password for basic HTTP authentication."}
        ]
        @example = "do_action 'SetHTTPBasicAuth', 'rich', 'password'"
      }
      
      def initialize(run, username, pwd)
        super(run)
        @username = username
        @pwd = pwd
      end
      
      def perform
        ::Cougaar::Communications::HTTP.set_auth(@username, @pwd)
      end
    end
    
    class SetHTTPSCertificateFile <  Cougaar::Action
      DOCUMENTATION = Cougaar.document {
        @description = "Sets the certificate file and password for HTTPS authentication."
        @parameters = [
          {:file => "required, The certificate file (in .PEM format)."},
          {:pwd => "required, The password for basic HTTP authentication."}
        ]
        @example = "do_action 'SetHTTPSCertificateFile', 'my_cert.pem', 'password'"
      }
      
      def initialize(run, file, pwd)
        super(run)
        @file = file
        @pwd = pwd
      end
      
      def perform
        ::Cougaar::Communications::HTTP.set_cert(@file, @pwd)
      end
    end
    
    class VerifyHosts < Cougaar::Action
      PRIOR_STATES = ["CommunicationsRunning"]
      DOCUMENTATION = Cougaar.document {
        @description = "Verify the hosts used by an experiment by sending an communications message to each ACME Service."
        @example = "do_action 'VerifyHosts'"
      }
      def perform
        begin
          @run.comms.verify
        rescue
          @run.error_message "Could not verify Society: #{$!}"
          @sequence.interrupt
        end
      end
    end
  end
end


module Cougaar

  class CougaarEvent
    attr_accessor :node, :event_type, :cluster_identifier, :component, :data, :experiment
    def initialize
      yield self if block_given?
    end
    
    def to_s
      return "CougaarEvent - NODE=#{@node}, TYPE=#{@event_type}, CLUSTER=#{@cluster_identifier}, COMP=#{@component}, DATA=#{@data}"
    end
  end

  module Communications
  
    class Message
      attr_accessor :subject, :thread, :body
      def initialize(sender)
        @sender = sender
      end
      def set_subject(subject)
        @subject = subject
      end
      
      def set_body(body)
        @body = body
      end
      
      def request(ttl = nil, &block)
        send(true, ttl, &block)
      end
      
      def send(sync = false, ttl = nil)
        @sender.send(self, sync)
      end
      
      def reply
        m = Message.new(@sender)
        m.thread = @thread
        m
      end
    end
    
    class JabberMessagingService
      JABBER_RETRY_COUNT = 5
      JABBER_RETRY_DELAY = 5 # seconds
      attr_reader :acme_session, :pids, :local_hostname
      attr_writer :password
      attr_accessor :username, :jabber_server
      
      def initialize(run)
        @run = run
        @experiment = run.experiment
        yield self if block_given?
        @retry_count = JABBER_RETRY_COUNT unless @retry_count
        @event_listeners = {}
        @listener_count = 0
        @local_hostname = `hostname`.strip
        @resource_id = "expt-#{@local_hostname}-#{@run.name}"
      end
      
      def stop
        if @acme_session
          @acme_session.close
          @acme_session = nil
        end
      end
      
      def verify
        @run.society.each_active_host do |host|
          result = new_message(host).set_body("command[help]").request(10)
          if result.nil?
            raise "Could not access host: #{host.host_name}"
          end
        end
      end

      def start
        @retry_count.times do |i|
          begin
            @acme_session = Jabber::Session.bind_digest("#{@username}@#{@jabber_server}/#{@resource_id}", @password)
            @acme_session.on_session_failure do
              Cougaar.logger.error "Session to Jabber interrupted...preparing to retry connection"
              @acme_session.close
              @acme_session = nil
              start
            end
            # Listen for CougaarEvent messsages
            @acme_session.add_message_listener do |message|
              if message.subject=="COUGAAR_EVENT" && message.to.resource==@resource_id
                begin 
                  event = Cougaar::CougaarEvent.new
                  event.node, event.event_type, event.cluster_identifier, event.component, event.data = message.body.split("`")
                  event.data = event.data.unpack("m")[0].gsub(/\&amp\;/, '&').gsub(/\&lt\;/, "<").gsub(/\&quot\;/, '"').gsub(/\&gt\;/, ">")
                rescue Exception => exc
                  @run.error_message "Exception from bad event: #{exc}"
                  @run.error_message "    event was: #{event}"
                end
                @event_listeners.each_value do |listener| 
                  begin
                    listener.call(event)
                  rescue
                    @run.error_message "Exception in Cougaar Event listener: #{$!}"
                    @run.error_message "    for event: #{event}"
                  end
                end
              end
            end
            # Listen for command[cmd] messages
            add_command_listener
            return
          rescue
            Cougaar.logger.error "Cannot connect to Jabber...retrying #{JABBER_RETRY_COUNT-i+1} more time(s)\n#{$!}\n#{$!.backtrace}"
            sleep JABBER_RETRY_DELAY
          end
        end
        raise "Could not connect to Jabber server"
      end
      
      def add_command(command, help="No help available", &block)
        @commands[command] = block
        @command_help[command] = help
      end
      
      def remove_command(command)
        @commands.delete(command)
        @command_help.delete(command)
      end
      
      def add_command_listener
        @commands = {}
        @command_help = {}
        add_command("hostname", "Return hostname") do |message, params|
          message.reply.set_body(@local_hostname).send
        end
        add_command("script_content", "Return content of active script") do |message, params|
          message.reply.set_body([File.read($0)].pack("m")).send
        end
        add_command("script_name", "Return fill name of active script") do |message, params|
          message.reply.set_body(File.expand_path($0)).send
        end
        add_command("help", "Display this help list") do |message, params|
          result = "Command List:\n"
          @commands.keys.sort.each { |cmd| result << "command[#{cmd}] #{@command_help[cmd]}\n" }
          message.reply.set_body(result)
        end

        @acme_session.add_message_listener do |message|
          md = /command\[([^\]]*)\](.*)/.match(message.body)
          if md
            command = md[1]
            params = md[2]
            if @commands.has_key? command
              @commands[command].call(message, params)
            else
              message.reply.set_body("Unknown command [#{command}]").send
            end
          end
        end
      end
      
      def new_message(to)
        if to.kind_of?(Cougaar::Model::Host)
          to = "#{to.host_name}@#{@jabber_server}/acme"
        end
        @acme_session.new_chat_message(to)
      end
      
      ##
      # Register a block to process CougaarEvent objects
      #
      # block:: [Block] block to handle cougaar events |Cougaar::CougaarEvent|
      #
      def on_cougaar_event(&block)
        @listener_count += 1
        @event_listeners[@listener_count] = block
        @listener_count
      end
      
      def remove_on_cougaar_event(num)
        @event_listeners.delete(num)
      end
      
    end
  
    class HTTP
      @@user = "mbarger"
      @@password = "mbarger"
      
      @@certfile = nil
      @@certpassword = nil
      
      def self.set_auth(user, password)
        @@user = user
        @@password = password
      end
      
      def self.set_cert(file, password)
        @@certfile = file
        @@certpassword = password
      end
      
      def self.authenticate_request(request)
        request.basic_auth(@@user, @@password)
      end
    
      ##
      # Performs an HTTP get request and follows redirects.  This is
      # useful for Cougaar because all agent requests are redirected
      # to the host that the agent is on before returning data.
      #
      # uri:: [String] The uri (http://...)
      # return:: [String, URI] Returns the body of the http response and the URI of the final page returned
      #
      def self.get(uri, timeout=1800)
        return nil if uri.nil?
        return nil unless uri[0,4]=='http'
        return CURL.get(uri, @@user, @@password, @@certfile, @@certpassword, timeout) if uri[0,5]=='https'
        uri = URI.parse(uri)
        puts "HTTP GET: [#{uri.to_s}]" if $COUGAAR_DEBUG
	Cougaar.logger.info "[#{Time.now}]  HTTP GET: [#{uri.to_s}]" if $COUGAAR_DEBUG
        begin
          c = Net::HTTP.new(uri.host, uri.port)
          c.read_timeout = timeout
          path = uri.path
          path += "?" + uri.query if uri.query
          req = Net::HTTP::Get.new(path)
          authenticate_request(req)
          resp = c.request req
          return get(resp['location']) if resp.code=="302"
          puts "RESPONSE: [#{resp.body}]" if $COUGAAR_DEBUG
    	  Cougaar.logger.info "[#{Time.now}]  RESPONSE: [#{resp.body}]" if $COUGAAR_DEBUG
	  return resp.body, uri
        rescue
          puts "Cougaar::Util exception #{$!}"
    	  Cougaar.logger.error "[#{Time.now}]  Cougaar::Util exception #{$!}"
          return nil
        end    
      end
      
      ##
      # Performs an HTTP put request and returns the body of response.  Optionally
      # creates a REXML document is the URI returns XML data.
      #
      # uri:: [String] The URI to put to (http://...)
      # request:: [String] The data to put
      # format:: [Symbol=:as_string] Return format (:as_string or :as_xml)
      # return:: [String | REXML::Document] The body test returned as a String or XML document
      #
      def self.put(uri, data, format=:as_string)
        return CURL.put(uri, data, @@user, @@password, @@certfile, @@certpassword) if uri[0,5]=='https'
        uri = URI.parse(uri)
        c = Net::HTTP.new(uri.host, uri.port)
        c.read_timeout = 60*30 # per bill wright
        req_uri = uri.path
        req_uri = req_uri+"?"+uri.query if uri.query
        req = Net::HTTP::Put.new(req_uri)
        req.basic_auth(@@user, @@password)
        result = c.request(req, data)
        return nil unless result
        result = result.body
        return case format
        when :as_xml
          REXML::Document.parse(result)
        else
          result
        end
      end
      
      ##
      # Performs an HTTP post request and returns the body of response.  Optionally
      # creates a REXML document is the URI returns XML data.
      #
      # uri:: [String] The URI to put to (http://...)
      # request:: [String] The data to post
      # format:: [Symbol=:as_string] Return format (:as_string or :as_xml)
      # return:: [String | REXML::Document] The body test returned as a String or XML document
      #
      def self.post(uri, data, content_type="application/x-www-form-urlencoded")
        return CURL.post(uri, data, @@user, @@password, @@certfile, @@certpassword, content_type) if uri[0,5]=='https'
        uri = URI.parse(uri)
        c = Net::HTTP.new(uri.host, uri.port)
        c.read_timeout = 60*30 # per bill wright
        req_uri = uri.path
        req_uri = req_uri+"?"+uri.query if uri.query
        req = Net::HTTP::Post.new(req_uri, {"content-type"=>content_type})
        req.basic_auth(@@user, @@password)
        result = c.request(req, data)
        return nil unless result
        result = result.body
      end
    end
  end
end
