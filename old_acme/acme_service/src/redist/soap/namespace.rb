=begin
SOAP4R - Namespace library
Copyright (C) 2000, 2001, 2002, 2003 NAKAMURA Hiroshi.

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
require 'soap/XMLSchemaDatatypes'


module SOAP


class NS
  attr_reader :defaultNamespace

  class FormatError < Error; end

public

  def initialize( initTag2NS = {} )
    @tag2ns = initTag2NS
    @ns2tag = {}
    @tag2ns.each do | tag, namespace |
      @ns2tag[ namespace ] = tag
    end
    @defaultNamespace = nil
  end

  def assign( namespace, tag = nil )
    if ( tag == '' )
      @defaultNamespace = namespace
      tag
    else
      tag ||= NS.assign( namespace )
      @ns2tag[ namespace ] = tag
      @tag2ns[ tag ] = namespace
      tag
    end
  end

  def assigned?( namespace )
    @ns2tag.has_key?( namespace )
  end

  def assignedTag?( tag )
    @tag2ns.has_key?( tag )
  end

  def clone
    cloned = NS.new( @tag2ns.dup )
    cloned.assign( @defaultNamespace, '' ) if @defaultNamespace
    cloned
  end

  def name( name )
    if ( name.namespace == @defaultNamespace )
      name.name
    elsif @ns2tag.has_key?( name.namespace )
      @ns2tag[ name.namespace ] + ':' << name.name
    else
      raise FormatError.new( 'Namespace: ' << name.namespace << ' not defined yet.' )
    end
  end

  def compare( namespace, name, rhs )
    if ( namespace == @defaultNamespace )
      return true if ( name == rhs )
    end
    @tag2ns.each do | assignedTag, assignedNS |
      if assignedNS == namespace &&
	  "#{ assignedTag }:#{ name }" == rhs
	return true
      end
    end
    false
  end

  # $1 and $2 are necessary.
  ParseRegexp = Regexp.new( '^([^:]+)(?::(.+))?$' )

  def parse( elem )
    namespace = nil
    name = nil
    ParseRegexp =~ elem
    if $2
      namespace = @tag2ns[ $1 ]
      name = $2
      if !namespace
	raise FormatError.new( 'Unknown namespace qualifier: ' << $1 )
      end
    elsif $1
      namespace = @defaultNamespace
      name = $1
    end
    if !name
      raise FormatError.new( "Illegal element format: #{ elem }" )
    end
    XSD::QName.new( namespace, name )
  end

  def eachNamespace
    @ns2tag.each do | namespace, tag |
      yield( namespace, tag )
    end
  end

  AssigningName = [ 0 ]

  def NS.assign( namespace )
    AssigningName[ 0 ] += 1
    'n' << AssigningName[ 0 ].to_s
  end

  def NS.reset()
    AssigningName[ 0 ] = 0
  end
end


end
