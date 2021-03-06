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

require 'socket'
require 'rexml/document'
require 'rexml/parsers/sax2parser'
require 'rexml/source'
require 'jabber4r/rexml_1.8_patch'

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
      puts "Cougaar Event Service started on port: #{@port}"
      server = TCPServer.new('0.0.0.0', @port)
      while(true)
        socket = server.accept
        handle_socket(socket)
      end
    end
    
    def handle_socket(socket)
      @threads << Thread.new do
        parser =  RegexpEventParser.new(socket, @proc)
        #parser =  RexmlEventParser.new(socket, @proc)
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
    
    class RegexpEventParser
      attr_reader :started
      
      def initialize(stream, listener)
        @stream = stream
        @listener = listener
      end
      
      def parse
        while data = @stream.gets('>')
          case data
          when /<CougaarEvents\s+Node="(.*)"\s+experiment="(.*)"\s*>/
            @node = $1
            @experiment = $2
          when /<CougaarEvent\s+type="(.*)"\s+clusterIdentifier="(.*)"\s+component="(.*)"\s*>/
            event = CougaarEvent.new
            event.node = @node
            event.experiment = @experiment
            event.event_type = $1
            event.cluster_identifier = $2
            event.component = $3
            event.data = [@stream.gets("</CougaarEvent>")[0..-16]].pack("m")
            @listener.call(event)
          end
        end
      end      
    end
    
    ##
    # The REXMLEventParser uses REXML to parse the incoming XML stream
    # of the Cougaar Events
    #
    class RexmlEventParser
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
      # Begins parsing the XML stream and does not return until
      # the stream closes.
      #
      def parse
        parser = REXML::Parsers::SAX2Parser.new @stream 
        parser.listen( :start_element ) do |uri, localname, qname, attributes|
          case qname
          when "CougaarEvents"
            @node = attributes['Node']
            @experiment = attributes['experiment']
            #puts "  Node: #{@node}  Experiment: #{@experiment}"
            @started = true
          when "CougaarEvent" 
            @current = CougaarEvent.new
            @current.node = @node
            @current.data = ""
            @current.experiment = @experiment
            @current.event_type = attributes['type']
            @current.cluster_identifier = attributes['clusterIdentifier']
            @current.component = attributes['component']
          else
            @current.data << "<#{qname}"
            attributes.each do |key, value| 
              @current.data << " #{key} = \"#{value}\""
            end
            @current.data << " >"
          end
        end
        parser.listen( :end_element ) do  |uri, localname, qname|
          case qname
          when "CougaarEvents"
            @node = nil
            @started = false
          when "CougaarEvent"
            @current.data = [@current.data].pack("m")
            @listener.call(@current)
            @current = nil
          else
            @current.data << "</#{qname}>"
          end
        end
        parser.listen( :characters ) do | text |
          @current.data << text if @current
        end
        parser.listen( :cdata ) do | text |
          @current.data << text if @current
        end
        parser.parse
      end
    end
    
  end
end

if $0==__FILE__
  parser =  Cougaar::CougaarEventService.new(3000)
  count = 0
  start = Time.now
  parser.start(false) do |event|
    if count == 999
      count = 0
      puts Time.now - start
    else
      start = Time.now if count == 0
      count += 1
    end
  end
end