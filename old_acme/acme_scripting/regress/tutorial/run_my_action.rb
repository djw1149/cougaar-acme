$:.unshift "../../src/lib"

require "cougaar/scripting"
require "my_action"
require "my_state"

require 'cougaar/message_router'
@port = 5555
@service = InfoEther::MessageRouter::Service.new(@port)
@service.start

Cougaar::ExperimentMonitor.enable_stdout
Cougaar::ExperimentMonitor.enable_logging

Cougaar.new_experiment("RunMyAction").run {

  #set_archive_path(".")
  
  do_action "StartMessageRouterCommunications", "localhost", 5555

  wait_for "Command", "shutdown"
  
  do_action "MyFirstAction", "alpha"

  at :stage_1_ready

  do_action "MySecondAction", "beta"

  at :stage_2_ready
  
  do_action "ExperimentSucceeded"
  
}

