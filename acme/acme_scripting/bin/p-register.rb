#!/usr/bin/ruby

if $0 == __FILE__
  $:.unshift File.dirname( __FILE__ )
  $:.unshift File.join( File.dirname( __FILE__ ), "..", "..", "acme_service", "src", "redist" )
  $:.unshift File.join( File.dirname( __FILE__ ), "..", "src", "lib" )
end

require "p-config"
require "xmlrpc/client"
require "cvs-info"

begin
  # Read in the Arguments to the Command
  state = "READY"
  name = "(none)"
  file_name = nil

  ARGV.each { |arg|
    case state
      when /READY/ then
        case arg
          when /-f/, /--file/ then
            state = "FILE"
          when /-n/, /--name/ then
            state = "NAME"
          else
            file_name = arg
        end
      when /FILE/ then
        file_name = arg
        state = "READY"
      when /NAME/ then
        name = arg
        state = "READY"
    end
  }


  cvsInfo = CVSInfo.new( file_name )
  if (!cvsInfo.committed?) then
    puts "Please check in your script before registering with Polaris."
    exit -1
  end

  description = ""
  puts "Type the Test Description, and press ^D (^Z in Windows) to finish."
  
  $stdin.each do |line|
    description = description + line
  end
  
  server = XMLRPC::Client.new( $POLARIS_HOST, "/servlet/xml-rpc" )
  server.set_parser(XMLRPC::XMLParser::REXMLStreamParser.new)

  result = server.call("remote.registerTest", name, description, cvsInfo.root, cvsInfo.repository, cvsInfo.file_name)

#  puts "#{result}"

rescue XMLRPC::FaultException => e
  puts "Error: " 
  puts e.faultCode
  puts e.faultString
end
