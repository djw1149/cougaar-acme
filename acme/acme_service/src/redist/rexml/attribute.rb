require "rexml/namespace"
require 'rexml/text'

module REXML
	# Defines an Element Attribute; IE, a attribute=value pair, as in:
	# <element attribute="value"/>.  Attributes can be in their own
	# namespaces.  General users of REXML will not interact with the
	# Attribute class much.
	class Attribute
		include Node
		include Namespace

		# The element to which this attribute belongs
		attr_reader :element
		# The normalized value of this attribute.  That is, the attribute with
		# entities intact.
		attr_writer :normalized	
		PATTERN = /\s*(#{NAME_STR})\s*=\s*(["'])(.*?)\2/um

		# Constructor.
		#
		#  Attribute.new( attribute_to_clone )
		#  Attribute.new( source )
		#  Attribute.new( "attr", "attr_value" )
		#  Attribute.new( "attr", "attr_value", parent_element )
		def initialize( first, second=nil, parent=nil )
			@element = nil
			@normalized = true
			if first.kind_of? Attribute
				self.name = first.expanded_name
				@value = first.value
				if second.kind_of? Element
					@element = second
				else
					@element = first.element
				end
			elsif first.kind_of? String
				@element = parent if parent.kind_of? Element
				self.name = first
				@value = second
				@normalized = false
			elsif first.kind_of? Source
				@element = second if second.kind_of? Element
				md = first.match(PATTERN, true )
				self.name, @value = md[1],md[3]
			else
				raise "illegal argument #{first.type} to Attribute constructor"
			end
		end

		# Returns the namespace of the attribute.
		# 
		#  e = Element.new( "elns:myelement" )
		#  e.add_attribute( "nsa:a", "aval" )
		#  e.add_attribute( "b", "bval" )
		#  e.attributes.get_attribute( "a" ).prefix   # -> "nsa"
		#  e.attributes.get_attribute( "b" ).prefix   # -> "elns"
		#  a = Attribute.new( "x", "y" )
		#  a.prefix                                   # -> ""
		def prefix
			pf = super
			if pf == ""
				pf = @element.prefix if @element
			end
			pf
		end

		# Returns the namespace URL, if defined, or nil otherwise
		# 
		#  e = Element.new("el")
		#  e.add_attributes({"xmlns:ns", "http://url"})
		#  e.namespace( "ns" )              # -> "http://url"
		def namespace arg=nil
			arg = prefix if arg.nil?
			@element.namespace arg
		end

		# Returns true if other is an Attribute and has the same name and value,
		# false otherwise.
		def ==( other )
			other.kind_of?(Attribute) and other.name==name and other.value==@value
		end

		# Creates (and returns) a hash from both the name and value
		def hash
			name.hash + value.hash
		end

		# Returns this attribute out as XML source, expanding the name
		#
		#  a = Attribute.new( "x", "y" )
		#  a.to_string     # -> "x='y'"
		#  b = Attribute.new( "ns:x", "y" )
		#  b.to_string     # -> "ns:x='y'"
		def to_string
			if @normalized
				"#@expanded_name='#{@value.gsub(/'/, '&apos;')}'"
			else
				doc = @element.document
				dt = doc ? doc.doc_type : nil
				rv = "#@expanded_name='"
				rv << Text::normalize(@value, dt)
				rv << "'"
				rv
			end
		end

		# Returns the attribute value, normalized
		def to_s
			if @normalized
				@value
			else
				doc = @element.document
				dt = doc ? doc.doc_type : nil
				Text::normalize( @value, dt )
			end
		end

		# Returns the UNNORMALIZED value of this attribute.  That is, entities
		# that can be replaced have been replaced.
		def value
			return @value unless @normalized
			doctype = nil
			if @element
				doc = @element.document
				doctype = doc.doc_type if doc
			end
			@normalized = false
			@value = Text::unnormalize( @value, doctype )
		end

		# Returns a copy of this attribute
		def clone
			Attribute.new self
		end

		# Sets the element of which this object is an attribute.  Normally, this
		# is not directly called.
		#
		# Returns this attribute
		def element=( element )
			@element = element
			self
		end

		# Removes this Attribute from the tree, and returns true if successfull
		# 
		# This method is usually not called directly.
		def remove
			@element.attributes.delete self.name unless @element.nil?
		end

		# Writes this attribute (EG, puts 'key="value"' to the output)
		def write( output, indent=-1 )
			output << to_string
		end
	end
end
#vim:ts=2 sw=2 noexpandtab:
