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

require 'socket'
require 'rexml/document'
require 'rexml/streamlistener'

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
    
  class CougaarEventService
    attr_accessor :port, :proc
    
    def initialize(port=3000)
      @port = port
      @threads = []
    end
    
    def start(threaded=true, proc=nil, &block)
      proc = block if block_given?
      @proc = proc
      if threaded
        @mainthread = Thread.new {
          run
        }
      else
        run
      end
    end
    
    def run 
      puts "starting cougaar event service on port: #{@port}"
      server = TCPServer.new('0.0.0.0', @port)
      while(true)
        socket = server.accept
        handle_socket(socket)
      end
    end
    
    def handle_socket(socket)
      @threads << Thread.new do
        parser =  EventParser.new(socket, @proc)
        begin
          puts "got connection"
          parser.parse
          puts "closed connection"
        rescue REXML::ParseException
          puts "closed connection (parse exception)"
        rescue 
          puts "EventServer: Exception: #{$!}"
        ensure
          @threads.delete Thread.current
        end
      end
    end
    
    def stop
      Thread.kill(@mainthread) if @mainthread
      @threads.each {|thread| Thread.kill(thread)}
    end
    
    ##
    # The EventParser uses REXML to parse the incoming XML stream
    # of the Cougaar Events
    #
    class EventParser
      include REXML::StreamListener
      # status if the parser is started
      attr_reader :started
      
      ##
      # Constructs a parser for the supplied stream (socket input)
      #
      # stream:: [IO] Socket input stream
      # listener:: [Object.receive(ParsedXMLElement)] The listener (usually a Jabber::Protocol::Connection instance
      #
      def initialize(stream, listener)
        @stream = stream
        @listener = listener
        @current = nil
        @node=nil
      end
      
      ##
      # Callback for REXML::Document.parse_stream when a start tag is encountered
      #
      # name:: [String] The tag name <name>
      # attrs:: [Array] The attribute array...attrs = [["key","value"], ["key2", "value2"]]
      #
      def tag_start(name, attrs)
        case name
          when "CougaarEvents"
            attrs.each do |item| 
              puts "#{item[0]}='#{item[1]}'"
              @node=item[1] if item[0].downcase=='node'
              @experiment=item[1] if item[0].downcase=='experiment'
            end
            puts "  Node: #{@node}  Experiment: #{@experiment}"
            @started = true
          when "CougaarEvent" 
            @current = CougaarEvent.new
            @current.node = @node
            @current.experiment = @experiment
            @current.data = ""
            attrs.each do |item| 
              case item[0]
              when 'type'
                @current.event_type = item[1]
              when 'clusterIdentifier'
                @current.cluster_identifier = item[1]
              when 'component'
                @current.component = item[1]
              end
            end
           else
             @current.data << "<#{name}"
             attrs.each do |item| 
               @current.data << " #{item[0]} = \"#{item[1]}\""
             end
             @current.data << " >"
    
        end
      end
      
      ##
      # Callback for REXML::Document.parse_stream when an end tag is encountered
      #
      # name:: [String] the tag name
      #
      def tag_end(name)
        case name
          when "CougaarEvents"
            @node = nil
            @started = false
          when "CougaarEvent"
            @listener.call(@current)
            @current = nil
          else
            @current.data << "</#{name}>"
        end
      end
      
      ##
      # Callback for REXML::Document.parse_stream when text is encountered
      #
      # text:: [String] The text (<tag>text</tag>)
      #
      def text(text)
        @current.data << text if @current      
      end
      
      ##
      # Callback for REXML::Document.parse_stream when cdata is encountered
      #
      # content:: [String] The CData content
      #
      def cdata(content)
        @current.data << content if @current      
      end
      
      ##
      # Begins parsing the XML stream and does not return until
      # the stream closes.
      #
      def parse
        @started = false
        parser = REXML::Document.parse_stream(@stream, self)
      end
    end
    
  end
end


if $0==__FILE__

  class Foo
    def hey_now(bar)
      puts "HERE IT IS:"
      puts bar
    end
  end

  a_foo = Foo.new
  aproc = a_foo.method("hey_now")

  file = ARGV[0]
  f = File.new(file);
  parser =  Cougaar::CougaarEventService::EventParser.new(f, aproc)
  puts "got connection"
  parser.parse
  puts "closed connection"
end
