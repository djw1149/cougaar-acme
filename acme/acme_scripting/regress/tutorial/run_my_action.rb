$:.unshift "../../src/lib"

require "cougaar/scripting"
require "my_action"
require "my_state"

def testThis(name)
  puts "Test #{name}"
end

Cougaar::ExperimentMonitor.enable_stdout

Cougaar.new_experiment("RunMyAction").run {
  do_action "MyFirstAction", "Richard"
  do_action "GenericAction" do
    testThis("Foobar")
  end
  wait_for "MyFirstState", 3.seconds do
    do_action "ExperimentFailed", "Timed out in my first state"
  end
  do_action "ExperimentSucceeded"
}

