require 'rexml/document'

module REXML
	class SAX2Parser
		def initialize source
			@listener = SAXHelper.new( )
			@source = source
		end
		
		# Listen arguments:
		#
		# Symbol, Array, Block
		# 	Listen to Symbol events on Array elements
		# Symbol, Block
		#   Listen to Symbol events
		# Array, Listener
		# 	Listen to all events on Array elements
		# Array, Block
		# 	Listen to :start_element events on Array elements
		# Listener
		# 	Listen to All events
		#
		# Symbol can be one of: :start_element, :end_element,
		# :start_prefix_mapping, :end_prefix_mapping, :characters,
		# :processing_instruction, :doctype, :attlistdecl, :elementdecl,
		# :entitydecl, :notationdecl, :cdata, :xmldecl, :comment
		#
		# Array contains regular expressions or strings which will be matched
		# against fully qualified element names.
		#
		# Listener must implement the methods in SAX2Listener
		#
		# Block will be passed the same arguments as a SAX2Listener method would
		# be, where the method name is the same as the matched Symbol.
		# See the SAX2Listener for more information.
		def listen( *args, &blok )
			if args[0].kind_of? Symbol
				if args.size == 2
					args[1].each { |match| @listener << [args[0], match, blok] }
				else
					@listener << [args[0], /.*/, blok]
				end
			elsif args[0].kind_of? Array
				if args.size == 2
					args[0].each { |match| @listener << [nil, match, args[1]] }
				else
					args[0].each { |match| @listener << [ :start_element, match, blok ] }
				end
			else
				@listener << [nil, /.*/, args[0]]
			end
		end
		
		def deafen( listener=nil, &blok )
			if listener
				@listener.del listener
			else
				@listener.del blok
			end
		end
		
		def parse
			@listener.start_document
			Document.parse_stream( @source, @listener )
			@listener.end_document
		end
	end



	private
	class SAXHelper
		def initialize
			@listeners = []
			@procs = []
			@namespace_stack = []
			@has_listeners = false
			@tag_stack = []
		end


		def << pair
			if pair[-1].kind_of? Proc
				@procs << pair unless @procs.include? pair
			else
				@listeners << pair unless @listeners.include? pair
				@has_listeners = true
			end
		end


		def del ob
			if ob.kind_of? Proc
				found = @procs.find {|item| item[-1] == ob }
				@procs.delete found
			else
				found = @listeners.find {|item| item[-1] == ob }
				@listeners.delete found
				@has_listeners = false if @listeners.size == 0
			end
		end


		def tag_start name, attrs
			@tag_stack.push name
			attributes = {}
			attrs.each { |n,v| attributes[n] = v }
			# find the observers for namespaces
			procs = get_procs( :start_prefix_mapping, name )
			listeners = get_listeners( :start_prefix_mapping, name )
			if procs or listeners
				# break out the namespace declarations
				nsdecl = attrs.find_all { |n, value| n =~ /^xmlns:/ }
				nsdecl.collect! { |n, value| [ n[6..-1], value ] }
				@namespace_stack.push({})
				nsdecl.each do |n,v|
					@namespace_stack[-1][n] = v
					# notify observers of namespaces
					procs.each { |ob| ob.call( n, v ) } if procs
					listeners.each { |ob| ob.start_prefix_mapping(n, v) } if listeners
				end
			end
			name =~ Namespace::NAMESPLIT
			prefix = $1
			local = $2
			uri = get_namespace prefix
			# find the observers for start_element
			procs = get_procs( :start_element, name )
			listeners = get_listeners( :start_element, name )
			# notify observers
			procs.each { |ob| ob.call( uri, local, name, attributes ) } if procs
			listeners.each { |ob| ob.start_element( uri, local, name, attributes ) } if listeners
		end


		def tag_end name
			@tag_stack.pop
			name =~ Namespace::NAMESPLIT
			prefix = $1
			local = $2
			uri = get_namespace prefix
			# find the observers for start_element
			procs = get_procs( :end_element, name )
			listeners = get_listeners( :end_element, name )
			# notify observers
			procs.each { |ob| ob.call( uri, local, name ) } if procs
			listeners.each { |ob| ob.end_element( uri, local, name ) } if listeners

			namespace_mapping = @namespace_stack.pop
			# find the observers for namespaces
			procs = get_procs( :end_prefix_mapping, name )
			listeners = get_listeners( :end_prefix_mapping, name )
			if procs or listeners
				namespace_mapping.each do |prefix, uri|
					# notify observers of namespaces
					procs.each { |ob| ob.call( prefix ) } if procs
					listeners.each { |ob| ob.end_prefix_mapping(prefix) } if listeners
				end
			end
		end

		def text text
			if @has_listeners
				handle( :characters, text ) { |ob| 
					ob.characters( text ) 
				}
			else
				handle( :characters, text )
			end
		end

		def instruction name, instruction
			if @has_listeners
				handle( :processing_instruction, name, instruction ) { |ob| 
					ob.processing_instruction( name, instruction ) 
				}
			else
				handle( :processing_instruction, name, instruction ) 
			end
		end

		def comment comment
			if @has_listeners
				handle( :comment, comment ) { |ob| ob.comment( comment ) }
			else
				handle( :comment, comment )
			end
		end

		def doctype name, ps, ln, uri
			if @has_listeners
				handle( :doctype, name, ps, ln, uri ) { |ob| 
					ob.doctype( name, ps, ln, uri ) 
				}
			else
				handle( :doctype, name, ps, ln, uri )
			end
		end

		def attlistdecl content
			if @has_listeners
				handle( :attlistdecl, content ) { |ob| ob.attlistdecl( content ) }
			else
				handle( :attlistdecl, content )
			end
		end

		def elementdecl content
			if @has_listeners
				handle( :elementdecl, content ) { |ob| ob.elementdecl( content ) }
			else
				handle( :elementdecl, content )
			end
		end

		def entitydecl content
			if @has_listeners
				handle( :entitydecl, content ) { |ob| ob.entitydecl( content ) }
			else
				handle( :entitydecl, content ) 
			end
		end

		def notationdecl content
			if @has_listeners
				handle( :notationdecl, content ) { |ob| ob.notationdecl( content ) }
			else
				handle( :notationdecl, content )
			end
		end

		# DEPRECATED.  This method is never called
		def entity content
		end

		def cdata content
			if @has_listeners
				handle( :cdata, content ) { |ob| ob.cdata( content ) }
			else
				handle( :cdata, content )
			end
		end

		def xmldecl version, encoding, standalone
			if @has_listeners
				handle( :xmldecl, version, encoding, standalone ) { |ob| 
					ob.xmldecl( version, encoding, standalone ) 
				}
			else
				handle( :xmldecl, version, encoding, standalone )
			end
		end

		def start_document
			@procs.each { |sym,match,block| block.call if sym == :start_document }
			@listeners.each { |sym,match,block| 
				block.start_document if sym == :start_document or sym.nil?
			}
		end

		def end_document
			@procs.each { |sym,match,block| block.call if sym == :end_document }
			@listeners.each { |sym,match,block| 
				block.end_document if sym == :end_document or sym.nil?
			}
		end

		private
		def handle( symbol, *arguments, &block )
			tag = @tag_stack[-1]
			procs = get_procs( symbol, tag )
			listeners = get_listeners( symbol, tag )
			# notify observers
			procs.each { |ob| ob.call( *arguments ) } if procs
			listeners.each(&block) if listeners
		end

		
		# The following methods are duplicates, but it is faster than using
		# a helper
		def get_procs( symbol, name )
			return nil if @procs.size == 0
			@procs.find_all do |sym, match, block|
				(
					(sym.nil? or symbol == sym) and 
					(name.nil? or (
						(name == match) or
						(match.kind_of? Regexp and name =~ match)
						)
					)
				)
			end.collect{|x| x[-1]}
		end
		def get_listeners( symbol, name )
			return nil if @listeners.size == 0
			@listeners.find_all do |sym, match, block|
				(
					(sym.nil? or symbol == sym) and 
					(name.nil? or (
						(name == match) or
						(match.kind_of? Regexp and name =~ match)
						)
					)
				)
			end.collect{|x| x[-1]}
		end

		def get_namespace( prefix ) 
			uri = @namespace_stack.find do |ns|
				not ns[prefix].nil?
			end
			uri[prefix] unless uri.nil?
		end
	end
end
