#!/usr/bin/ruby

if $0 == __FILE__
  $:.unshift File.dirname( __FILE__ )
  $:.unshift File.join( File.dirname( __FILE__ ), "..", "..", "acme_service", "src", "redist" )
  $:.unshift File.join( File.dirname( __FILE__ ), "..", "src", "lib" )
end

require "p-config"

require "xmlrpc/client"
require "rexml/document"
require "cvs-info"

queue = ARGV[0].to_i

server = XMLRPC::Client.new( $POLARIS_HOST, "/servlet/xml-rpc" )
server.set_parser(XMLRPC::XMLParser::REXMLStreamParser.new)

playground = CVSPlayground.new

begin
  taskDescription = server.call("remote.startNextTask", queue)

  taskDoc = REXML::Document.new( taskDescription )
  scriptId = taskDoc.elements["task/script"].attributes["id"]
  configId = taskDoc.elements["task/config"].attributes["id"]

  scriptInfo = CVSInfo.new( taskDoc.elements["task/script/cvs"] )
  configInfo = CVSInfo.new( taskDoc.elements["task/config/cvs"] )

  ARGV[0] = playground.get_file( scriptInfo )
  ARGV[1] = playground.get_file( configInfo )

  puts ARGV[0]
  puts ARGV[1]

  load File.join( File.dirname( __FILE__ ), "p-run.rb" )

rescue XMLRPC::FaultException => e
  puts "Error: "
  puts e.faultCode
  puts e.faultString
end

