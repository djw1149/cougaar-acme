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

require 'uri'
require 'timeout'
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
        @example = "wait_for 'Command', 'continue' # waiting for command[continue]"
      }
      
      def initialize(run, command, timeout=nil, &block)
        super(run, timeout, &block)
        @command = command
      end
      
      def to_s
        return super.to_s + "('command[#{@command}]')"
      end
      
      def process
        @myThread = Thread.current
        @run.comms.add_command(@command, "wait_for: command[#{@command}]") do |message, params| 
          message.reply.set_body('Proceeding...').send
          @myThread.wakeup
        end
        Thread.stop
        @run.comms.remove_command(@command)
      end
      
      def on_interrupt
        @myThread.exit
        @run.comms.remove_command(@command)
      end

      def unhandled_timeout
        @run.do_action "StopSociety" if @sequence.index_of("StartSociety")
        @run.do_action "StopCommunications"
      end
            
    end
  end
  
  module Actions
  
    class StartCommunications < Cougaar::Action
      RESULTANT_STATE = "CommunicationsRunning"
      DOCUMENTATION = Cougaar.document {
        @description = "Starts either the jabber or message router communications subsystem."
        @example = "do_action 'StartCommunications'"
      }

      
      def perform
        society = @run.society
        society = Ultralog::OperatorUtils::HostManager.new.load_society unless society
        
        if society.get_service_host("message-router")
          @run.do_action "StartMessageRouterCommunications"
        else
          @run.do_action "StartJabberCommunications"
        end
        @run.add_to_interrupt_stack do 
          do_action "StopCommunications"
        end
      end
    end
  
    class StartMessageRouterCommunications < Cougaar::Action
      RESULTANT_STATE = "CommunicationsRunning"
      DOCUMENTATION = Cougaar.document {
        @description = "Starts the message router communications subsystem."
        @parameters = [
          {:server => "default=<message-router/jabber facet>, The message router server."},
          {:port => "default=<MessageRouter::DEFAULT_PORT>, The message router port."}
        ]
        @example = "do_action 'StartMessageRouterCommunications', 7777"
      }
      
      def initialize(run, server=nil, port=nil) 
        require 'cougaar/message_router'
        super(run)
        @server = server
        @port = port
      end
      
      def to_s
        return super.to_s + "(#{@server} #{@port})"
      end
      
      def perform
        unless @server
          society = @run.society
          society = Ultralog::OperatorUtils::HostManager.new.load_society unless society

          ohost = society.get_service_host("message-router")
          if ohost==nil
            ohost = society.get_service_host("jabber")
          end
          if ohost==nil
            @run.info_message "Could not locate message router service host (host with <facet service='message-router|jabber'/>)...defaulting to 'acme'"
            @server = 'acme'
          else
            @server = ohost.host_name
          end
        end
     
        @run.comms = Cougaar::Communications::MessageRouterClient.new(@run, @server, @port)
        begin
          @run.comms.start
        rescue
          @run.error_message "Could not connect to message router server: '#{@server}:#{@port}'"
          @sequence.interrupt
        end
      end
      
    end
  
    class StartJabberCommunications < Cougaar::Action
      RESULTANT_STATE = "CommunicationsRunning"
      DOCUMENTATION = Cougaar.document {
        @description = "Starts the Jabber communications subsystem and connects to the Jabber server."
        @parameters = [
          {:username => "default='acme_console', The username of the account used to control the experiment."},
          {:server => "default=<jabber facet or nil>, The Jabber server name."},
          {:pwd => "default='c0ns0le', The password for the Jabber account."}
        ]
        @example = "do_action 'StartJabberCommunications', 'acme_console', 'myjabberserver'"
      }
      
      JABBER_TIMEOUT = 5.minutes
      
      def initialize(run, username="acme_console", server=nil, pwd="c0ns0le")
        super(run)
        @username = username
        @server = server
        @pwd = pwd
        require 'jabber4r/jabber4r'
      end
      
      def to_s
        return super.to_s + "('#{@username}', '#{@server}', '#{@pwd}')"
      end
      
      def perform
        unless @server
          society = @run.society
          society = Ultralog::OperatorUtils::HostManager.new.load_society unless society

          ohost = society.get_service_host("jabber")
          if ohost==nil
            @run.info_message "Could not locate jabber service host (host with <facet service='jabber'/>)...defaulting to 'acme'"
            @server = 'acme'
          else
            @server = ohost.host_name
          end
        end
        @run.comms = Cougaar::Communications::JabberMessagingClient.new(@run) do |jabber|
          jabber.username = @username
          jabber.password = @pwd
          jabber.jabber_server = @server
        end
        begin
          timeout(JABBER_TIMEOUT) {
            @run.comms.start
          }
        rescue TimeoutError
          @run.error_message "Timed out connecting to Jabber."
          @sequence.interrupt
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
          
          society = @run.society
          society = Ultralog::OperatorUtils::HostManager.new.load_society unless society
         
          hosts = []
          society.each_service_host('acme') { |host| hosts << host }
          hosts.each_parallel do |host|
            test_ntp_synch(host)
          end 	  
          test_ntp_synch(society.get_service_host('operator'))
        rescue
          @run.error_message "Could not verify Society: #{$!}"
          @sequence.interrupt
        end
      end
      
      def test_ntp_synch(host)
        output = @run.comms.new_message(host).set_body("command[rexec_user]ntpstat").request(60)
        if (output.nil?) then
          @run.error_message "Request timed out verifying clock on #{host.name}"
        else 
          output = output.body
          output.chomp!
          if output.empty? then
            @run.error_message "ntpstat not installed on #{host.name}"
          elsif !(output =~ /^synch/) then
            @run.error_message "Clock on #{host.name} not synchronised with ntp server"
          end
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

    class MessagingClient
    
      attr_reader :local_hostname, :experiment_name
      
      def initialize(run)
        @run = run
        @experiment = run.experiment
        @event_listeners = {}
        @commands = {}
        @command_help = {}
        @listener_count = 0
        @local_hostname = `hostname`.strip
        @experiment_name = "#{@local_hostname}-#{@run.name}"
      end
      
      def verify
        society = @run.society
        society = Ultralog::OperatorUtils::HostManager.new.load_society unless society
        
        # check acme (node) hosts
        hosts = []
        society.each_service_host('acme') { |host| hosts << host }
        hosts.each_parallel do |host|
          result = new_message(host).set_body("command[help]").request(30)
          if result.nil?
            raise "Could not access host: #{host.host_name}"
          end
        end
        
        # check router (bandwidth shaping) hosts
        hosts = []
        society.each_host { |host| hosts << host }
        hosts.each_parallel do |host|
          if host.get_facet(:host_type) == "router"
            result = new_message(host).set_body("command[help]").request(30)
            if result.nil?
              raise "Could not access host: #{host.host_name}"
            end
          end
        end
      end
      
      def add_command(command, help="No help available", &block)
        @commands[command] = block
        @command_help[command] = help
      end
      
      def remove_command(command)
        @commands.delete(command)
        @command_help.delete(command)
      end
      
      def add_base_commands
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
          message.reply.set_body(result).send
        end
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
      
      def monitor_cougaar_events
        add_message_listener do |message|
          if message.subject=="COUGAAR_EVENT"
            if message.to.kind_of?(String) || message.to.resource==@resource_id
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
                rescue Exception => exc
                  @run.error_message "Exception in Cougaar Event listener: #{exc}"
                  @run.error_message "    for event: #{event}"
                end
              end
            end
          end 
        end
      end
      
      def monitor_commands
        add_message_listener do |message|
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
        raise "#{self.class} does not implement new_message"
      end

      def add_message_listener(message)
        raise "#{self.class} does not implement add_message_listener"
      end

    end
    
    class MessageRouterClient < MessagingClient
    
      def initialize(run, server, port=nil)
        super(run)
        @server = server
        @port = port ? port : InfoEther::MessageRouter::DEFAULT_PORT
      end
      
      def start
        @client = InfoEther::MessageRouter::Client.new(@experiment_name, @server, @port)
        @client.start_and_reconnect
        monitor_cougaar_events
        monitor_commands
      end
      
      def stop
        @client.stop
      end
      
      def add_message_listener(&block)
        @client.add_message_listener(&block)
      end
      
      def new_message(to)
        if to.kind_of?(Cougaar::Model::Host)
          to = to.host_name
        end
        @client.new_message(to)
      end 
      
    end
    
    class JabberMessagingClient < MessagingClient
      JABBER_RETRY_COUNT = 5
      JABBER_RETRY_DELAY = 5 # seconds
      attr_reader :acme_session, :pids
      attr_writer :password
      attr_accessor :username, :jabber_server
      
      def initialize(run)
        super(run)
        yield self if block_given?
        @retry_count = JABBER_RETRY_COUNT unless @retry_count
        @resource_id = "expt-#{@experiment_name}"
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
            monitor_cougaar_events # Listen for CougaarEvent messsages
            monitor_commands # Listen for command[cmd] messages
            return
          rescue
            Cougaar.logger.error "Cannot connect to Jabber...retrying #{JABBER_RETRY_COUNT-i+1} more time(s)\n#{$!}\n#{$!.backtrace}"
            sleep JABBER_RETRY_DELAY
          end
        end
        raise "Could not connect to Jabber server"
      end     
      
      def stop
        if @acme_session
          @acme_session.close
          @acme_session = nil
        end
      end
      
      def add_message_listener(&block)
        @acme_session.add_message_listener(&block)
      end
      
      def new_message(to)
        if to.kind_of?(Cougaar::Model::Host)
          to = "#{to.host_name}@#{@jabber_server}/acme"
        end
        @acme_session.new_chat_message(to)
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
	ExperimentMonitor.notify(ExperimentMonitor::InfoNotification.new("HTTP GET: [#{uri.to_s}]")) if $COUGAAR_DEBUG      
        begin
          c = Net::HTTP.new(uri.host, uri.port)
          c.read_timeout = timeout
          path = uri.path
          path += "?" + uri.query if uri.query
          req = Net::HTTP::Get.new(path)
          authenticate_request(req)
          resp = c.request req
          return get(resp['location']) if resp.code=="302"
	  ExperimentMonitor.notify(ExperimentMonitor::InfoNotification.new("RESPONSE: [#{resp.body}]")) if $COUGAAR_DEBUG      
	  return resp.body, uri
        rescue
	  ExperimentMonitor.notify(ExperimentMonitor::InfoNotification.new("Cougaar::Util exception #{$!}"))
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
