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

fullpath = File.expand_path(__FILE__)
path = fullpath.split("/")[0...(fullpath.split("/").index("config"))]
dir1 = ( ( path + ['src', 'ruby', 'acme_scripting', 'src', 'lib'] ).join("/") )
dir2 = ( ( path + ['src', 'ruby', 'acme_service', 'src', 'redist'] ).join("/") )
dir1 = ( ( path + ['acme_scripting', 'src', 'lib'] ).join("/") ) unless File.exist?(dir1)
dir2 = ( ( path + ['acme_service', 'src', 'redist'] ).join("/") ) unless File.exist?(dir2)
$:.unshift dir1 if File.exist?(dir1)
$:.unshift dir2 if File.exist?(dir2)

require 'cougaar/scripting'
require 'getoptlong'

opts = GetoptLong.new( [ '--input',	'-i',		GetoptLong::REQUIRED_ARGUMENT],
											[ '--output', '-o', GetoptLong::REQUIRED_ARGUMENT ],
											[ '--help', '-h', GetoptLong::NO_ARGUMENT])

input = nil
output = nil
input_type = :unknown
output_type = :unknown

def help
  puts "Converts society between xml and ruby.\nUsage:\n\t#$0 -i <input file> [-o <output file>] [-h]"
  puts "\t-i --input\tThe input file (.xml or .rb)."
  puts "\t-o --output\tThe output file. (default <input>.rb|.xml)"
end

opts.each do |opt, arg|
	case opt
  when '--input'
    input = arg
    input_type = :xml if (File.basename(input)!=File.basename(input, ".xml"))
    input_type = :ruby if (File.basename(input)!=File.basename(input, ".rb"))
  when '--output'
    output = arg
    output_type = :xml if (File.basename(output)!=File.basename(output, ".xml"))
    output_type = :ruby if (File.basename(output)!=File.basename(output, ".rb"))
  when '--help'
    help
    exit 0
	end
end

unless input
  puts "Incorrect usage...must supply input file name.\n"
  help
  exit
end

if input_type==:unknown
  puts "Unknown file type (#{input}).  Must be .xml or .rb\n"
  exit
end

unless output
  if input_type==:ruby
    output = File.basename(input, ".rb") + ".xml"
    output_type = :xml
  else
    output = File.basename(input, ".xml") + ".rb"
    output_type = :ruby
  end
end

if (input_type==:ruby && output_type!=:xml) || (input_type==:xml && output_type!=:ruby)
  puts "Can only convert .rb to .xml -or- .xml to .rb not #{input} to #{output}\n"
  help
  exit
end

unless File.exist?(input)
  puts "Cannot find file: #{input}\n"
  exit
end

print "Converting #{input} to #{output}..."
$stdout.flush
if input_type==:xml
  builder = Cougaar::SocietyBuilder.from_xml_file(input)
  builder.to_ruby_file(output)
else
  builder = Cougaar::SocietyBuilder.from_ruby_file(input)
  builder.to_xml_file(output)
end
puts "done."