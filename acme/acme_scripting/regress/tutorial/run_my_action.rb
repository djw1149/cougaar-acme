$:.unshift "../../src/lib"

require "cougaar/scripting"
require "my_action"
require "my_state"

Cougaar::ExperimentMonitor.enable_stdout

Cougaar.new_experiment("RunMyAction").run {
  do_action "MyFirstAction", "Richard"
  wait_for "MyFirstState", 10.seconds
}

