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

module Cougaar

  module States
    class CommunicationsRunning < Cougaar::NOOPState
    end
    
    class Command < Cougaar::State
      PRIOR_STATES = ["CommunicationsRunning"]
      def initialize(run, command, timeout=nil, &block)
        super(run, timeout, &block)
        @command = command
      end
      def to_s
        return super.to_s + "('#{@command}')"
      end
      def process
        myThread = Thread.current
        id = @run.comms.acme_session.add_message_listener do |message|
          if message.body == @command
            myThread.wakeup
          end
        end
        Thread.stop
        @run.comms.acme_session.delete_message_listener(id)
      end
    end
  end
  
  module Actions
  
    class StartJabberCommunications < Cougaar::Action
      PRIOR_STATES = ["SocietyLoaded"]
      RESULTANT_STATE = "CommunicationsRunning"
      def initialize(run, username="acme_console", server="acme", pwd="c0ns0le")
        super(run)
        @username = username
        @server = server
        @pwd = pwd
        @run.comms = Cougaar::Communications::JabberMessagingService.new(@run) do |jabber|
          jabber.username = username
          jabber.password = pwd
          jabber.jabber_server = server
        end
      end
      def to_s
        return super.to_s + "('#{@username}', '#{@server}', '#{@pwd}')"
      end
      def perform
        begin
          @run.comms.start
        rescue
          raise_failure "Could not start Jabber Communications", $!
        end
      end
    end
    
    class StopCommunications <  Cougaar::Action
      PRIOR_STATES = ["CommunicationsRunning"]
      def perform
        @run.comms.stop
      end
    end
    
    class VerifyHosts < Cougaar::Action
      PRIOR_STATES = ["CommunicationsRunning"]
      def perform
        begin
          @run.comms.verify
        rescue
          raise_failure "Could not verify society", $!
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
      attr_reader :acme_session, :pids
      attr_writer :password
      attr_accessor :username, :jabber_server
      
      def initialize(run)
        @run = run
        @experiment = run.experiment
        yield self if block_given?
        @retry_count = JABBER_RETRY_COUNT unless @retry_count
        @event_listeners = {}
        @listener_count = 0
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
            @acme_session = Jabber::Session.bind_digest("#{@username}@#{@jabber_server}/expt-#{@run.name}", @password)
            @acme_session.on_session_failure do
              Cougaar.logger.error "Session to Jabber interrupted...preparing to retry connection"
              @acme_session.close
              @acme_session = nil
              start
            end
            # Listen for CougaarEvent messsages
            @acme_session.add_message_listener do |message|
              if message.subject=="COUGAAR_EVENT"
                event = Cougaar::CougaarEvent.new
                event.node, event.event_type, event.cluster_identifier, event.component, event.data = message.body.split("\n")
                @event_listeners.each_value {|listener| listener.call(event)}
              end
            end
            return
          rescue
            Cougaar.logger.error "Cannot connect to Jabber...retrying #{JABBER_RETRY_COUNT-i+1} more time(s)\n#{$!}\n#{$!.backtrace}"
            sleep JABBER_RETRY_DELAY
          end
        end
        raise "Could not connect to Jabber server"
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
      
      def self.set_auth(user, password)
        @@user = user
        @@password = password
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
        uri = URI.parse(uri)
        begin
          c = Net::HTTP.new(uri.host, uri.port)
          c.read_timeout = timeout
          path = uri.path
          path += "?" + uri.query if uri.query
          req = Net::HTTP::Get.new(path)
          authenticate_request(req)
          resp = c.request req
          return get(resp['location']) if resp.code=="302"
          return resp.body, uri
        rescue
          puts "Cougaar::Util exception #{$!}"
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
