require "rexml/text"

module REXML
	class CData < Text
		START = '<![CDATA['
		START_RE = /\A<!\[CDATA\[/u
		STOP = ']]>'
		PATTERN = /#{Regexp.escape(START)}(.*?)#{Regexp.escape(STOP)}/um

		#	Constructor.  CData is data between <![CDATA[ ... ]]>
		#
		# _Examples_
		#  CData.new( source )
		#  CData.new( "Here is some CDATA" )
		#  CData.new( "Some unprocessed data", respect_whitespace_TF, parent_element )
		def initialize( first, whitespace=nil, parent=nil )
			super( first, whitespace, parent, PATTERN, true )
		end

		# Make a copy of this object
		# 
		# _Examples_
		#  c = CData.new( "Some text" )
		#  d = c.clone
		#  d.to_s        # -> "Some text"
		def clone
			CData.new self
		end

		# Returns the content of this CData object
		#
		# _Examples_
		#  c = CData.new( "Some text" )
		#  c.to_s        # -> "Some text"
		def to_s
			@string
		end

		# Generates XML output of this object
		#
		# _Examples_
		#  c = CData.new( " Some text " )
		#  c.write( $stdout )     #->  <![CDATA[ Some text ]]>
		def write( output, indent=-1, transitive=false )
			indent( output, indent )
			output << START
			output << @string
			output << STOP
		end

		# Usually not called directly.
		def CData.parse_stream(source, listener)
			listener.cdata(source.match( PATTERN, true )[1])
		end

		def CData.pull( source )
			source.match( PATTERN, true )[1]
		end
	end
end
