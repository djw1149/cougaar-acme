require "rexml/parent"
require "rexml/parseexception"
require "rexml/namespace"
require 'rexml/entity'
require 'rexml/attlistdecl'
require 'rexml/xmltokens'

module REXML
	# Represents an XML DOCTYPE declaration; that is, the contents of <!DOCTYPE
	# ... >.  DOCTYPES can be used to declare the DTD of a document, as well as
	# being used to declare entities used in the document.
	class DocType < Parent
		include XMLTokens
		START = "<!DOCTYPE"
		START_RE = /\A\s*#{START}\s/um
		STOP = ">"
		STOP_RE = />/u
		SYSTEM = "SYSTEM"
		PUBLIC = "PUBLIC"
		OPEN_RE = /\A\s*\[/u
		PATTERN_RE = /\s*#{START}\s+(.*?)(\[|>)/um
		IDENTITY = /^([!\*\w]+)(\s+#{NCNAME_STR})?(\s+["'].*?['"])?(\s+['"].*?["'])?/u
		DEFAULT_ENTITIES = { 
			'gt'=>EntityConst::GT, 
			'lt'=>EntityConst::LT, 
			'quot'=>EntityConst::QUOT, 
			"apos"=>EntityConst::APOS 
		}

		# name is the name of the doctype
		# external_id is the referenced DTD, if given
		attr_reader :name, :external_id, :entities, :namespaces

		# Constructor
		#
		#	 dt = DocType.new( 'foo', '-//I/Hate/External/IDs' )
		#	 # <!DOCTYPE foo '-//I/Hate/External/IDs'>
		#	 dt = DocType.new( doctype_to_clone )
		#	 # Incomplete.  Shallow clone of doctype
		#	 source = Source.new( '<!DOCTYPE foo "bar">' )
		#	 dt = DocType.new( source )
		#	 # <!DOCTYPE foo "bar">
		#	 dt = DocType.new( source, some_document )
		#	 # Creates a doctype, and adds to the supplied document
		def initialize( first, parent=nil )
			@entities = DEFAULT_ENTITIES
			if first.kind_of? String
				super()
				@name = first
				@external_id = parent
			elsif first.kind_of? DocType
				super(parent)
				@name = first.name
				@external_id = first.external_id
			elsif first.kind_of? Source
				super(parent)
				md = first.match( PATTERN_RE, true )
				identity = md[1]
				close = md[2]

				identity =~ IDENTITY
				@name = $1

				raise ParseException.new("DOCTYPE is missing a name", first) if @name.nil?

				@pub_sys = $2.nil? ? nil : $2.strip
				@long_name = $3.nil? ? nil : $3.strip
				@uri = $4.nil? ? nil : $4.strip
				@external_id = nil

				case @pub_sys
				when "SYSTEM"
					@external_id = "SYSTEM"
				when "PUBLIC"
					@external_id = "PUBLIC"
				else
					# Done, or junk
				end
				# If these raise nil exceptions, then the doctype was malformed
				begin
					@external_id << " #@long_name" if @long_name
					@external_id << " #@uri" if @uri
				rescue
					raise "malformed DOCTYPE declaration #$&"
				end

				return if close == ">"
				parse_entities first
			end
		end

		def attributes_of element
			rv = []
			each do |child|
				child.each do |key,val|
					rv << Attribute.new(key,val)
				end if child.kind_of? AttlistDecl and child.element == element
			end
			rv
		end

		def attribute_of element, attribute
			att_decl = find do |child|
				child.kind_of? AttlistDecl and
				child.element == element and
				child.include? attribute
			end
			return nil unless att_decl
			att_decl[attribute]
		end

		def clone
			DocType.new self
		end

		def write( output, indent=0, transitive=false )
			indent( output, indent )
			output << START
			output << ' '
			output << @name
			output << " #@external_id" unless @external_id.nil?
			unless @children.empty?
				next_indent = indent + 2
				output << ' ['
				child = nil		# speed
				@children.each { |child|
					output << "\n"
					child.write( output, next_indent )
				}
				output << "\n"
				#output << '   '*next_indent
				output << "]"
			end
			output << STOP
		end

		def DocType.parse_stream source, listener
			args = pull(source)
			close = args.pop
			listener.doctype(*args)
			return if close == ">"
			parse_entities_source source, listener
		end

		def DocType.pull source
			md = source.match( PATTERN_RE, true )
			identity = md[1]
			close = md[2]

			identity =~ IDENTITY
			name = $1

			raise "DOCTYPE is missing a name" if name.nil?

			pub_sys = $2.nil? ? nil : $2.strip
			long_name = $3.nil? ? nil : $3.strip
			uri = $4.nil? ? nil : $4.strip
			[name, pub_sys, long_name, uri, close]
		end

		def entity( name )
			@entities[name].unnormalized if @entities[name]
		end

		def add child
			super(child)
			@entities = DEFAULT_ENTITIES.clone if @entities == DEFAULT_ENTITIES
			@entities[ child.name ] = child if child.kind_of? Entity
		end

		private
		PEDECL = /^\s*#{Entity::PEREFERENCE}/um
		def DocType.parser source
			begin
				md = source.match(/\s*(.*?)>/um)
				until md[1].strip == "]" 
					yield process(md[1], source)
					md = source.match(/\s*(.*?)>/um)
					raise ParseException.new( "Invalid end of DOCTYPE declaration \"#{source.buffer}\"", source ) if md.nil?
				end
				source.match(/\s*]\s*>/um, true)
			rescue ParseException
				raise
			rescue Exception => err
				raise
				raise ParseException.new( "Error parsing DOCTYPE declaration", source, nil, err )
			end
		end

		def DocType.parse_entities_source source, listener
			DocType.parser source do |arg|
				if arg.kind_of? String
					listener.entity arg
				else
					arg.parse_stream source, listener
				end
			end
		end

		def DocType::process match, source
			case match
			when /^%/um 				#/
				md = source.match(PEDECL, true)
				md[1]
			when AttlistDecl::START_RE
				AttlistDecl
			when ElementDecl::START_RE
				ElementDecl
			when Entity::START_RE
				Entity
			when NotationDecl::START_RE
				NotationDecl
			when Comment::START_RE
				Comment
			when Instruction::START_RE
				Instruction
			else
				if md.nil?
					raise "DocType error: no match!"
				else
					raise "illegal entry \"#{md[1]}\" in DOCTYPE\n(match data was '#{md[0]}'"
				end
			end
		end

		def parse_entities src
			DocType.parser(src) do |arg|
				if arg.kind_of? String
					#entity reference.  Process the reference value
					if ent = entity(arg)
						source = Source.new(ent)
						clss = DocType::process(ent, nil)
						add( clss.new(source) )
					end
				else
					add( arg.new(src) ) unless arg.kind_of? String
				end
			end
		end
	end

	# We don't really handle any of these since we're not a validating
	# parser, so we can be pretty dumb about them.  All we need to be able
	# to do is spew them back out on a write()

	# This is an abstract class.  You never use this directly; it serves as a
	# parent class for the specific declarations.
	class Declaration < Child
		def initialize src
			super()
			md = src.match( pattern, true )
			@string = md[1]
		end

		def to_s
			@string+'>'
		end

		def write( output, indent )
			output << ('   '*indent) if indent > 0
			output << to_s
		end

		def Declaration.parse_stream source, listener
			listener.send pull(source) 
		end
		def Declaration.pull source
			source.match( pattern, true )[1]
		end
	end
	
	class ElementDecl < Declaration
		START = "<!ELEMENT"
		START_RE = /^\s*#{START}/um
		PATTERN_RE = /^\s*(#{START}.*?)>/um
		def pattern
			PATTERN_RE
		end
		def ElementDecl.parse_stream source, listener
			listener.elementdecl pull(source)
		end
		def ElementDecl.pull source
			source.match( PATTERN_RE, true )[1]
		end
	end

	class NotationDecl < Child
		START = "<!NOTATION"
		START_RE = /^\s*#{START}/um
		#PATTERN_RE = /^\s*(#{START}.*?>)/um
		PUBLIC = /^\s*#{START}\s+(\w[-\w]*)\s+(PUBLIC)\s+((["']).*?\4)\s*>/um
		SYSTEM = /^\s*#{START}\s+(\w[-\w]*)\s+(SYSTEM)\s+((["']).*?\4)\s*>/um
		def initialize src
			super()
			if src.match( PUBLIC )
				md = src.match( PUBLIC, true )
			elsif src.match( SYSTEM )
				md = src.match( SYSTEM, true )
			else
				raise ParseException.new( "error parsing notation: no matching pattern", src )
			end
			@name = md[1]
			@middle = md[2]
			@rest = md[3]
		end

		def to_s
			"<!NOTATION #@name #@middle #@rest>"
		end

		def write( output, indent=-1 )
			output << ('   '*indent) if indent > 0
			output << to_s
		end

		def NotationDecl.parse_stream source, listener
			listener.notationdecl pull(source)
		end
		def NotationDecl.pull source
			md = nil
			if source.match( PUBLIC )
				md = source.match( PUBLIC, true )
			elsif source.match( SYSTEM )
				md = source.match( SYSTEM, true )
			else
				raise ParseException.new( "error parsing notation: no matching pattern", src )
			end
			md[0].squeeze " \t\n\r"
		end
	end
end
