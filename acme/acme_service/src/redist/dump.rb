#!/usr/local/bin/ruby -w

# ver.0.1 create
# ver.0.2 print -> buffering thanx to nahi

module Debug
	DumpFormat = {
		"o4" => [ ' %011o', '' ],
		"o2" => [ ' %06o',  '' ],
		"o1" => [ ' %03o',  '    ' ],
		"d4" => [ ' %10d',  '' ],
		"d2" => [ ' %5d',   '' ],
		"d1" => [ ' %3d',   '    ' ],
		"x4" => [ ' %08x',  '' ],
		"x2" => [ ' %04x',  '' ],
		"x1" => [ ' %02x',  '   ' ]
	}
	UnpackFormat = {
		4 => [ 'N', 'V' ],
		2 => [ 'n', 'v' ],
		1 => [ 'C', 'C' ]
	}

	def dump(buf, param = "x2", bigendian = false, width = 16, offset0 = 0)
		raise "Not suppored dump format '#{param}'" unless DumpFormat.has_key?(param)
		result = ""

		format = param[0, 1]
		datasize = param[1, 1].to_i
		raise "Width must be > 0" unless width > 0
		raise "Width must be any times by #{datasize}" if width % datasize > 0

		dumpfmt0, alignfmt = DumpFormat[param]
		unpackfmt, unpackfmt2 = UnpackFormat[datasize]
		unpackfmt = unpackfmt2 unless bigendian

		chunk = buf[offset0..-1]
		dumpsize = chunk.size
		dumpfmt = dumpfmt0 * (width / datasize)

		(dumpsize / width).times do |i|
			offset = i * width
			buf = chunk[offset, width]
			bin = buf.unpack("#{unpackfmt}*")
			result += sprintf('%07' + format + dumpfmt, offset + offset0, *bin)
			result += '  ' + buf.tr("\000-\037\177", '.') if datasize == 1
			result += "\n"
		end

		fragment = dumpsize % width
		if fragment > 0
			offset = dumpsize - fragment
			buf = chunk[offset, fragment]
			buf0 = buf.dup
			fraalign = fragment % datasize
			if fraalign > 0
				fraalign = datasize - fraalign
				if bigendian
				#	buf0[fragment + fraalign - (datasize - fraalign) - 1, 0] = "\0" * fraalign
					buf0 += "\0" * fraalign	 # ???
				else
					buf0 += "\0" * fraalign
				end
			end
			bin = buf0.unpack("#{unpackfmt}*")
			result += sprintf('%07' + format + dumpfmt0 * bin.size, offset + offset0, *bin)
			if datasize == 1
				alignment = width - fragment
				result += alignfmt * alignment
				result += '  ' + buf.tr("\000-\037\177", '.') + ' ' * alignment
			end
			result += "\n"
		end
		result += sprintf("%07x\n", dumpsize)

		result
	end

	module_function :dump
end

class String
	def datadump
		Debug::dump(self, "x1")
	end
end

if __FILE__ == $0
	while gets
		print Debug::dump($_)
		print $_.datadump
	end
end

