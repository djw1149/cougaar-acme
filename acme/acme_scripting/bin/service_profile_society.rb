#! /usr/bin/env ruby
$:.unshift Dir.pwd.split("/")[0..(Dir.pwd.split("/").index("acme_scripting"))].push("src").push("lib").join("/")
$:.unshift Dir.pwd.split("/")[0..(Dir.pwd.split("/").index("acme_scripting")-1)].push('acme_service').push("src").push("redist").join("/")

require 'cougaar/society_builder'
require 'cougaar/society_model'
require 'cougaar/society_rule_engine'
require 'getoptlong'

opts = GetoptLong.new( [ '--input', '-i',       GetoptLong::REQUIRED_ARGUMENT],
                       [ '--output', '-o', GetoptLong::REQUIRED_ARGUMENT ],
                       [ '--help', '-h', GetoptLong::NO_ARGUMENT])

input = nil
output = nil
input_type = :unknown
input_basename = nil

def help
  puts "Produces agent.profile.daml files\nUsage:\n\t#$0 -i <input file> [-o <output file>] [-h]"
  puts "\t-i --input\tThe input file (.xml or .rb)."
  puts "\t-o --output\tThe output file. (default <input>.service_profile)"
  puts "\t-h --help\tThis help text."
end

opts.each do |opt, arg|
	case opt
  when '--input'
    input = arg
    if (File.basename(input)!=File.basename(input, ".xml"))
      input_type = :xml 
      input_basename = File.basename(input, ".xml")
    elsif (File.basename(input)!=File.basename(input, ".rb"))
      input_type = :ruby 
      input_basename = File.basename(input, ".rb")
    end
  when '--output'
    output = arg
  when '--help'
    help
    exit 0
	end
end

unless (input)
  puts "Incorrect usage...must supply input file name.\n"
  help
  exit
end

if (input_type==:unknown)
  puts "Unknown file type on input.  Must be .xml or .rb."
  exit
end

unless File.exist?(input)
  puts "Cannot find file: #{input}"
  exit
end

unless output
  output = input_basename + ".service_profile"
end

# Output the Service Profile

print "Loading #{input}..."
$stdout.flush
starttime = Time.now
builder = case input_type
when :ruby
  Cougaar::SocietyBuilder.from_ruby_file(input)
when :xml
  Cougaar::SocietyBuilder.from_xml_file(input)
end
soc = builder.society
puts "done."
outfile = File.open(output, "wb")
puts "Writing #{output}..."
first_agent = true
soc.each_agent do |agent|
  has_roles = false
  agent.each_facet( :role ) { | role | has_roles = true }
  if has_roles
    outfile.puts unless first_agent
    first_agent = false
    outfile.puts "agentName = " + agent.name
    first_role = true
    agent.each_facet(:role) do |facet|
      outfile.puts "---" unless first_role
      first_role = false
      outfile.puts "roleName = " + facet[:role] + "," + facet[:echelon_of_support]
    end
  end
end

puts "finished in #{Time.now - starttime} seconds."
outfile.flush
$stdout.flush
puts "done."
