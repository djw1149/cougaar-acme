=begin script

include_path: save_snapshot.rb
description: Stops a society and saves a persistence snapshot
             snapshot_location - point after which to stop the society and save snapshot

=end

insert_after parameters[:snapshot_location].intern do
  do_action "FreezeSociety"
  at :datagrabber_here
  do_action "Sleep", 10.minutes
  do_action "SynchronizeSocietyTime"
  do_action "StopSociety"
  do_action "SavePersistenceSnapshot", parameters[:snapshot_name]
  do_action "StopCommunications"
  do_action "StopRun"
end

file = File.join(ENV['CIP'], 'csmart', 'lib', 'isat', 'datagrabber_include.rb')
include file, {:location => :datagrabber_here}
