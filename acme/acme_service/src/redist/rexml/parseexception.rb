module REXML
	class ParseException < Exception
		attr_accessor :source, :element, :continued_exception

		def initialize( message, source=nil, element=nil, exception=nil )
			super(message)
			@source = source
			@element = nil
			@element = element if element.kind_of? Element
			@continued_exception = exception
		end

		def to_s
			# Quote the original exception, if there was one
			if @continued_exception
				err = @continued_exception.message
				err << "\n"
				err << @continued_exception.backtrace[0..3].join("\n")
				err << "\n...\n"
			else
				err = ""
			end

			# Get the stack trace and error message
			err << super

			# Add contextual information
			err << "\nat about line #{@source.current_line}:\n#{@source.buffer[0..80].gsub(/\n/, ' ')}\n" if @source
			# Information about the path of the element the error occurred in
			if @element
				path = @element.expanded_name
				path = "TAG MISSING ERROR" unless path
				parent = @element.parent
				while parent and not parent.type == "Document"
					path = parent.expanded_name + "/" + path
					parent = parent.parent
				end
				err << "in element #{path}\n"
			end
			err
		end

		def line
			@source.current_line if @source
		end
	end	
end
