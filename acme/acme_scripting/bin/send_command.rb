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
  opts.on('--expt EXPERIMENT', "experiment to send command to.") {|options[:expt]|}
  opts.on('--host HOST', "host to send command to") {|options[:host]|}
  opts.on('--command COMMAND', "command to send") {|options[:command]|}
  opts.parse!
end

host = options[:host]
command = options[:command]
expt = options[:expt]

unless command
  puts "ERROR: Please specify --command 'command text'"
  exit
end

require 'cougaar/scripting'
require 'cougaar/message_router'
require 'ultralog/scripting'

unless host
  begin
    society = Ultralog::OperatorUtils::HostManager.new.load_society
    chost = society.get_service_host("message-router")
    host = chost.host_name
  rescue
    puts "ERROR: No --host <host> specified and cannot locate host via hosts xml file"
    exit
  end
end

client = InfoEther::MessageRouter::Client.new("CommandLineInterface", host)

expts = []
client.available_clients.each do |c|
  expts << c if c =~ /[0-9]+of[0-9]+/
end

case expts.size
when 0
  puts "No experiements online to send message to."
  exit
when 1
  if expt
    if expts[0]==expt
      expt = expts[0]
    else
      puts "The following experiments are online, please specify with --expt <experiment>"
      expts.each_with_index {|e, i| puts "#{i+1}. #{e}"}
      exit
    end
  else
    expt = expts[0]
  end
else
  if expt && expts.include?(expt)
    expt = expts[0]
  else
    puts "The following experiments are online, please specify with --expt <experiment>"
    expts.each_with_index {|e, i| puts "#{i+1}. #{e}"}
    exit
  end
end

puts "Sending 'command[#{command}]' to #{host}/#{expt}"
reply = client.new_message(expt).set_body("command[#{command}]").request
puts "Reply: #{reply.body}"
client.stop