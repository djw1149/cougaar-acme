=begin
WSDL4R - WSDL information base.
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


module WSDL


class Info
  attr_accessor :parent

  def initialize
    @parent = nil
  end

  def root
    @parent.root
  end

  def parseElement( element ); end	# abstract
  
  def parseAttr( attr, value ); end	# abstract

  def postParse; end			# abstract
end


end
