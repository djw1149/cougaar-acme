#!/usr/bin/ruby

if $0 == __FILE__
  $:.unshift File.dirname( __FILE__ )
  $:.unshift File.join( File.dirname( __FILE__ ), "..", "..", "acme_service", "src", "redist" )
  $:.unshift File.join( File.dirname( __FILE__ ), "..", "src", "lib" )
end

require "p-config"

require "xmlrpc/client"
require "rexml/document"

require "cougaar/scripting"
require "ultralog/scripting"
require "polaris/tools"

require "cvs-info"

queue = ARGV[0].to_i

server = XMLRPC::Client.new( $POLARIS_HOST, "/servlet/xml-rpc" )
server.set_parser(XMLRPC::XMLParser::REXMLStreamParser.new)

monitor = Polaris::Monitor.new( server )
Cougaar::ExperimentMonitor.add monitor

playground = CVSPlayground.new

@@is_OK = true

while (@@is_OK) do
  trap("SIGINT") {
    exit
  }

  sleep 30 # Sleep for 1 minute.
  begin
    taskDescription = server.call("remote.startNextTask", queue)

    taskDoc = REXML::Document.new( taskDescription )
    scriptId = taskDoc.elements["task/script"].attributes["id"]
    configId = taskDoc.elements["task/config"].attributes["id"]

    scriptInfo = CVSInfo.new( taskDoc.elements["task/script/cvs"] )
    configInfo = CVSInfo.new( taskDoc.elements["task/config/cvs"] )

    scriptFile = playground.get_file( scriptInfo )
    configFile = playground.get_file( configInfo )

    monitor.scriptId = scriptId.to_i
    config = Polaris::CougaarConfig.new configFile, ENV["COUGAAR_INSTALL_PATH"]

    config.update if ($POLARIS_UPDATE)
     
    ARGV[0] = config.transform_script

    logs = Polaris::Logs.new("#{ENV['COUGAAR_INSTALL_PATH']}/workspace/log4jlogs")
    
    begin
      load scriptFile
    rescue XMLRPC::FaultException => e
      puts "Code: #{e.faultCode}"
      puts "Msg: #{e.faultString}"
      throw e
    rescue Exception => exc
      puts "Caught ACME Exception: #{exc}"
      monitor.acme_failure( exc )
      throw exc
    end

  rescue XMLRPC::FaultException => e
    match = /NoSuchElementException/.match( e.faultString )
    raise e if (match.nil?)

    trap("SIGINT") {
	exit
    }

    sleep 1*60
  end
end


