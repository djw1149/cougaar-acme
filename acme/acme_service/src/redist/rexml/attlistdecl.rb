#vim:ts=2 sw=2 noexpandtab:
require 'rexml/child'
require 'rexml/source'

module REXML
	# This class needs:
	# * Documentation
	# * Work!  Not all types of attlists are intelligently parsed, so we just
	# spew back out what we get in.  This works, but it would be better if
	# we formatted the output ourselves.
	#
	# AttlistDecls provide *just* enough support to allow namespace
	# declarations.  If you need some sort of generalized support, or have an
	# interesting idea about how to map the hideous, terrible design of DTD
	# AttlistDecls onto an intuitive Ruby interface, let me know.  I'm desperate
	# for anything to make DTDs more palateable.
	class AttlistDecl < Child
		include XMLTokens
		include Enumerable
		ENUMERATION = "\\(\\s*#{NMTOKEN}(?:\\s*\\|\\s*#{NMTOKEN})*\\s*\\)"
		NOTATIONTYPE = "NOTATION\\s+\\(\\s*#{NAME}(?:\\s*\\|\\s*#{NAME})*\\s*\\)"
		ENUMERATEDTYPE = "(?:(?:#{NOTATIONTYPE})|(?:#{ENUMERATION}))"
		ATTTYPE = "(CDATA|ID|IDREF|IDREFS|ENTITY|ENTITIES|NMTOKEN|NMTOKENS|#{ENUMERATEDTYPE})"
		ATTVALUE = "(?:\"((?:[^<&\"]|#{REFERENCE})*)\")|(?:'((?:[^<&']|#{REFERENCE})*)')"
		DEFAULTDECL = "(#REQUIRED|#IMPLIED|(?:(#FIXED\\s+)?#{ATTVALUE}))"
		ATTDEF = "\\s+#{NAME}\\s+#{ATTTYPE}\\s+#{DEFAULTDECL}"
		ATTLISTDECL = /^\s*<!ATTLIST\s+#{NAME}(?:#{ATTDEF})*\s*>/um

		START_RE = /^\s*<!ATTLIST/um

		# What is this?  Got me.
		attr_reader :element

		# Create an AttlistDecl, pulling the information from a Source.  Notice
		# that this isn't very convenient; to create an AttlistDecl, you basically
		# have to format it yourself, and then have the initializer parse it.
		# Sorry, but for the forseeable future, DTD support in REXML is pretty
		# weak on convenience.  Have I mentioned how much I hate DTDs?
		def initialize source
			super()
			md = source.match( ATTLISTDECL, true )
			raise ParseException.new( "Bad ATTLIST declaration!", source ) if md.nil?
			@element = md[1]
			@contents = md[0]

			@pairs = {}
			values = md[0].scan( ATTDEF )
			values.each do |attdef|
				unless attdef[3] == "#IMPLIED"
					attdef.compact!
					val = attdef[3]
					val = attdef[4] if val == "#FIXED "
					@pairs[attdef[0]] = val
				end
			end
		end
	
		# Access the attlist attribute/value pairs.
		#  value = attlist_decl[ attribute_name ]
		def [](key)
			@pairs[key]
		end

		# Whether an attlist declaration includes the given attribute definition
		#  if attlist_decl.include? "xmlns:foobar"
		def include?(key)
			@pairs.keys.include? key
		end

		# Itterate over the key/value pairs:
		#  attlist_decl.each { |attribute_name, attribute_value| ... }
		def each(&block)
			@pairs.each(&block)
		end

		# Parses an AttlistDecl out of a Source, and notifies a given listerer of
		# the event.
		def AttlistDecl.parse_stream source, listener
			listener.attlistdecl pull(source)
		end

		# Purrl an AttlistDecl from a Source, returning ... what?  FIX THESE DOCS
		def AttlistDecl.pull source
			source.match( ATTLISTDECL, true )[1]
		end

		# Write out exactly what we got in.
		def write out, indent=-1
			out << @contents
		end
	end
end
