#!/usr/bin/ruby -W0

# $stdout.sync = true

if $0 == __FILE__
  $:.unshift File.dirname( __FILE__ )
  $:.unshift File.join( $CIP, "csmart", "acme_service", "src", "redist" )
  $:.unshift File.join( $CIP, "csmart", "assessment", "lib" )
  $:.unshift File.join( $CIP, "csmart", "assessment", "scripts" )
  $:.unshift File.join( $CIP, "csmart", "config", "lib" )
  $:.unshift File.join( $CIP, "csmart", "acme_scripting", "src", "lib" )
end

require "p-config"

require "cougaar/scripting"
require "ultralog/scripting"
require "assessment/scripting"
require "framework/scripting"
require "polaris/tools"

require "xmlrpc/client"
require "cvs-info"

scriptFile = ARGV[0]
configFile = ARGV[1]

server = XMLRPC::Client.new( $POLARIS_HOST, "/servlet/xml-rpc" )
server.set_parser(XMLRPC::XMLParser::REXMLStreamParser.new)


scriptInfo = CVSInfo.new( scriptFile )
if (!scriptInfo.committed?) then
  puts "You must run p-run.rb within a CVS hierarchy, or check in your script"
  exit -1
end
begin
  testId = server.call("remote.lookupTest", scriptInfo.root, scriptInfo.repository, scriptInfo.file_name)
rescue XMLRPC::FaultException => e
  puts "Code: #{e.faultCode}"
  puts "Msg: #{e.faultString}"
  throw e
end

puts "[#{Time.now}] Starting Registered Test: #{scriptInfo.file_name}/#{testId}"

$POLARIS_CONFIG = Polaris::CougaarConfig.new configFile, ENV["COUGAAR_INSTALL_PATH"]
if ($POLARIS_UPDATE)
  puts "[#{Time.now}] Begining cougaar.update"
  $POLARIS_CONFIG.update
  puts "[#{Time.now}] cougaar.update Finished"
else
  puts "[#{Time.now}] Skipping cougaar.update"
end

$POLARIS_CONFIG.update_versions

puts "[#{Time.now}] Transforming . . ."
ARGV[0] = $POLARIS_CONFIG.transform_script

puts "[#{Time.now}] . . . Done.  Results in #{ARGV[0]}"

puts "[#{Time.now}] Watching Log Files"
logs = Polaris::Logs.new("#{ENV['COUGAAR_INSTALL_PATH']}/workspace/log4jlogs")

puts "[#{Time.now}] Adding Polaris Monitor"
monitor = Polaris::Monitor.new server
monitor.scriptId = testId

Cougaar::ExperimentMonitor.add monitor

begin
  puts "[#{Time.now}] Starting Experiment"
  $POLARIS_MONITOR = monitor

  load scriptFile

  puts "[#{Time.now}] Experiment Finished"

rescue XMLRPC::FaultException => e
  puts "Code: #{e.faultCode}"
  puts "Msg: #{e.faultString}"
  monitor.polaris_failure( e )
  throw e
rescue Exception => exc
  puts "Caught ACME Exception: #{exc}"
  begin
    monitor.acme_failure( exc )
  rescue XMLRPC::FaultException => fe
    puts "Code: #{fe.faultCode}"
    puts "Msg: #{fe.faultString}"
    throw fe
  end
  throw exc
end


