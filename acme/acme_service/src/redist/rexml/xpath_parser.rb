require 'rexml/namespace'
require 'rexml/xmltokens'

# Ignore this class.  It adds a __ne__ method, because Ruby doesn't seem to
# understand object.send( "!=", foo ), whereas it *does* understand "<", "==",
# and all of the other comparison methods.  Stupid, and annoying, and not at
# all POLS.
class Object
	def __ne__(b)
		self != b
	end
end

module REXML
	# You don't want to use this class.  Really.  Use XPath, which is a wrapper
	# for this class.  Believe me.  You don't want to poke around in here.
	# There is strange, dark magic at work in this code.  Beware.  Go back!  Go
	# back while you still can!
	class XPathParser
		include XMLTokens
		LITERAL		= /^'([^']*)'|^"([^"]*)"/u

		def initialize
			@EQ_PROC = proc do |a,o,b|
				o = '==' if o == '='
				o = '__ne__' if o == '!='
				#puts "Comparing #{a.inspect} #{o} #{b.inspect}"
				equality_relational_compare(a,o,b)
			end
			@REL_PROC = method(:equality_relational_compare).to_proc
			@ANDEXPR = method(:AndExpr)
			@EQUALITYEXPR = method(:EqualityExpr)
			@RELATIONALEXPR = method(:RelationalExpr )
			@ADDITIVEEXPR = method(:AdditiveExpr )
			@MULTIPLICATIVEEXPR = method(:MultiplicativeExpr )
			@UNARYEXPR = method(:UnaryExpr )
			@PATHEXPR = method(:PathExpr )
		end

		def namespaces=( namespaces )
			Functions::namespace_context = namespaces
			@namespaces = namespaces
		end

		def parse path, nodeset, break_and_return=false
			#puts "path is #{path}, node is #{nodeset.type}" 
			rv = LocationPath(path, nodeset)[1]
			rv = [] unless rv
			return rv
		end

		private
		#LocationPath
		#	| RelativeLocationPath
		#	| '/' RelativeLocationPath?
		#	| '//' RelativeLocationPath
		def LocationPath path, nodeset
			#puts "LocationPath( '#{path}', #{puta nodeset} )" 
			case path
			when /^\/\//
				# '//' RelativeLocationPath
				path = "descendant-or-self::#$'"
				nodeset = [nodeset[0].root.parent]
			when /^\/$/
				return ["", [nodeset[0].root.parent]]
			when /^\//u
				# '/' RelativeLocationPath?
				path = $'
				nodeset = [nodeset[0].root.parent]
			end
			return RelativeLocationPath( path, nodeset )
		end

		#RelativeLocationPath
		#	|																										Step
		#		| (AXIS_NAME '::' | '@' | '') 										AxisSpecifier
		#			NodeTest
		#				Predicate
		#		| '.' | '..'																			AbbreviatedStep
		#	|	RelativeLocationPath '/' Step
		#	| RelativeLocationPath '//' Step
		AXIS = /^(ancestor|ancestor-or-self|attribute|child|descendant|descendant-or-self|following|following-sibling|namespace|parent|preceding|preceding-sibling|self)::/
		def RelativeLocationPath path, nodeset
			#puts "RelativePath( '#{path}', #{puta nodeset} )" 
			while path.size > 0
				case path
				when AXIS
					axis_name = $1
					path = $'
				when /^@/
					axis_name = 'attribute'
					path = $'
				when /^\.\./
					axis_name = 'parent'
					path = $'
				when /^\./
					axis_name = 'self'
					path = $'
				else
					axis_name = 'child'
				end
				#puts "CALLING AXE WITH #{axis_name}, #{path}, and #{puta nodeset}" 
				path,nodeset = axe( axis_name, path, nodeset )
				#puts "axe returned '#{path}' and #{puta nodeset}" 

				if path.size > 0 
					case path
					when /^\/\//
						path = "descendant-or-self::#$'"
						#axis_name = 'descendant-or-self'
					when /^\//
						path = $'
						#axis_name = 'child'
					else
						#puts "RETURNING #{path}" 
						return [path,nodeset]
					end
					#path,nodeset = axe( axis_name, path, nodeset )
				end
			end
			#puts "RETURNING #{path} and #{puta nodeset}" 
			return [path,nodeset]
		end

		# The following return arrays of true/false, a 1-1 mapping of the
		# supplied nodeset, except for axe(), which returns a filtered
		# nodeset

		def GenericExpr(path, nodeset, regex, method, &block)
			rest, results = method.call( path, nodeset )
			#puts "First #{method} call, results are #{puta results}" 
			#puts "'#{rest}' != '#{path}'? #{rest!=path}" 
			if rest != path
				maps = []
				#puts "LOOKING FOR #{regex.inspect}"
				while rest =~ regex
					#puts "LOOKED FOR #{regex.inspect}; REST IS #{rest}" 
					op = $1
					rest = $'
					#puts "Calling #{method} (operator #{op}) with #{rest}" 
					rest, res = method.call( rest, nodeset )
					#puts "Results #{method} are #{puta res}" 
					maps << res
					#puts "MAPS IS NOW #{puta maps}" 
				end
				maps.each { |map| results = yield( results, op, map ) }
				#puts "Results after join are #{puta results}" 
			end
			#puts "Returning [#{rest.inspect}, #{results.inspect}]"
			[rest, results]
		end

		#| OrExpr S 'or' S AndExpr
		#| AndExpr
		def OrExpr path, nodeset
			#puts "OrExpr( #{path}, #{puta nodeset} )" 
			GenericExpr( path, nodeset, /^\s*( or )/, @ANDEXPR ) {|a,o,b| 
				a = Functions::boolean(a)
				b = Functions::boolean(b)
				a | b
			}
		end

		#| AndExpr S 'and' S EqualityExpr
		#| EqualityExpr
		def AndExpr path, nodeset
			#puts "AndExpr( #{path}, #{puta nodeset} )" 
			GenericExpr( path, nodeset, /^\s*( and )/, @EQUALITYEXPR ) {|a,o,b| 
				a = Functions::boolean( a )
				b = Functions::boolean( b )
				[a & b]
			}
		end

		#| EqualityExpr ('=' | '!=')  RelationalExpr
		#| RelationalExpr
		def EqualityExpr path, nodeset
			#puts "EqualityExpr( #{path}, #{puta nodeset} )" 
			GenericExpr( path, nodeset, /^\s*(=|\!=)\s*/, @RELATIONALEXPR, &@EQ_PROC)
		end

		#| RelationalExpr ('<' | '>' | '<=' | '>=') AdditiveExpr
		#| AdditiveExpr
		def RelationalExpr path, nodeset
			#puts "RelationalExpr( #{path}, #{puta nodeset} )" 
			#puts "@REL_PROC IS A #@REL_PROC" 
			GenericExpr( path, nodeset, /^\s*(<=|>=|<|>)\s*/, @ADDITIVEEXPR, &@REL_PROC)
		end

		#| AdditiveExpr ('+' | S '-') MultiplicativeExpr
		#| MultiplicativeExpr
		def AdditiveExpr path, nodeset
			#puts "AdditiveExpr( #{path}, #{puta nodeset} )" 
			GenericExpr( path, nodeset, /^\s*(\+| -)\s*/, @MULTIPLICATIVEEXPR) {|a,o,b| 
				a = Functions::number(a)
				b = Functions::number(b)
				#puts "MATH:: #{a}(#{a.type}) #{o} #{b}(#{b.type})"
				a.send( o.strip, b )
			}
		end

		#| MultiplicativeExpr ('*' | S ('div' | 'mod') S) UnaryExpr
		#| UnaryExpr
		def MultiplicativeExpr path, nodeset
			#puts "MultiplicativeExpr( #{path}, #{puta nodeset} )" 
			GenericExpr( path, nodeset, /^\s*(\*| div | mod )\s*/, @UNARYEXPR) do |a,o,b|
				a = Functions::number(a)
				b = Functions::number(b)
				case o
				when '*'
					a * b
				when ' mod '
					a % b
				when ' div '
					a.to_f / b.to_f
				end
			end
		end

		#| '-' UnaryExpr
		#| UnionExpr
		def UnaryExpr path, nodeset
			#puts "UnaryExpr( #{path}, #{puta nodeset} )" 
			mult = 1 if path[0] == ?-
			while path[0] == ?-
				mult *= -1
				path = path[1..-1]
			end
			rest, results = UnionExpr( path, nodeset )
			#puts "After UnionExpr '#{path}' and #{puta nodeset}"
			#puts "We have #{puta results} and mult=#{mult}"
			join( results, [mult] ) {|a,o,b| 
				a = Functions::number(a)
				b = Functions::number(b)
				a * b
			} if mult
			[rest, results]
		end

		#| UnionExpr '|' PathExpr
		#| PathExpr
		def UnionExpr path, nodeset
			#puts "UnionExpr( #{path}, #{puta nodeset} )" 
			GenericExpr( path, nodeset, /^\s*(\|)\s*/, @PATHEXPR) {|a,o,b| a | b}
		end

		#| LocationPath
		#| FilterExpr ('/' | '//') RelativeLocationPath
		def PathExpr path, nodeset
			#puts "PathExpr( #{path}, #{puta nodeset} )" 
			p,n = FilterExpr path, nodeset
			#puts "After FilterExpr p is '#{p}' and n is #{puta n}" 
			return [p,n] if p.size == 0
			# p is now '/' '/'? RelativeLocationPath
			if p =~ /^\/\/?/
				if $& == '//'
					p = "descendant-or-self::#$'"
				else
					p = $'
				end
				#puts "CALLING RELATIVELOCATIONPATH" 
				return RelativeLocationPath(p, n)
			end
			return LocationPath(p, nodeset) if p =~ /^[\/\.\@\[\w_*]/
			return [p, n]
		end

		#| FilterExpr Predicate
		#| PrimaryExpr
		def FilterExpr path, nodeset
			path, results = PrimaryExpr(path, nodeset)
			#puts "Path is now '#{path}' (#{path.type}), results are #{puta results}" 
			path, results = Predicate(path, results) if path[0] == ?[
			[path, results]
		end

		#| VARIABLE_REFERENCE
		#| '(' expr ')'
		#| LITERAL
		#| NUMBER
		#| FunctionCall
		VARIABLE_REFERENCE	= /^\$(#{NAME_STR})/u
		NUMBER							= /^(\d*\.?\d+)/
		def PrimaryExpr path, nodeset
			#puts "#"*5+"PrimaryExpr('#{path}', #{puta nodeset})" 
			arry = []
			case path
			when VARIABLE_REFERENCE
				#puts "VARIABLE REF"
				varname = $1
				path = $'
				arry << @variables[ varname ]
			when /^(\w[-\w]*)(?:\()/
				#puts "GOT FUNCTION #$1"
				fname = $1
				path = $'
				return nil if fname =~ NT
				#return ['',[]] if fname =~ NT
				#puts "Calling #{fname} with #{path}"
				return FunctionCall(fname, path, nodeset)
			when LITERAL, NUMBER
				#puts "LITERAL, NUMBER = #$& > [#$1, #$2]"
				varname = $1.nil? ? $2 : $1
				path = $'
				arry << varname
			when /^\(/ 																							#/
				path, contents = get_group path
				contents = contents[1..-2]
				#puts "PATH=#{path} CONTENTS=#{contents}" 
				p, arry = OrExpr( contents, nodeset )
			else
				arry = nodeset
			end
			#puts "Returning '#{path}', '#{puta arry}'"
			return [path, arry]
		end

		#| FUNCTION_NAME '(' ( expr ( ',' expr )* )? ')'
		def FunctionCall funcname, rest, nodeset
			#puts "FunctionCall: #{funcname}(#{rest})" 
			funcname.gsub!(/-/, '_')
			path, arguments = parse_args rest
			#puts "ARGUMENTS SIZE = #{arguments.size}" 
			#puts "ARGUMENTS = #{puta arguments}" 
			args = arguments.collect {|arg| OrExpr( arg, nodeset )[1] }
			#puts "ARGS IS #{puta args}"
			results = []
			if args.size > 0
				#puts "NODESET IS ::: #{nodeset.size}" 
				#puts "CURARGS IS ::: #{args.size}" 

				nodeset.each_index do |index|
					#puts "1) Calling #{funcname}(#{args.join ', '}) with #{args.size} args" 
					results << Functions.send( funcname, *args )
				end
			else
				nodeset.each_index do |index|
					#puts "\n2) Calling #{funcname}()" 
					results << Functions.send( funcname )
				end
			end
			[path, results]
		end

		def axe( axis_name, path, nodeset ) 
			#puts "axe #{axis_name}, #{path} #{puta nodeset}" 
			return unless nodeset

			case axis_name
			when 'self'
				axe_helper(path, nodeset)
			when /^descendant/u
				results = []
				a = ""
				recurse( nodeset ) { |node| 
					a, b = axe_helper(path, [node]) 
					results += b if b
				}
				results.uniq!
				#puts "RESULTS ARE NOW #{puta results}" 
				[a, results]

			when /^ancestor/u
				ancestors = []
				ancestors += nodeset if axis_name =~ /self$/
				nodeset.each do |element|
					while element.parent
						element = element.parent
						ancestors << element
					end
				end
				#puts "ancestors is #{puta ancestors}" 
				axe_helper( path, ancestors)

			when "child"
				results = []
				#puts "PATH IS '#{path}'" 
				p = path
				nodeset.each do |element|
					if element.kind_of? Element
						#puts "YIELDING CHILDREN OF #{element.name if element.kind_of? Element}" 
						p,r = axe_helper( path, element.to_a )
						#puts "P IS NOW '#{p}'" 
						results += r
					end
				end
				#puts "CHILD: P IS NOW '#{p}'" 
				[p, results]

			when "attribute"
				results = []
				#puts "ATTRIBUTE: NODESET SIZE IS #{nodeset.size}" 
				p = ''
				nodeset.each do |element|
					p,r=axe_helper(path,element.attributes.values.flatten) if element.kind_of? Element
					#puts "#{path} => #{p}" 
					next unless r
					results += r
					results << nil if r.size < 1
				end
				#puts "ATTRIBUTE: P IS NOW '#{p}'" 
				#puts "results is now #{puta results}" 
				#results.collect!{ |a| a.value if a }
				[p,results]

			when "parent"
				axe_helper(path, nodeset.collect{|element| element.parent}.uniq)

			when "following-sibling"
				siblings = []
				nodeset.each do |el|
					while el = el.next_sibling
						siblings << el
					end
				end
				axe_helper(path, siblings.uniq)

			when "following"
				results = []
				p = ""
				nodeset.each do |node|
					set = following( node )
					p, res = axe_helper( path, set )
					results += res
				end
				return [p, results]
				#axe_helper(path, nodeset.collect{|element| element.next_node}.uniq)

			when "preceding-sibling"
				siblings = []
				nodeset.each do |el|
					while el = el.previous_sibling
						siblings << el
					end
				end
				axe_helper(path, siblings.uniq)

			when "preceding"
				results = []
				p = ""
				nodeset.each do |node|
					set = preceding( node )
					p, res = axe_helper( path, set )
					results += res
				end
				return [p, results]
				#axe_helper(path, nodeset.collect{|element| element.previous_node}.uniq)

			when "namespace"
				axe_helper( path, nodeset.collect{|el| el.namespace} )
			end
		end

		def axe_helper path, nodeset
			# NodeTest returns a true/false 1-1 map of nodeset
			#puts "axe_helper with nodeset #{puta nodeset}" 
			path, node_test = NodeTest( path, nodeset )
			#puts "NodeTest returned '#{path}' and #{puta node_test}" 
			#puts "Nodeset is now #{puta nodeset}" 
			join( nodeset, node_test ) {|a,o,b| a if b}
			#puts "After join, nodeset is #{puta nodeset}" 
			nodeset.compact!
			# Predicate returns a true/false 1-1 map  of nodeset
			if path[0] == ?[
				path, predicate = Predicate( path, nodeset )
				#puts "PREDICATE RETURNED '#{path}' and #{puta predicate}" 
				#puts "Joining with #{puta nodeset}" 
				join( nodeset, predicate ) {|a,o,b| a if b}
				nodeset.compact!
			end
			#puts "AXE HELPER RETURNING '#{path}'" 
			[path, nodeset]
		end

		def all_descendants nodeset
			rv = []
			nodeset.each { |node|
				if node.kind_of? Parent
					rv += node.to_a
					rv += all_descendants( node.to_a )
				end
			}
			rv
		end

		# Returns a 1-1 map of the nodeset
		# The contents of the resulting array are either:
		# 	true/false, if a positive match
		# 	String, if a name match
		#NodeTest
		#	| ('*' | NCNAME ':' '*' | QNAME)								NameTest
		#	| NODE_TYPE '(' ')'															NodeType
		#	| PI '(' LITERAL ')'														PI
		#		| '[' expr ']'																Predicate
		NCNAMETEST= /^(#{NCNAME_STR}):\*/u
		QNAME 		= Namespace::NAMESPLIT
		NT				= /^comment|text|processing-instruction|node$/
		NODE_TYPE	= /^(comment|text|processing-instruction|node)\(\)/
		PI				= /^processing-instruction\(/
		def NodeTest path, nodeset
			res = nil
			#puts "NodeTest with '#{path}' and #{puta nodeset}" 
			case path
			when /^\*/
				path = $'
				res = nodeset.collect {|n| Element===n || Attribute===n}
			when NODE_TYPE
				type = $1
				path = $'
				res = nodeset.collect { |n|
					case type
					when 'node'
						true
					when 'text'
						n.kind_of? Text
					when 'comment'
						n.kind_of? Comment
					when 'processing-instruction'
						n.kind_of? Instruction
					end
				}
			when PI
				p = path[$&.length..-1]
				path = $'
				p =~ LITERAL
				literal = $1
				p = p[$&.length..-1]
				raise ParseException.new("Missing ')' after processing instruction") if p[0]!=?)
				res = nodeset.collect { |n|
					true if n.kind_of? Instruction and n.target == literal
				}
			when NCNAMETEST
				#puts "NCNAMETEST #{path}"
				#puts "PREFIX = #$1"
				#puts "PATH = #$'"
				prefix = $1
				path = $'
				res = nodeset.collect {|n| n.kind_of? Namespace and matching_namespace?(n, prefix) }
			when QNAME
				#puts "QNAME"
				#puts "PREFIX = #$1"
				#puts "NAME = #$2"
				#puts "PATH = #$'"
				prefix = $1
				name = $2
				path = $'
				prefix = "" unless prefix
				#puts "QNAME #{prefix}:#{name}, '#{path}'" 
				res = nodeset.collect { |n|
					n.kind_of? Namespace and name==n.name and matching_namespace?(n, prefix)
				}
			end
			[path, res]
		end

		def matching_namespace?( node, prefix )
			prefix = node.prefix if node.kind_of? Attribute and prefix == ""
			nscontext = (@namespaces.nil? ? node.namespace(prefix) : @namespaces[prefix] )
			#print " -- matching_namespace? #{node.namespace} == #{nscontext}" 
			node.namespace == nscontext
		end

		# Filters the supplied nodeset on the predicate(s)
		def Predicate path, nodeset
			#puts "Predicate '#{path}'" 
			return nil unless path[0] == ?[
			predicates = []
			while path[0] == ?[
				path, expr = get_group path
				predicates << expr[1..-2] if expr
			end
			count = -1 
			mapping = nodeset.collect{ count = count+1 }
			nodes = nodeset.clone
			predicates.each do |expr|
				subresults = []
				nodes.each do |node|
					#puts "PREDICATE FILTERING #{node.name if node.kind_of? Element}" 
					ind = nodes.index(node)+1
					Functions.node = node
					Functions.pair = [ ind, nodes.size ]
					Functions.namespace_context = node
					p, r = OrExpr(expr, [node])
					r = r[0] if r.kind_of? Array
					if r.to_s =~ /^\d+(\.\d+)?$/
						r = r.to_s.to_f.round
						r = (r == ind)
					end
					#puts "PREDICATE ON NODE #{node.name if node.kind_of? Element}" 
					#puts "PREDICATE RESULTS ARE #{r}" 
					subresults << r
					#puts "RESULT SET IS #{puta subresults}" 
				end
				join( nodes, subresults ) {|a,o,b| a if b}
				join( mapping, subresults ) {|a,o,b| a if b}
				nodes.compact!
				mapping.compact!
			end
			#results = nodeset.collect{ false }
			results = []
			mapping.each{|ind| results[ind] = true}
			results << false while results.size < nodeset.size
			#puts "PREDICATE RETURNING #{puta results}" 
			[path, results]
		end

		def join( arg1, op, arg2=nil)
			return nil unless arg1 and op
			op, arg2 = arg2, op unless arg2
			arg2 = [arg2] unless arg2.kind_of? Array
			if arg1.size == arg2.size
				arg1.each_index { |ind| arg1[ind] = yield(arg1[ind], op, arg2[ind]) }
			else
				arg1.collect! { |item| yield(item, op, arg2[0]) }
			end
			arg1
		end

		def replace_groups( path, groups=nil )
			return nil unless path
			if groups
				groups.each_index do |index|
					path[/\(#{index}\)/] = groups[index]
				end
				path
			else
				count = 0
				left = ""
				args = []

				while path =~ /(.*?)(?=\(|\[)/
					left = left + $1 + "(#{count})"
					right = $'
					count += 1
					path, arg = get_group( right )
					args << arg
				end
				left += path if path and path.length > 0
				[left, args]
			end
		end

		# get_paren( '[foo]bar' ) -> ['bar', '[foo]']
		def get_group string
			ind = 0
			depth = 0
			st = string[0,1]
			en = (st == "(" ? ")" : "]")
			begin
				case string[ind,1]
				when st
					depth += 1
				when en
					depth -= 1
				end
				ind += 1
			end while depth > 0 and ind < string.length
			return nil unless depth==0
			[string[ind..-1], string[0..ind-1]]
		end
		
		def split_ignoring_groups path, re
			path, groups = replace_groups( path )
			path =~ re
			left = $1
			op = $2
			right = $'
			left = replace_groups( left, groups )
			right = replace_groups( right, groups )
			[left,op,right]
		end

		def puta( arry )
			return "\n\t"+arry.type.to_s unless arry.kind_of? Enumerable
			rv = " #{arry.type.to_s} "
			rv << arry.name if arry.kind_of? Element
			arry.each { |n|
				rv << "\n\t"
				rv << n.to_s if n.kind_of? Numeric
				rv << ' '
				rv << n.type.to_s
				rv << ' '
				rv << n.name if n.kind_of? Element
				rv << "'#{n}'" if n.kind_of? String or n.kind_of? Fixnum
				rv << " "
				rv << n.attributes.values.collect{|v|v.to_s}.to_s if n.kind_of? Element
			}
			rv
		end

		def parse_args( string )
			#puts "parse_args '#{string}'" 
			arguments = []
			ind = 0
			depth = 1
			begin
				case string[ind]
				when ?(
					depth += 1
					if depth == 1
						string = string[1..-1]
						ind -= 1
					end
				when ?)
					depth -= 1
					if depth == 0
						s = string[0,ind].strip
						arguments << s unless s == ""
						string = string[ind+1..-1]
					end
				when ?,
					if depth == 1
						s = string[0,ind].strip
						arguments << s unless s == ""
						string = string[ind+1..-1]
						ind = 0
					end
				end
				ind += 1
			end while depth > 0 and ind < string.length
			return nil unless depth==0
			[string,arguments]
		end

		def recurse( nodeset, &block )
			#puts "RECURSE" 
			nodeset.each do |node|
				yield node
				recurse( node, &block ) if node.kind_of? Element
			end
		end

		def equality_relational_compare( set1, op, set2 )
			#puts "COMPARING #{set1} (#{set1.type}) #{op} #{set2} (#{set2.type})" 
			if set1.kind_of? Array and set2.kind_of? Array
				if set1.size == 1 and set2.size == 1
					set1 = set1[0]
					set2 = set2[0]
				else
					# Compare two sets
					set1.each{|i1| 
						set2.each{|i2| 
							return true if i1.to_s.send(op, i2.to_s) 
						} 
					}
					return false
				end
			end
			#puts "COMPARING VALUES"
			# If one is nodeset and other is number, compare number to each item
			# in nodeset s.t. number op number(string(item))
			# If one is nodeset and other is string, compare string to each item
			# in nodeset s.t. string op string(item)
			# If one is nodeset and other is boolean, compare boolean to each item
			# in nodeset s.t. boolean op boolean(item)
			if set1.kind_of? Array or set2.kind_of? Array
				if set1.kind_of? Array
					a = set1
					b = set2.to_s
				else
					a = set2
					b = set1.to_s
				end

				block = nil
				case b
				when 'true', 'false'
					b = Functions::boolean( b )
					block = proc{|v| return true if Functions::boolean(v).send(op,b)}
				when /^\d+(\.\d+)?$/
					b = Functions::number( b )
					block = proc{|v| return true if Functions::number(v).send(op,b)}
				else
					b = Functions::string( b )
					block = proc{|v| return true if Functions::string(v).send(op,b)}
				end
				a.each( &block )
			else
				# If neither is nodeset,
				#   If op is = or !=
				#     If either boolean, convert to boolean
				#     If either number, convert to number
				#     Else, convert to string
				#   Else
				#     Convert both to numbers and compare
				if op == '==' or op == '!='
					set1 = set1.to_s
					set2 = set2.to_s
					if set1 == 'true' or set1 == 'false' or set2 == 'true' or set2 == 'false'
						set1 = Functions::boolean( set1 )
						set2 = Functions::boolean( set2 )
					elsif set1 =~ /^\d+(\.\d+)?$/ or set2 =~ /^\d+(\.\d+)?$/
						set1 = Functions::number( set1 )
						set2 = Functions::number( set2 )
					else
						set1 = Functions::string( set1 )
						set2 = Functions::string( set2 )
					end
				else
					set1 = Functions::number( set1 )
					set2 = Functions::number( set2 )
				end
				return [set1.send(op, set2)]
			end
			return false
		end

		# Builds a nodeset of all of the following nodes of the supplied node,
		# in document order
		def following( node )
			siblings = [node]
			while node.next_sibling
				node = node.next_sibling
				siblings << node
			end
			following = []
			recurse( siblings ) { |node| following << node }
			following.shift
			#puts "following is returning #{puta following}"
			following
		end

		# Builds a nodeset of all of the preceding nodes of the supplied node,
		# in reverse document order
		def preceding( node )
			siblings = []
			while node.previous_sibling
				node = node.previous_sibling
				siblings << node
			end
			siblings.reverse!
			preceding = []
			recurse( siblings ) { |node| preceding << node }
			preceding.reverse
		end
	end
end
