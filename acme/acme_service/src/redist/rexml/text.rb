require 'rexml/entity'

module REXML
	# Represents text in an XML document
	class Text < Child
		include Comparable
		# The order in which the substitutions occur
		SPECIALS = [ /&(?!#?[\w-]+;)/u, /</u, />/u, /"/u, /'/u, /\r/u ]
		SUBSTITUTES = ['&amp;', '&lt;', '&gt;', '&quot;', '&apos;', '&#13;']
		# Characters which are substituted in written strings
		SLAICEPS = [ '<', '>', '"', "'", '&' ]
		SETUTITSBUS = [ /&lt;/u, /&gt;/u, /&quot;/u, /&apos;/u, /&amp;/u ]


		# string is String content, raw is a boolean
		attr_reader :string
		attr_accessor :raw
		PATTERN_SEARCH = /\A([^<]*)</um
		PATTERN = /\A([^<]*)/um
		ILLEGAL = /<|&(?!#?[-\w]+;)/u

		# Constructor
		# FIXME: This documentation sucks.
		# @param arg if a String, the content is set to the String.  If a Text,
		# the object is shallowly cloned.  If a Source, the source is parsed
		# for text content up to the next element.  If a Parent, the parent of
		# this object is set to the argument.  If true or false, will be used as
		# the value for the 'raw' setting.
		# @param respect_whitespace (boolean, optional) if true, whitespace is
		# respected
		# @param parent (Parent, optional) if this is a Parent object, the parent
		# will be set to this.  If this is true or false, the value will be used
		# as the 'raw' setting.
		# @param pattern INTERNAL USE ONLY
		# @param raw INTERNAL USE ONLY
		def initialize(arg, respect_whitespace=false, parent=nil, pattern=PATTERN, raw=false)
			@raw = raw
			if parent
				if parent == true
					@raw = true
					@parent = nil
				elsif parent.kind_of? Parent
					super( parent )
					@raw = parent.raw
				end
			else
				@parent = nil
			end
			if arg.kind_of? Source
				# OPTIMIZE
				# We've got two lines to do one search.  Can we improve this?
				arg.match(PATTERN_SEARCH)
				md = arg.match(pattern, true)
				raise "no text to add" if md[0].length == 0
				@string = md[1]
				@string.squeeze!(" \n\t") unless respect_whitespace
				@normalized = true
				#@string = Node::read_with_substitution(@string, ILLEGAL) unless @raw
			elsif arg.kind_of? String
				@string = arg.clone
				@string.squeeze!(" \n\t") unless respect_whitespace
				@normalized = false
				#@string = Text::normalize(@string) unless @raw
				#@string = Node::read_with_substitution(@string) unless @raw
			elsif arg.kind_of? Text
				@string = arg.string
				@raw = arg.raw
				@normalized = true
			elsif arg.kind_of? Parent
				super( arg )
			elsif [true,false].include? arg
				@raw = arg
			end
		end

		def empty?
			@string.size==0
		end

		def clone
			return Text.new(self)
		end

		# @param other a String or a Text
		# @return the result of (to_s <=> arg.to_s)
		def <=>( other )
			@string <=> other.to_s
		end

		REFERENCE = /#{Entity::REFERENCE}/
		# Returns an UNNORMALIZED value; IE, entities that can be replaced have
		# been replaced.
		def to_s
			return @string if @raw or not @normalized
			doctype = nil
			if @parent
				doc = @parent.document
				doctype = doc.doc_type if doc
			end
			@normalized = false
			@string = Text::unnormalize( @string, doctype )
		end

		def write( writer, indent=-1, transitive=false ) 
			#indent( writer, indent )
			s = @string
			#if (indent>-1)
			#	s = @string.strip
			#end
			if @normalized
				writer << s
			else
				dt = nil
				dt = @parent.document.doc_type if @parent and @parent.document
				writer << Text::normalize( s, dt )
			end
		end

		def Text.parse_stream source, listener
			md = source.match(PATTERN, true)
			raise "no text to add" if md[0].length == 0
			listener.text( Text::unnormalize(md[1]) )
		end

		def Text.pull source
			md = source.match(PATTERN, true)
			raise "no text to add" if md[0].length == 0
			return Text::unnormalize(md[1])
		end
		
		# Writes out text, substituting special characters beforehand.
		# @param out A String, IO, or any other object supporting <<( String )
		# @param input the text to substitute and the write out
		#
		# z=utf8.unpack("U*")
		# ascOut=""
		# z.each{|r|
		#   if r <  0x100
		#     ascOut.concat(r.chr)
		#   else
		#     ascOut.concat(sprintf("&#x%x;", r))
		#   end
		# }
		# puts ascOut
		def write_with_substitution out, input
			copy = input.clone
			# Doing it like this rather than in a loop improves the speed
			copy.gsub!( SPECIALS[0], SUBSTITUTES[0] )
			copy.gsub!( SPECIALS[1], SUBSTITUTES[1] )
			copy.gsub!( SPECIALS[2], SUBSTITUTES[2] )
			copy.gsub!( SPECIALS[3], SUBSTITUTES[3] )
			copy.gsub!( SPECIALS[4], SUBSTITUTES[4] )
			copy.gsub!( SPECIALS[5], SUBSTITUTES[5] )
			out << copy
		end

		# Reads text, substituting entities
		def Text::read_with_substitution( input, illegal=nil )
			copy = input.clone

			if copy =~ illegal
				raise ParseException.new( "malformed text: Illegal character #$& in \"#{copy}\"" )
			end if illegal
			
			copy.gsub!( /\r\n?/, "\n" )
			if copy.include? ?&
				copy.gsub!( SETUTITSBUS[0], SLAICEPS[0] )
				copy.gsub!( SETUTITSBUS[1], SLAICEPS[1] )
				copy.gsub!( SETUTITSBUS[2], SLAICEPS[2] )
				copy.gsub!( SETUTITSBUS[3], SLAICEPS[3] )
				copy.gsub!( SETUTITSBUS[4], SLAICEPS[4] )
				copy.gsub!( /&#0*((?:\d+)|(?:x[a-f0-9]+));/ ) {|m|
					m=$1
					#m='0' if m==''
					m = "0#{m}" if m[0] == ?x
					[Integer(m)].pack('U*')
				}
			end
			copy
		end

		EREFERENCE = /&(?!#{Entity::NAME};)/
		def Text::normalize( input, doctype=nil )
			copy = input.clone
			# Doing it like this rather than in a loop improves the speed
			if doctype
				copy.gsub!( EREFERENCE, '&amp;' )
				doctype.entities.each_value do |entity|
					copy.gsub!( entity.value, "&#{entity.name};" ) if entity.value
				end
			else
				copy.gsub!( EREFERENCE, '&amp;' )
				DocType::DEFAULT_ENTITIES.each_value do |entity|
					copy.gsub!(entity.value, "&#{entity.name};" )
				end
			end
			copy
		end

		def Text::unnormalize( string, doctype=nil, illegal=nil )
			rv = string.clone
			rv.gsub!( /\r\n?/, "\n" )
			matches = rv.scan REFERENCE
			return rv if matches.size == 0
			rv.gsub!( /&#0*((?:\d+)|(?:x[a-f0-9]+));/ ) {|m|
				m=$1
				m = "0#{m}" if m[0] == ?x
				[Integer(m)].pack('U*')
			}
			matches.collect!{|x|x[0]}.compact!
			if matches.size > 0
				if doctype
					matches.each do |entity_reference|
						entity_value = doctype.entity( entity_reference )
						rv.gsub!( /&#{entity_reference};/, entity_value ) if entity_value
					end
				else
					matches.each do |entity_reference|
						entity_value = DocType::DEFAULT_ENTITIES[ entity_reference ]
						rv.gsub!( /&#{entity_reference};/, entity_value.value ) if entity_value
					end
				end
				rv.gsub!( /&amp;/, '&' )
			end
			rv
		end
	end
end
