SOCIETY_FILE =  'ping-society.xml'
HOST_FILE =     'ping-hosts.xml'
LAYOUT_FILE =   'ping-layout.xml'

begin
  require 'cougaar/scripting'
rescue LoadError => e
  $:.unshift File.join('..', '..', 'src', 'lib')
  $:.unshift File.join('..', '..', '..', 'acme_service', 'src', 'redist')
  require 'cougaar/scripting'
end

require './ping-actions.rb'

require 'socket'
require 'rexml/document'

Cougaar::ExperimentMonitor.enable_stdout
Cougaar::ExperimentMonitor.enable_logging

Cougaar.new_experiment("MiniPing-Test").run(10) {

  # read the basic society definition
  #
  # also see the "create_society.rb" class, which illustrates how
  # to create a society from scratch within ruby.
  # useage: do_action "BuildSocietyFromScratch", "MiniPing"
  do_action "LoadSocietyFromXML", SOCIETY_FILE

  # transform the basic society to use our host-node layout
  do_action "LayoutSociety", LAYOUT_FILE, HOST_FILE

  # add the community plugins
  do_action "SetupCommunityPlugins"

  # add a ping from AgentA to AgentB, and have it generate event
  # statistics once every 10 seconds
  # 
  # see the org.cougaar.core.mobility.ping.PingAdderPlugin for
  # additional options.
  do_action "AddPing", "AgentA", "AgentB", {'eventMillis' => '10000'}

  # add the ping manager plugins
  #
  # A ping manager is required for every agent that contains a
  # ping adder plugin.  This rule searches for the agents and
  # adds the manager plugins.
  #
  # The "1000" is the time between ping timeout and event checks.
  # One second is fine for most tests.
  do_action "SetupPingTimers", 1000

  # load local rules (ping_env.rule)
  do_action "TransformSociety", false, "."

  # optional: save the society to an XML file for easy debugging
  do_action "SaveCurrentSociety", "savedSociety.xml"

  # start jabber
  #
  # replace the last parameter with your jabber server's host name 
  do_action "StartCommunications"

  do_action "VerifyHosts"

  # optional: print the cougaar events
  #
  # this will also print the ping statistics events
  do_action "GenericAction" do |run| 
     run.comms.on_cougaar_event do |event| 
       puts event 
     end 
  end 

  do_action "StartSociety"

  # however long you want to run
  #do_action "Sleep", 1.minutes
  do_action "Sleep", 20.seconds

  do_action "StopSociety"
  do_action "StopCommunications"
}
