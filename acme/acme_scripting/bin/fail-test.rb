#!/usr/bin/ruby

$CIP = ENV['CIP']

if $0 == __FILE__
  $:.unshift File.dirname( __FILE__ )
  $:.unshift File.join( File.dirname( __FILE__ ), "..", "..", "acme_service", "src", "redist" )
  $:.unshift File.join( File.dirname( __FILE__ ), "..", "src", "lib" )
  $:.unshift File.join( $CIP, "csmart", "assessment", "lib" )
  $:.unshift File.join( $CIP, "csmart", "config", "lib" )
  $:.unshift File.join( $CIP, "csmart", "assessment", "scripts" )
#  $:.unshift File.join( $CIP, "csmart", "acme_service", "src", "redist" )
#  $:.unshift File.join( $CIP, "csmart", "acme_scripting", "src", "lib" )
end

$stdout.sync = true


require "p-config"

require "xmlrpc/client"

host = ARGV[0]
testId = ARGV[1]

server = XMLRPC::Client.new( host, "/servlet/xml-rpc" )
server.set_parser(XMLRPC::XMLParser::REXMLStreamParser.new)



puts "[#{Time.now}] Failing Test: #{testId}"


description = ""
puts "Type the reason for failing this test, and press ^D (^Z in Windows) to finish."
  
$stdin.each do |line|
    description = description + line
end

server.call("remote.addObservation", testId.to_i, "OPERATOR", description)
server.call("remote.finishRun", testId.to_i, 0)