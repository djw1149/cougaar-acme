#! /usr/bin/env ruby
$:.unshift Dir.pwd.split("/")[0..(Dir.pwd.split("/").index("acme_scripting"))].push("src").push("lib").join("/")

require 'cougaar/scripting'
require 'cougaar/society_rule_engine'
require 'getoptlong'

opts = GetoptLong.new( [ '--input',	'-i',		GetoptLong::REQUIRED_ARGUMENT],
											[ '--rules', '-r', GetoptLong::REQUIRED_ARGUMENT ],
											[ '--output', '-o', GetoptLong::REQUIRED_ARGUMENT ],
											[ '--help', '-h', GetoptLong::NO_ARGUMENT])

input = nil
output = nil
input_type = :unknown
output_type = :unknown
rules = nil

def help
  puts "Transforms a society with rules (and converts between xml and ruby).\nUsage:\n\t#$0 -i <input file> -r <rules dir> [-o <output file>] [-h]"
  puts "\t-i --input\tThe input file (.xml or .rb)."
  puts "\t-r --rules\tThe rule directory (e.g. ./rules)."
  puts "\t-o --output\tThe output file. (default new-<input>)"
end

opts.each do |opt, arg|
	case opt
  when '--input'
    input = arg
    input_type = :xml if (File.basename(input)!=File.basename(input, ".xml"))
    input_type = :ruby if (File.basename(input)!=File.basename(input, ".rb"))
  when '--rules'
    rules = arg
  when '--output'
    output = arg
    output_type = :xml if (File.basename(output)!=File.basename(output, ".xml"))
    output_type = :ruby if (File.basename(output)!=File.basename(output, ".rb"))
  when '--help'
    help
    exit 0
	end
end

unless (input && rules)
  puts "Incorrect usage...must supply input file name and rule directory.\n"
  help
  exit
end

unless output
  output = "new-"+File.basename(input)
  output_type = input_type
end

if (input_type==:unknown || output_type==:unknown)
  puts "Unknown file type on input or output.  Must be .xml or .rb."
  exit
end

unless File.exist?(input)
  puts "Cannot find file: #{input}"
  exit
end

unless File.directory?(rules)
  puts "Cannot find rules directory: #{rules}"
  exit
end

# TRANSFORM SOCIETY

print "Loading #{input}..."
$stdout.flush
builder = case input_type
when :ruby
  Cougaar::SocietyBuilder.from_ruby_file(input)
when :xml
  Cougaar::SocietyBuilder.from_xml_file(input)
end
builder.society
puts "done."
print "Applying transformation rules from #{rules}..."
$stdout.flush
starttime = Time.now
engine = Cougaar::Model::RuleEngine.new(builder.society)
engine.enable_stdout
engine.load_rules(rules)
engine.execute
puts "finished in #{Time.now - starttime} seconds."
puts "Writing #{output}..."
$stdout.flush
case output_type
when :ruby
  builder.to_ruby_file(output)
when :xml
  builder.to_xml_file(output)
end
puts "done."