=begin
WSDL4R - WSDL SOAP binding definition.
Copyright (C) 2002 NAKAMURA Hiroshi.

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


require 'wsdl/info'


module WSDL
  module SOAP


class Binding < Info
  attr_reader :style
  attr_reader :transport

  def initialize
    super
    @style = nil
    @transport = nil
  end

  def parseElement( element )
    raise WSDLParser::UnknownElementError.new( "Unknown element #{ element }." )
  end

  StyleAttrName = XSD::QName.new( nil, 'style' )
  TransportAttrName = XSD::QName.new( nil, 'transport' )
  def parseAttr( attr, value )
    case attr
    when StyleAttrName
      @style = value
    when TransportAttrName
      @transport = value
    else
      raise WSDLParser::UnknownAttributeError.new( "Unknown attr #{ attr }." )
    end
  end
end


  end
end
