#!/usr/bin/ruby

if $0 == __FILE__
  $:.unshift File.dirname( __FILE__ )
  $:.unshift File.join( File.dirname( __FILE__ ), "..", "..", "acme_service", "src", "redist" )
  $:.unshift File.join( File.dirname( __FILE__ ), "..", "src", "lib" )
end

require "p-config"

require "cougaar/scripting"
require "ultralog/scripting"
require "polaris/tools"

require "xmlrpc/client"
require "cvs-info"

scriptFile = ARGV[0]
configFile = ARGV[1]

server = XMLRPC::Client.new( $POLARIS_HOST, "/servlet/xml-rpc" )
server.set_parser(XMLRPC::XMLParser::REXMLStreamParser.new)


scriptInfo = CVSInfo.new( scriptFile )
if (!scriptInfo.committed?) then
  puts "You must run p-run.rb within a CVS heirarchy, or check in your script"
  exit -1
end

testId = server.call("remote.lookupTest", scriptInfo.root, scriptInfo.repository, scriptInfo.file_name)

puts "[#{Time.now}] Starting Registered Test: #{scriptInfo.file_name}/#{testId}"

config = Polaris::CougaarConfig.new configFile, ENV["COUGAAR_INSTALL_PATH"]
if ($POLARIS_UPDATE)
  puts "[#{Time.now}] Begining cougaar.update"
  config.update
  puts "[#{Time.now}] cougaar.update Finished"
else
  puts "[#{Time.now}] Skipping cougaar.update"
end

puts "[#{Time.now}] Transforming . . ."
ARGV[0] = config.transform_script

puts "[#{Time.now}] . . . Done.  Results in #{ARGV[0]}"

puts "[#{Time.now}] Watching Log Files"
logs = Polaris::Logs.new("#{ENV['COUGAAR_INSTALL_PATH']}/workspace/log4jlogs")

puts "[#{Time.now}] Adding Polaris Monitor"
monitor = Polaris::Monitor.new testId, server
Cougaar::ExperimentMonitor.add monitor

begin
  puts "[#{Time.now}] Starting Experiment"
  load scriptFile
  puts "[#{Time.now}] Experiment Finished"
end


