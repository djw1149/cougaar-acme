require "rexml/child"

module REXML
	##
	# Represents an XML comment; that is, text between <!-- ... -->
	class Comment < Child
		include Comparable
		START = "<!--"
		START_RE = /\A<!--/u
		STOP = "-->"
		PATTERN = /#{START}(.*?)#{STOP}/um

		attr_accessor :string			# The content text

		##
		# Constructor.  The first argument can be one of three types:
		# @param first If String, the contents of this comment are set to the 
		# argument.  If Comment, the argument is duplicated.  If
		# Source, the argument is scanned for a comment.
		# @param second If the first argument is a Source, this argument 
		# should be nil, not supplied, or a Parent to be set as the parent 
		# of this object
		def initialize( first, second = nil )
			#puts "IN COMMENT CONSTRUCTOR; SECOND IS #{second.type}"
			super second
			if first.kind_of? String
				@string = first
			elsif first.kind_of? Comment
				@string = first.string
			elsif first.kind_of? Source
				@string = first.match( PATTERN, true )[1]
			end
		end

		def clone
			Comment.new self
		end

		def write( output, indent=-1, transitive=false )
			indent( output, indent )
			output << START
			output << @string
			output << STOP
		end

		alias :to_s :string

		##
		# Compares this Comment to another; the contents of the comment are used
		# in the comparison.
		def <=>(other)
			other.to_s <=> @string
		end

		##
		# Compares this Comment to another; the contents of the comment are used
		# in the comparison.
		def ==( other )
			other.kind_of? Comment and
			(other <=> self) == 0
		end

		def Comment.parse_stream source, listener
			listener.comment(source.match( PATTERN, true )[1])
		end

		def Comment.pull source
			source.match( PATTERN, true )[1]
		end
	end
end
#vim:ts=2 sw=2 noexpandtab:
