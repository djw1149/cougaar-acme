=begin script

include_path: datagrabber_include.rb
description: Captures the datagrabber data


=end

if parameters[:location]
  location = parameters[:location]
else
  location = :society_frozen
end 

location = location.intern unless location.kind_of?(Symbol)

insert_after location do
  do_action "StartDatagrabberService"
  do_action "ConnectToDatagrabber", "localhost" do |datagrabber|
    run = datagrabber.new_run
    run.wait_for_completion
    # Need to re-fetch the last run because its filled in now
    last_run = datagrabber.get_runs.last
    msg = "DataGrabber run #{last_run.id} assets #{last_run.assets} units #{last_run.units}"
    ExperimentMonitor.notify(ExperimentMonitor::InfoNotification.new(msg))
  end
  do_action "StopDatagrabberService"
end
