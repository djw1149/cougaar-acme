require 'rexml/document'
require 'rexml/parseexception'
require 'rexml/xmltokens'

module REXML
	# = Using the Pull Parser
	# <em>This API is experimental, and subject to change.</em>
	#  parser = PullParser.new( "<a>text<b att='val'/>txet</a>" )
	#  while parser.has_next?
	#    res = parser.next
	#    puts res[1]['att'] if res.start_tag? and res[0] == 'b'
	#  end
	# See the PullEvent class for information on the content of the results.
	# The data is identical to the arguments passed for the various events to
	# the StreamListener API.
	#
	# Notice that:
	#  parser = PullParser.new( "<a>BAD DOCUMENT" )
	#  while parser.has_next?
	#    res = parser.next
	#    raise res[1] if res.error?
	#  end
	#
	# Nat Price gave me some good ideas for the API.
	class PullParser
		include XMLTokens

		def initialize stream
			if stream.kind_of? String
				@source = Source.new stream
			elsif stream.kind_of? IO
				@source = IOSource.new stream
			elsif stream.kind_of? Source
				@source = stream
			else
				raise "#{stream.type} is not a valid input stream.  It must be \n"+
				"either a String, IO, or Source."
			end
			@closed = nil
			@document_status = nil
			@tags = []
			@stack = []
			@entities = []
		end

		# Returns true if there are no more events
		def empty?
			!has_next?
		end

		# Returns true if there are more events.  Synonymous with !empty?
		def has_next?
			@source.read if @source.buffer.size==0 and !@source.empty?
			(!@source.empty? and @source.buffer.strip.size>0 and @stack.size==0) or @closed
		end

		def each
			while has_next?
				yield self.next
			end
		end

		# Push an event back on the head of the stream.  This method
		# has (theoretically) infinite depth.
		def unshift token
			@stack.unshift(token) if token.kind_of? PullEvent
		end

		# Peek at the +depth+ event in the stack.  The first element on the stack
		# is at depth 0.  If +depth+ is -1, will parse to the end of the input
		# stream and return the last event, which is always :document_end.
		# Be aware that this causes the stream to be parsed up to the +depth+ 
		# event, so you can effectively pre-parse the entire document (pull the 
		# entire thing into memory) using this method.  
		def peek depth=0
			raise 'Illegal argument "#{depth}"' if depth < -1
			temp = []
			if depth == -1
				temp.push(self.next) until empty?
			else
				while @stack.size+temp.size < depth+1
					temp.push(self.next)
				end
			end
			@stack += temp if temp.size > 0
			@stack[depth]
		end

		CLOSE_MATCH = /^\s*<\/(#{NAME_STR})\s*>/um
		# Returns the next event.  This is a +PullEvent+ object.
		def next
			return PullEvent.new( :document_end ) if empty?
			if @closed
				x, @closed = @closed, nil
				return PullEvent.new( :end_element, x )
			end
			return @stack.shift if @stack.size > 0
			@source.read if @source.buffer.size==0
			if @document_status == nil
				@source.match( /^\s*/um, true )
				word = @source.match( /^\s*(<.*?)>/um )
				word = word[1] unless word.nil?
				case word
				when Comment::START_RE
					return PullEvent.new( :comment, Comment.pull( @source ))
				when XMLDecl::START_RE
					return PullEvent.new( :xmldecl, *XMLDecl.pull( @source ))
				when Instruction::START_RE
					return PullEvent.new( :processing_instruction, *Instruction.pull( @source ))
				when DocType::START_RE
					args = DocType.pull( @source )
					if args.pop == ">"
						@document_status = :after_doctype
						@source.read if @source.buffer.size==0
						md = @source.match(/^\s*/um, true)
					else
						@document_status = :in_doctype
					end
					return PullEvent.new( :doctype, *args)
				else
					@document_status = :after_doctype
					@source.read if @source.buffer.size==0
					md = @source.match(/\s*/um, true)
				end
			end
			#puts "Document status is #@document_status"
			if @document_status == :in_doctype
				md = @source.match(/\s*(.*?)>/um)
				case md[1]
				when ElementDecl::START_RE
					return PullEvent.new( :elementdecl, ElementDecl.pull(@source)) 
				when Entity::START_RE
					entity = Entity.pull(@source)
					@entities << entity
					return PullEvent.new( :entitydecl, *entity )
				when AttlistDecl::START_RE
					return PullEvent.new( :attlistdecl, AttlistDecl.pull(@source)) 
				when NotationDecl::START_RE
					return PullEvent.new( :notationdecl, NotationDecl.pull(@source)) 
				when /^\s*]>/um
					@document_status = :after_doctype
					@source.match( /^\s*/um, true )
				end
			end
			if @source.buffer[0] == ?<
				if @source.buffer[1] == ?/
					last_tag = @tags.pop
					md = @source.match( CLOSE_MATCH, true )
					raise ParseException.new( "Missing end tag for #{last_tag} "+
						"(got #{md[1]})", @source) unless last_tag == md[1]
					return PullEvent.new( :end_element, last_tag )
				elsif @source.buffer[1] == ?!
					md = @source.match(/\A(\s*[^>]*>)/um)
					#puts "SOURCE BUFFER = #{source.buffer}, #{source.buffer.size}"
					raise ParseException.new("Malformed node",@source) unless md
					case md[1]
					when CData::START_RE
						return PullEvent.new( :cdata, CData.pull( @source ))
					when Comment::START_RE
						return PullEvent.new( :comment, Comment.pull( @source ))
					else
						raise ParseException.new( "Declarations can only occur "+
						"in the doctype declaration.")
					end
				elsif @source.buffer[1] == ??
					return PullEvent.new( :processing_instruction, *Instruction.pull( @source ))
				else
					rv = Element.base_parser( @source )
					if rv[1]
						@closed = rv[0]
					else
						@tags.push rv[0]
					end
					attrs = {}
					rv[2].each { |a,b,c| attrs[a] = c }
					return PullEvent.new( :start_element, rv[0], attrs )
				end
			else
				text = Text.pull( @source )
				unnormalized = Text::unnormalize( text, self )
				return PullEvent.new( :text, text, unnormalized )
			end
			return PullEvent.new( :dummy )
		end

		def entity( reference )
			value = @entities.find { |entity_array|
				(entity_array.size == 2 || entity_array.size == 3) && entity_array[0] == reference
			}
			if value
				value = value[1]
			else
				value = DocType::DEFAULT_ENTITIES[ reference ]
				value = value.value if value  # This should be taken out and shot
			end
			Text::unnormalize( value, self ) if value
		end
	end

	# A parsing event.  The contents of the event are accessed as an +Array?,
	# and the type is given either by the ...? methods, or by accessing the
	# +type+ accessor.  The contents of this object vary from event to event,
	# but are identical to the arguments passed to +StreamListener+s for each
	# event.
	class PullEvent < Array
		# The type of this event.  Will be one of :tag_start, :tag_end, :text,
		# :processing_instruction, :comment, :doctype, :attlistdecl, :entitydecl,
		# :notationdecl, :entity, :cdata, :xmldecl, or :error.
		attr_reader :event_type
		def initialize(*args)
			concat args[1..-1]
			@event_type = args[0]
		end
		# Content: [ String tag_name, Hash attributes ]
		def start_element?
			@event_type == :start_element
		end
		# Content: [ String tag_name ]
		def end_element?
			@event_type == :end_element
		end
		# Content: [ String raw_text, String unnormalized_text ]
		def text?
			@event_type == :text
		end
		# Content: [ String text ]
		def instruction?
			@event_type == :processing_instruction
		end
		# Content: [ String text ]
		def comment?
			@event_type == :comment
		end
		# Content: [ String name, String pub_sys, String long_name, String uri ]
		def doctype?
			@event_type == :doctype
		end
		# Content: [ String text ]
		def attlistdecl?
			@event_type == :attlistdecl
		end
		# Content: [ String text ]
		def elementdecl?
			@event_type == :elementdecl
		end
		# Due to the wonders of DTDs, an entity declaration can be just about
		# anything.  There's no way to normalize it; you'll have to interpret the
		# content yourself.  However, the following is true:
		#
		# * If the entity declaration is an internal entity:
		#   [ String name, String value ]
		# Content: [ String text ]
		def entitydecl?
			@event_type == :entitydecl
		end
		# Content: [ String text ]
		def notationdecl?
			@event_type == :notationdecl
		end
		# Content: [ String text ]
		def entity?
			@event_type == :entity
		end
		# Content: [ String text ]
		def cdata?
			@event_type == :cdata
		end
		# Content: [ String version, String encoding, String standalone ]
		def xmldecl?
			@event_type == :xmldecl
		end
		def error?
			@event_type == :error
		end

		def inspect
			@event_type.to_s + ": "+super
		end
	end
end
