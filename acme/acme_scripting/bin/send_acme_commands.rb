#! /usr/bin/env ruby
path = Dir.pwd.split("/")[0...(Dir.pwd.split("/").index("acme_scripting"))]
dir1 = ( ( path + ['src', 'ruby', 'acme_scripting', 'src', 'lib'] ).join("/") )
dir2 = ( ( path + ['src', 'ruby', 'acme_service', 'src', 'redist'] ).join("/") )
dir1 = ( ( path + ['acme_scripting', 'src', 'lib'] ).join("/") ) unless File.exist?(dir1)
dir2 = ( ( path + ['acme_service', 'src', 'redist'] ).join("/") ) unless File.exist?(dir2)
$:.unshift dir1 if File.exist?(dir1)
$:.unshift dir2 if File.exist?(dir2)

require 'optparse'

options = {}
ARGV.options do |opts|
  opts.on_tail("--help", "show this message") {puts opts; exit}
  opts.on('--host HOST', "host to send command to") {|options[:host]|}
  opts.on('--command COMMAND', "command to send") {|options[:command]|}
  opts.parse!
end

host = options[:host]
command = options[:command]

unless command
  puts "ERROR: Please specify --command 'command text'"
  exit
end

require 'cougaar/scripting'
require 'cougaar/message_router'
require 'ultralog/scripting'

society = Ultralog::OperatorUtils::HostManager.new.load_society

unless host
  begin
    chost = society.get_service_host("message-router")
    host = chost.host_name
  rescue
    puts "ERROR: No --host <host> specified and cannot locate host via hosts xml file"
    exit
  end
end

client = InfoEther::MessageRouter::Client.new("CommandLineInterface", host)
client.start

society.each_service_host("acme") do |acme_host|
  reply = client.new_message(acme_host.host_name).set_body("command[#{command}]").request
  puts "#{acme_host.host_name} - #{reply.body}"
end

client.stop