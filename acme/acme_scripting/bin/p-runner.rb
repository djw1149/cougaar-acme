#!/usr/bin/ruby -W0

$CIP = ENV['CIP']

if $0 == __FILE__
  $:.unshift File.dirname( __FILE__ )
  $:.unshift File.join( $CIP, "csmart", "acme_service", "src", "redist" )
  $:.unshift File.join( $CIP, "csmart", "acme_scripting", "src", "lib" )
  $:.unshift File.join( $CIP, "csmart", "assessment", "scripts" )
  $:.unshift File.join( $CIP, "csmart", "assessment", "lib" )
  $:.unshift File.join( $CIP, "csmart", "config", "lib" )
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

$POLARIS_MONITOR = Polaris::Monitor.new( server )
Cougaar::ExperimentMonitor.add $POLARIS_MONITOR

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

    $POLARIS_MONITOR.scriptId = scriptId.to_i
    $POLARIS_CONFIG = Polaris::CougaarConfig.new configFile, ENV["COUGAAR_INSTALL_PATH"]

    $POLARIS_CONFIG.update if ($POLARIS_UPDATE)
   
    $POLARIS_CONFIG.update_versions 
    $POLARIS_CONFIG.versions << scriptInfo.version 
    $POLARIS_CONFIG.versions << configInfo.version 
   
    Cougaar.in_memory_society = $POLARIS_CONFIG.make_society
#    ARGV[0] = $POLARIS_CONFIG.transform_script

    logs = Polaris::Logs.new("#{ENV['COUGAAR_INSTALL_PATH']}/workspace/log4jlogs")
    
    begin
      load scriptFile
    rescue XMLRPC::FaultException => e
      puts "Code: #{e.faultCode}"
      puts "Msg: #{e.faultString}"
      $POLARIS_MONITOR.polaris_failure( e )
      throw e
    rescue Exception => exc
      puts "Caught ACME Exception: #{exc}"
      $POLARIS_MONITOR.acme_failure( exc )
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


