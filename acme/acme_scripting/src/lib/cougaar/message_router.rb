require 'thread'
require 'socket'

Socket.do_not_reverse_lookup=true

module InfoEther
  module MessageRouter
  
    DEFAULT_PORT = 6667
    DEBUG = false
    if DEBUG
      Thread.abort_on_exception=true
    end

    class MessageQueue
    
      def initialize
        @q     = []
        @mutex = Mutex.new
        @cond  = ConditionVariable.new
      end
    
      def enqueue(*elems)
        @mutex.synchronize do
          @q.push *elems
          @cond.signal
        end
      end
    
      def dequeue()
        @mutex.synchronize do
          while @q.empty? do
            @cond.wait(@mutex)
          end
    
          return @q.shift
        end
      end
    
      def empty?()
        @mutex.synchronize do
          return @q.empty?
        end
      end
    end
  
    class SocketHandler
      attr_reader :handler, :socket
      
      def initialize(socket)
        @queue = MessageQueue.new
        @socket = socket
        send_messages
        receive_messages
        @thread_listeners = {}
        @listeners = []
      end
      
      def on_close(&block)
        @on_close = block
      end
      
      def add_listener(thread=nil, &listener)
        if thread
          @thread_listeners[thread] = listener
          return thread
        else
          @listeners << listener
          return listener
        end
      end
      
      def remove_listener(listener)
        @listeners.delete listener
        @thread_listeners.delete listener
      end
      
      def complete?
        return @queue.empty?
      end
      
      def notify_listeners(message)
        puts "RX: #{message}" if DEBUG
        if @thread_listeners.has_key?(message.thread)
          @thread_listeners[message.thread].call(message)
        else
          @listeners.each do |listener|
            listener.call(message)
          end
        end
      end

      def receive_messages
        @receive_thread = Thread.new {
          while(true)
            data = @socket.recv(8)
            if data.nil? || data.size==0
              @on_close.call(self) if @on_close
              stop
            end
            sizes = data.unpack("CCCCN")
            data += socket.recv(sizes[0]+sizes[1]+sizes[2]+sizes[3]+sizes[4])
            notify_listeners(Message.new(self, data))
          end
        }
      end
      
      def <<(message)
        @queue.enqueue(message)
      end
      
      def send_messages
        @send_thread = Thread.new {
          while(true)
            message = @queue.dequeue
            puts "TX: #{message}" if DEBUG
            @socket.send(message.encode, 0)
          end
        }
      end
      
      def stop
        @socket.close
        @send_thread.kill
        @receive_thread.kill
      end

    end
    
    class Client
    
      def initialize(name, service_host, service_port=DEFAULT_PORT)
        @name = name
        @service_host = service_host
        @service_port = service_port
        start
      end
      
      def start
        @socket_handler = SocketHandler.new(TCPSocket.new(@service_host, @service_port))
        reply = Message.new(@socket_handler).set_subject("connect").set_body(@name).request
        unless reply.body=="connected"
          raise "Connection error #{reply.body}"
        end
      end
      
      def add_message_listener(thread=nil, &block)
        @socket_handler.add_listener(thread, &block)
      end

      def remove_message_listener(id)
        @socket_handler.remove_listener(id)
      end
      
      def new_message(to)
        Message.new(@socket_handler) do |m|
          m.to = to
          m.from = @name
        end
      end
      
      def available_clients
        reply = new_message(nil).set_subject("list").request
        reply.body.split(',')
      end
      
      def stop
        @socket_handler.stop
      end
      
      def wait_until_done
        while(!@socket_handler.complete?) do
        end
      end
      
    end
    
    class SimpleFileLogger
      LEVELS = ['disabled', 'error', 'info', 'debug']
      def initialize(logName, logFile, logLevel)
        @logName = logName
        @logFile = logFile
        ensure_logdir
        self.logLevel = logLevel
        @file = File.new(logFile, "a")
        @file.sync = true
      end
      
      def ensure_logdir
        path = File.dirname(@logFile).split(File::SEPARATOR)
        (path.size-1).times do |i|
          dir = File.join(*path[0,i+2])
          unless File.exist?(dir)
            Dir.mkdir(dir)
          end
        end
      end
      
      def logLevel=(logLevel)
        logLevel = LEVELS[logLevel] if logLevel.kind_of? Numeric
        @logLevel = logLevel.downcase
        case @logLevel
        when 'disabled'
          @logLevelInt = 0
        when 'error'
          @logLevelInt = 1
        when 'info'
          @logLevelInt = 2
        when 'debug'
          @logLevelInt = 3
        else
          raise "Unknown Logger level: #{@logLevel}"
        end
      end
      
      def close
        @file.close
      end
      
      def time
        Time.now.strftime("%Y-%m-%d %H:%M:%S")
      end
      
      def error(message)
        return if @logLevelInt < 1
        @file.puts "#{time} :: [ERROR] #{message}"
      end
      
      def info(message)
        return if @logLevelInt < 2
        @file.puts "#{time} :: [INFO]  #{message}"
      end
      
      def debug(message)
        return if @logLevelInt < 3
        @file.puts "#{time} :: [DEBUG] #{message}"
      end

    end
  
    class Service
      attr_accessor :logger
      
      def initialize(port=DEFAULT_PORT)
        @port = port
        @handlers = {}
      end
      
      def start
        @server = TCPServer.new("0.0.0.0", @port)
        @thread = Thread.new do
          while(true)
            socket = @server.accept
            new_handler = SocketHandler.new(socket)
            new_handler.add_listener do |message|
              if message.to.nil? or message.to.size==0
                control_message(message)
              else
                route_message(message)
              end
            end
            # get rid of handler if already registered
            new_handler.on_close do
              client_id = nil
              @handlers.each do |id, handler|
                client_id = id if handler==new_handler
              end
              @logger.info "Client #{client_id} offline" if @logger
              @handlers.delete(client_id) if client_id
            end
          end
        end
      end
      
      def control_message(message)
        case message.subject
        when 'connect'
          @handlers[message.body] = message.socket_handler
          @logger.info  "Client #{message.body} online" if @logger
          message.reply.set_to(message.body).set_body("connected").send
        when 'list'
          @logger.debug "#{message.from} requested client list" if @logger
          message.reply.set_body(@handlers.keys.sort.join(',')).send
        end
      end
      
      def route_message(message)
        handler = @handlers[message.to]
        if handler
          handler << message
        else
          @logger.error "#{message.from} sent message to unknown client #{message.to}" if @logger
          message.reply.set_from(nil).set_subject("ERROR").set_body("Unknown client #{message.to}").send
        end
      end
      
      def stop
        @server.kill
      end
      
      def wait_until_done
        @thread.join
      end

    end
    
    class Message
      attr_accessor :socket_handler, :subject, :body, :to, :from, :thread
    
      @@thread_id = 0
      
      def self.next_thread
        @@thread_id += 1
        @@thread_id.to_s
      end
    
      DEFAULT_TIMEOUT = 5*60
      
      def initialize(socket_handler, data=nil)
        @socket_handler = socket_handler
        decode(data) if data
        yield self if block_given?
        @thread = Message.next_thread unless @thread
      end
      
      def set_subject(subject)
        @subject = subject
        self
      end
      
      def set_body(body)
        @body = body
        self
      end
      
      def set_to(to)
        @to = to
        self
      end
      
      def set_from(from)
        @from = from
        self
      end
      
      def request(timeout = DEFAULT_TIMEOUT)
        send(true, timeout)
      end
      
      def send(wait_for_reply=false, timeout = DEFAULT_TIMEOUT)
        if wait_for_reply
          reply = nil
          exec_thread = Thread.current
          listener = @socket_handler.add_listener(@thread) do |m|
            reply = m
            exec_thread.wakeup
          end
          @socket_handler << self
          Thread.stop
          @socket_handler.remove_listener(listener)
          return reply
        else
          @socket_handler << self
        end
      end
      
      def encode
        packstring = "CCCCNA#{@to.to_s.size}A#{@from.to_s.size}A#{@thread.to_s.size}A#{@subject.to_s.size}A#{@body.to_s.size}"
        [ @to.to_s.size, 
          @from.to_s.size,
          @thread.to_s.size,
          @subject.to_s.size,
          @body.to_s.size,
          @to, @from, @thread, @subject, @body ].pack(packstring)
      end
      
      def reply
        Message.new(@socket_handler) do |message|
          message.thread = @thread
          message.subject = @subject
          message.to = @from
          message.from = @to
        end
      end
      
      def decode(string)
        @to, @from, @thread, @subject, @body = 
          string[8..-1].unpack((string.unpack("CCCCN").collect {|i| 'A'+i.to_s}).join(''))
      end
      
      def to_s
        "from: #{@from}, to: #{@to}, thread: #{@thread}, subject: #{@subject}, body: #{@body}"
      end
      
    end
  end
end