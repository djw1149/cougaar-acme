=begin
SOAP4R - SOAP XML Instance Parser library.
Copyright (C) 2001, 2003 NAKAMURA Hiroshi.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PRATICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 675 Mass
Ave, Cambridge, MA 02139, USA.
=end

require 'soap/soap'
require 'soap/charset'
require 'soap/baseData'
require 'soap/encodingStyleHandler'
require 'soap/namespace'


module SOAP


class SOAPParser
  include SOAP

  class ParseError < Error; end
  class FormatDecodeError < Error; end

  @@parserFactory = nil

  def self.factory
    @@parserFactory
  end

  def self.createParser( opt = {} )
    @@parserFactory.new( opt )
  end

  def self.setFactory( factory )
    if $DEBUG
      puts "Set #{ factory } as XML processor."
    end
    @@parserFactory = factory
  end

private
  class ParseFrame
    attr_reader :node
    attr_reader :ns, :encodingStyle

    class NodeContainer
      def initialize( node )
	@node = node
	@typeDef = nil
      end

      def node
	@node
      end

      def replaceNode( node )
	@node = node
      end
    end

  public

    def initialize( ns = nil, node = nil, encodingStyle = nil )
      @ns = ns
      self.node = node
      @encodingStyle = encodingStyle
    end

    def node=( node )
      @node = NodeContainer.new( node )
    end
  end

public

  attr_accessor :charset
  attr_accessor :defaultEncodingStyle
  attr_accessor :decodeComplexTypes
  attr_accessor :allowUnqualifiedElement

  def initialize( opt = {} )
    @parseStack = nil
    @lastNode = nil
    @handlers = {}
    @charset = opt[ :charset ] || 'us-ascii'
    @defaultEncodingStyle = opt[ :defaultEncodingStyle ] || EncodingNamespace
    @decodeComplexTypes = opt[ :decodeComplexTypes ] || nil
    @allowUnqualifiedElement = opt[ :allowUnqualifiedElement ] || false
  end

  def parse( stringOrReadable )
    @parseStack = []
    @lastNode = nil

    prologue
    @handlers.each do | uri, handler |
      handler.decodePrologue
    end

    doParse( stringOrReadable )

    unless @parseStack.empty?
      raise FormatDecodeError.new( "Unbalanced tag in XML." )
    end

    @handlers.each do | uri, handler |
      handler.decodeEpilogue
    end
    epilogue

    @lastNode
  end

  def doParse( stringOrReadable )
    raise NotImplementError.new( 'Method doParse must be defined in derived class.' )
  end

  def startElement( name, attrs )
    lastFrame = @parseStack.last
    ns = parent = parentEncodingStyle = nil
    if lastFrame
      ns = lastFrame.ns.clone
      parent = lastFrame.node
      parentEncodingStyle = lastFrame.encodingStyle
    else
      NS.reset
      ns = NS.new
      parent = ParseFrame::NodeContainer.new( nil )
      parentEncodingStyle = nil
    end

    parseNS( ns, attrs )
    encodingStyle = getEncodingStyle( ns, attrs )

    # Children's encodingStyle is derived from its parent.
    encodingStyle ||= parentEncodingStyle || @defaultEncodingStyle

    node = decodeTag( ns, name, attrs, parent, encodingStyle )

    @parseStack << ParseFrame.new( ns, node, encodingStyle )
  end

  def characters( text )
    lastFrame = @parseStack.last
    if lastFrame
      # Need not to be cloned because character does not have attr.
      ns = lastFrame.ns
      parent = lastFrame.node
      encodingStyle = lastFrame.encodingStyle
      decodeText( ns, text, encodingStyle )
    else
      # Ignore Text outside of SOAP Envelope.
      p text if $DEBUG
    end
  end

  def endElement( name )
    lastFrame = @parseStack.pop
    decodeTagEnd( lastFrame.ns, lastFrame.node, lastFrame.encodingStyle )
    @lastNode = lastFrame.node.node
  end

private

  def setXMLDeclEncoding( charset )
    if @charset.nil?
      @charset = charset
    else
      # Definition in a stream (like HTTP) has a priority.
      p "encoding definition: #{ charset } is ignored." if $DEBUG
    end
  end

  # $1 is necessary.
  NSParseRegexp = Regexp.new( '^xmlns:?(.*)$' )

  def parseNS( ns, attrs )
    return unless attrs
    attrs.each do | key, value |
      next unless ( NSParseRegexp =~ key )
      # '' means 'default namespace'.
      tag = $1 || ''
      ns.assign( value, tag )
    end
  end

  def getEncodingStyle( ns, attrs )
    attrs.each do | key, value |
      if ( ns.compare( EnvelopeNamespace, AttrEncodingStyle, key ))
	return value
      end
    end
    nil
  end

  def decodeTag( ns, name, attrs, parent, encodingStyle )
    element = ns.parse( name )

    # Envelope based parsing.
    if (( element.namespace == EnvelopeNamespace ) ||
	( @allowUnqualifiedElement && element.namespace.nil? ))
      o = decodeSOAPEnvelope( ns, element, attrs, parent )
      return o if o
    end

    # Encoding based parsing.
    handler = getHandler( encodingStyle )
    if handler
      return handler.decodeTag( ns, element, attrs, parent )
    else
      raise FormatDecodeError.new(
	"Unknown encodingStyle: #{ encodingStyle }." )
    end
  end

  def decodeTagEnd( ns, node, encodingStyle )
    return unless encodingStyle

    handler = getHandler( encodingStyle )
    if handler
      return handler.decodeTagEnd( ns, node )
    else
      raise FormatDecodeError.new( "Unknown encodingStyle: #{ encodingStyle }." )
    end
  end

  def decodeText( ns, text, encodingStyle )
    handler = getHandler( encodingStyle )

    if handler
      handler.decodeText( ns, text )
    else
      # How should I do?
    end
  end

  def decodeSOAPEnvelope( ns, element, attrs, parent )
    o = nil
    if element.name == EleEnvelope
      o = SOAPEnvelope.new
    elsif element.name == EleHeader
      unless parent.node.is_a?( SOAPEnvelope )
	raise FormatDecodeError.new( "Header should be a child of Envelope." )
      end
      o = SOAPHeader.new
      parent.node.header = o
    elsif element.name == EleBody
      unless parent.node.is_a?( SOAPEnvelope )
	raise FormatDecodeError.new( "Body should be a child of Envelope." )
      end
      o = SOAPBody.new
      parent.node.body = o
    elsif element.name == EleFault
      unless parent.node.is_a?( SOAPBody )
	raise FormatDecodeError.new( "Fault should be a child of Body." )
      end
      o = SOAPFault.new
      parent.node.setFault( o )
    end
    o.parent = parent if o
    o
  end

  def prologue
  end

  def epilogue
  end

  def getHandler( encodingStyle )
    unless @handlers.has_key?( encodingStyle )
      handlerFactory = SOAP::EncodingStyleHandler.getHandler( encodingStyle ) ||
	SOAP::EncodingStyleHandler.getHandler( EncodingNamespace )
      handler = handlerFactory.new( @charset )
      handler.decodeComplexTypes = @decodeComplexTypes
      handler.decodePrologue
      @handlers[ encodingStyle ] = handler
    end
    @handlers[ encodingStyle ]
  end
end


end
