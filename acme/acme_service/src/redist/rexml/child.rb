require "rexml/node"

module REXML
	##
	# A Child object is something contained by a parent, and this class
	# contains methods to support that.  Most user code will not use this
	# class directly.
	class Child
		include Node
		attr_reader :parent		# The Parent of this object

		# Constructor.  Any inheritors of this class should call super to make
		# sure this method is called.
		# @param parent if supplied, the parent of this child will be set to the
		# supplied value, and self will be added to the parent
		def initialize( parent = nil )
			#puts "IN CHILD, PARENT IS #{parent.type}"
			@parent = nil  
			# Declare @parent, but don't define it.  The next line sets the 
			# parent.
			parent.add( self ) unless parent.nil?
		end

		# Replaces this object with another object.  Basically, calls
		# Parent.replace_child
		# @return self
		def replace_with( child )
			@parent.replace_child( self, child )
			self
		end

		# Removes this child from the parent.
		# @return self
		def remove
			unless @parent.nil?
				@parent.delete self
			end
			self
		end

		def parent=( other )
			return if @parent == other
			@parent.delete self if defined? @parent and @parent
			@parent = other
		end

		alias :next_sibling :next_sibling_node
		alias :previous_sibling :previous_sibling_node

		def next_sibling=( other )
		  parent.insert_after self, other
		end

		def previous_sibling=(other)
		  parent.insert_before self, other
		end

		##
		# @return the document this child belongs to, or nil if this child
		# belongs to no document
		def document
			return parent.document unless parent.nil?
			nil
		end

		##
		# This doesn't yet handle encodings
		def bytes
			encoding = document.encoding

			to_s
		end

=begin
		def Child.once(*ids)
			for id in ids
				module_eval <<-"end_eval"
					alias_method :__#{id.to_i}__, #{id.inspect}
					def #{id.id2name}(*args, &block)
						def self.#{id.id2name}(*args, &block)
							@__#{id.to_i}__
						end
						@__#{id.to_i}__ = __#{id.to_i}__(*args, &block)
					end
				end_eval
			end
		end
=end
	end
end
