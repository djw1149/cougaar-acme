require "rexml/element"
require "rexml/xmldecl"
require "rexml/source"
require "rexml/comment"
require "rexml/doctype"
require "rexml/instruction"
require "rexml/rexml"
require "rexml/parseexception"
require "rexml/output"

module REXML
  # Represents a full XML document, including PIs, a doctype, etc.  A
  # Document has a single child that can be accessed by root().
  # Note that if you want to have an XML declaration written for a document
  # you create, you must add one; REXML documents do not write a default
	# declaration for you.  See |DECLARATION| and |write|.
	class Document < Element
		# A convenient default XML declaration.  If you want an XML declaration,
		# the easiest way to add one is mydoc << Document::DECLARATION
		DECLARATION = XMLDecl.new( "1.0", "UTF-8" )

		# Constructor
		# @param source if supplied, must be a Document, String, or IO. 
		# Documents have their context and Element attributes cloned.
	  # Strings are expected to be valid XML documents.  IOs are expected
	  # to be sources of valid XML documents.
	  # @param context if supplied, contains the context of the document;
	  # this should be a Hash.
	  # NOTE that I'm not sure what the context is for; I cloned it out of
	  # the Electric XML API (in which it also seems to do nothing), and it
	  # is now legacy.  It may do something, someday... it may disappear.
		def initialize( source = nil, context = {} )
			super()
			@context = context
			return if source.nil?
			if source.kind_of? Source
				parse( source )
			elsif source.kind_of? Document
				super source
				@context = source.context
			else
				parse( SourceFactory.create_from(source) )
			end
		end

		# Should be obvious
		def clone
			Document.new self
		end

		# According to the XML spec, a root node has no expanded name
		def expanded_name
			''
			#d = doc_type
			#d ? d.name : "UNDEFINED"
		end

		alias :name :expanded_name

		# We override this, because XMLDecls and DocTypes must go at the start
		# of the document
		def add( child )
			if child.kind_of? XMLDecl
				@children.unshift child
			elsif child.kind_of? DocType
				if @children[0].kind_of? XMLDecl
					@children[1,0] = child
				else
					@children.unshift child
				end
			else
				rv = super
				raise "attempted adding second root element to document" if @elements.size > 1
				rv
			end
		end
		alias :<< :add

		def add_element(arg=nil, arg2=nil)
			rv = super
			raise "attempted adding second root element to document" if @elements.size > 1
			rv
		end

		# @return the root Element of the document, or nil if this document
		# has no children.
		def root
			@children.find { |item| item.kind_of? Element }
		end

		# @return the DocType child of the document, if one exists,
		# and nil otherwise.
		def doc_type
			@children.find { |item| item.kind_of? DocType }
		end

		# @return the XMLDecl of this document; if no XMLDecl has been
		# set, the default declaration is returned.
		def xml_decl
			rv = @children.find { |item| item.kind_of? XMLDecl }
			rv = DECLARATION if rv.nil?
			rv
		end

		# @return the XMLDecl version of this document as a String.
		# If no XMLDecl has been set, returns the default version.
		def version
			decl = xml_decl()
			decl.nil? ? XMLDecl.DEFAULT_VERSION : decl.version
		end

		# @return the XMLDecl encoding of this document as a String.
		# If no XMLDecl has been set, returns the default encoding.
		def encoding
			decl = xml_decl()
			decl.nil? or decl.encoding.nil? ? XMLDecl.DEFAULT_ENCODING : decl.encoding
		end

		# @return the XMLDecl standalone value of this document as a String.
		# If no XMLDecl has been set, returns the default setting.
		def stand_alone?
			decl = xml_decl()
			decl.nil? ? XMLDecl.DEFAULT_STANDALONE : decl.stand_alone?
		end

		# Write the XML tree out, optionally with indent.  This writes out the
		# entire XML document, including XML declarations, doctype declarations,
		# and processing instructions (if any are given).
		# A controversial point is whether Document should always write the XML
		# declaration (<?xml version='1.0'?>) whether or not one is given by the
		# user (or source document).  REXML does not write one if one was not
		# specified, because it adds unneccessary bandwidth to applications such
		# as XML-RPC.
		# @param output an object which supports '<< string'; this is where the
		# document will be written
		# @param indent (optional) if given, the starting indent for the lines
		# in the document.
		def write( output, indent=-1, transitive=false )
			output = Output.new( output, xml_decl.encoding ) if xml_decl.encoding != "UTF-8"
			@children.each { |node|
				node.write( output, indent, transitive )
				output << "\n" unless indent<0 or node == @children[-1]
			}
		end

		# Stream parser.  The source will be parsed as a Stream.  
		# If a block is supplied, yield will be called for tag starts, ends,
		# and text.  If a listener is supplied, the listener will also be
		# notified, by calling the appropriate methods on events.
		# The arguments to the block will be:
		# IF TAG START: "tag name", { attributes } (possibly empty)
		# IF TEXT: "text"
		# IF TAG END: "/tag name"
		# The listener must supply the following methods:
		# tag_start( "name", { attributes } )
		# tag_end( "name" )
		# text( "text" )
		# instruction( "name", "instruction" )
		# comment( "comment" )
		# doctype( "name", *contents )
		def Document.parse_stream( source, listener )
			if			source.kind_of? Source
				# do nothing
			elsif		source.kind_of?  IO
				source = IOSource.new(source)
			elsif		source.kind_of? String
				source = Source.new source
			else
				raise "Unknown source type!"
			end

			while not source.empty?
				word = source.match( /^\s*(<.*?)>/um )
				source.match( /^\s*/um, true )
				word = word[1] unless word.nil?
				case word
				when nil
					word = source.match( /\s*(\S+)/um, true )
					return if word.nil?
					word = word[0]
					raise "data found outside of root element ('#{word}')" if word.strip.length > 0
				when Comment::START_RE
					Comment.parse_stream source, listener
				when DocType::START_RE
					DocType.parse_stream source, listener
				when XMLDecl::START_RE
					XMLDecl.parse_stream source, listener
				when Instruction::START_RE
					Instruction.parse_stream source, listener
				else
					Element.parse_stream source, listener
				end
			end
			# Here we need to check for invalid documents.
		end

		# This and parse_stream could have been combined, but separating them
		# improves the speed of REXML
		def parse( source )
			begin 
				while not source.empty?
					word = source.match( /^\s*(<.*?)>/um )
					source.match( /^\s*/um, true )
					word = word[1] unless word.nil?
					case word
					when nil
						word = source.match( /\s*(\S+)/um, true )
						return if word.nil?
						raise ParseException.new( "data found outside of root element (data is '#{word}')", source ) if word[0].strip.length > 0
					when Comment::START_RE
						self.add( Comment.new( source ) )
					when DocType::START_RE
						self.add( DocType.new( source ) )
					when XMLDecl::START_RE
						x = XMLDecl.new( source )
						source.encoding = x.encoding
						self.add( x )
					when Instruction::START_RE
						self.add( Instruction.new(source) )
					else
						Element.new( source, self, @context )
					end
				end
				unless @elements.size == 1
					#@children.find_all{|x| puts x if x.kind_of? Element }
					raise "the document does not have exactly one root"
				end
			rescue ParseException
				$!.source = source
				$!.element = self
				raise
			rescue Exception
				old_ex = $!
				raise ParseException.new("unidentified error", source, self, old_ex)
			end
		end
	end
end
