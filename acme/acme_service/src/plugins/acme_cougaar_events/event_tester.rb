require 'event_server'

if $0==__FILE__
  parser =  Cougaar::CougaarEventService.new(3000)
  parser.start do |event|
    puts event
  end
  
  socket = TCPSocket.new("localhost", 3000)
  10000.times do
    socket.write '<CougaarEvents Node="freeride" experiment="MyExperiment">'
    socket.flush
    socket.write '<CougaarEvent type="STATUS" clusterIdentifier="FooBar" component="Bar"></CougaarEvent>'
    socket.flush
    socket.write '</CougaarEvents>'
    socket.flush
  end
  puts "done"
  sleep 5
  socket.close
  parser.stop
end