require 'rexml/encoding'
require 'rexml/source'

module REXML
	# NEEDS DOCUMENTATION
	class XMLDecl < Child
		include Encoding

		DEFAULT_VERSION = "1.0";
		DEFAULT_ENCODING = "UTF-8";
		DEFAULT_STANDALONE = "no";
		START = '<\?xml';
		STOP = '\?>';
		START_RE = /\A<\?xml\s/u;
		VERSION_RE = /\bversion\s*=\s*["'](.*?)['"]/um
		ENCODING_RE = /\bencoding=["'](.*?)['"]/um
		STANDALONE_RE = /\bstandalone=["'](.*?)['"]/um
		PATTERN = /<\?xml\s+(.*?)\?>*/um

		attr_accessor :version, :standalone

		def initialize(version=DEFAULT_VERSION, encoding=nil, standalone=nil)
			@encoding_set = !encoding.nil?
			if version.kind_of? Source
				super encoding
				XMLDecl.parse_stream version, self
				@parent = encoding if encoding.kind_of? Parent
			elsif version.kind_of? XMLDecl
				super()
				@version = version.version
				self.encoding = version.encoding
				@standalone = version.standalone
			else
				super()
				@version = version
				self.encoding = encoding
				@standalone = standalone
			end
			@version = DEFAULT_VERSION if @version.nil?
		end

		def clone
			XMLDecl.new(self)
		end

		def write writer, indent=-1, transitive=false
			indent( writer, indent )
			writer << START.sub(/\\/u, '')
			writer << " #{content}"
			writer << STOP.sub(/\\/u, '')
		end

		def ==( other )
		  other.kind_of?(XMLDecl) and
		  other.version == @version and
		  other.encoding == self.encoding and
		  other.standalone == @standalone
		end

		def xmldecl version, encoding, standalone
			@version = version
			@encoding_set = !encoding.nil?
			self.encoding = encoding
			@standalone = standalone
		end

		def XMLDecl.parse_stream source, listener
			listener.xmldecl(*pull(source))
		end

		def XMLDecl.pull source
			results = source.match( PATTERN, true )[1]
			version = VERSION_RE.match( results )
			version = version[1] unless version.nil?
			encoding = ENCODING_RE.match(results)
			encoding = encoding[1] unless encoding.nil?
			standalone = STANDALONE_RE.match(results)
			standalone = standalone[1] unless standalone.nil?
			[version, encoding, standalone]
		end

		alias :stand_alone? :standalone

		private
		def content
			rv = "version='#@version'"
			rv << " encoding='#{encoding}'" if @encoding_set
			rv << " standalone='#@standalone'" if @standalone
			rv
		end
	end
end
