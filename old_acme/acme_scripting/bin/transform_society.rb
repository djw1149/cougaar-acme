#! /usr/bin/env ruby

=begin
 * <copyright>  
 *  Copyright 2001-2004 InfoEther LLC  
 *  Copyright 2001-2004 BBN Technologies
 *
 *  under sponsorship of the Defense Advanced Research Projects  
 *  Agency (DARPA).  
 *   
 *  You can redistribute this software and/or modify it under the 
 *  terms of the Cougaar Open Source License as published on the 
 *  Cougaar Open Source Website (www.cougaar.org <www.cougaar.org> ).   
 *   
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
 *  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
 *  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR 
 *  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT 
 *  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
 *  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT 
 *  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
 *  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY 
 *  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
 *  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
 *  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 * </copyright>  
=end

path = Dir.pwd.split("/")[0...(Dir.pwd.split("/").index("acme_scripting"))]
dir1 = ( ( path + ['src', 'ruby', 'acme_scripting', 'src', 'lib'] ).join("/") )
dir2 = ( ( path + ['src', 'ruby', 'acme_service', 'src', 'redist'] ).join("/") )
dir1 = ( ( path + ['acme_scripting', 'src', 'lib'] ).join("/") ) unless File.exist?(dir1)
dir2 = ( ( path + ['acme_service', 'src', 'redist'] ).join("/") ) unless File.exist?(dir2)
$:.unshift dir1 if File.exist?(dir1)
$:.unshift dir2 if File.exist?(dir2)


require 'cougaar/scripting'
require 'cougaar/communities'
require 'getoptlong'

opts = GetoptLong.new( [ '--input',	'-i',		GetoptLong::REQUIRED_ARGUMENT],
                      [ '--layout', '-l', GetoptLong::REQUIRED_ARGUMENT],
                      [ '--hosts', '-h', GetoptLong::REQUIRED_ARGUMENT],
											[ '--rules', '-r', GetoptLong::REQUIRED_ARGUMENT ],
											[ '--output', '-o', GetoptLong::REQUIRED_ARGUMENT ],
                      [ '--communities', '-c', GetoptLong::REQUIRED_ARGUMENT ],
                      [ '--abort-on-warning', '-a',  GetoptLong::NO_ARGUMENT],
											[ '--help', '-?', GetoptLong::NO_ARGUMENT])

input = nil
layout = nil
hosts = nil
output = nil
communities = nil
input_type = :unknown
output_type = :unknown
abort_on_warning = false
rules = nil

def help
  puts "Transforms a society with rules (and converts between xml and ruby).\nUsage:\n\t#$0 -i <input file> -l <layout file> [-h <hosts file>] -r <rules dir> [-o <output file>] [-c <communities file>] [-?]"
  puts "\t-i --input\tThe input file (.xml or .rb)."
  puts "\t-l --layout\tThe layout file (.xml or .rb)."
  puts "\t-h --hosts\tThe hosts file (.xml or .rb)."
  puts "\t-r --rules\tThe rule directory (e.g. ./rules)."
  puts "\t-c --communities\tThe communities file to write to (e.g. communities.xml)."
  puts "\t-a --abort-on-warning\tAbort the generation of the society if a rule warning is encountered."
  puts "\t-o --output\tThe output file. (default new-<input>)"
end

opts.each do |opt, arg|
	case opt
  when '--input'
    input = arg
    input_type = :xml if (File.basename(input)!=File.basename(input, ".xml"))
    input_type = :ruby if (File.basename(input)!=File.basename(input, ".rb"))
  when '--layout'
    layout = arg
  when '--hosts'
    hosts = arg
  when '--rules'
    rules = arg
  when '--communities'
    communities = arg
  when '--output'
    output = arg
    output_type = :xml if (File.basename(output)!=File.basename(output, ".xml"))
    output_type = :ruby if (File.basename(output)!=File.basename(output, ".rb"))
  when '--abort-on-warning'
    abort_on_warning = true
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

if hosts
  unless layout
    puts "Incorrect usage...must supply layout file if using a hosts file.\n"
    help
    exit
  end
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
society = builder.society
puts "done."

if layout
  print "Laying out society with layout file #{layout}"
  print " and hosts file #{hosts}" if hosts
  puts ""
  sl = Cougaar::Model::SocietyLayout.from_society(society, layout, hosts)
  sl.layout
  print "Finished laying out society."
end
puts "Applying transformation rules from #{rules}..."
starttime = Time.now
engine = Cougaar::Model::RuleEngine.new(society)
engine.abort_on_warning = abort_on_warning
engine.enable_stdout
engine.load_rules(rules)
engine.execute
puts "Finished in #{Time.now - starttime} seconds."
puts "Writing #{output}..."
$stdout.flush
case output_type
when :ruby
  builder.to_ruby_file(output)
when :xml
  builder.to_xml_file(output)
end
if communities
  puts "Writing Communities file to: #{communities}"
  communities_xml = society.communities.to_xml
  File.open(communities, "w") { |file| file.puts communities_xml }  
end
puts "Done."
