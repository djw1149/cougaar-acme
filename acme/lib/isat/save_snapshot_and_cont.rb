=begin script

include_path: save_snapshot_and_cont.rb
description: Saves a persistence snapshot but keeps running

=end

insert_after parameters[:snapshot_location] do
#  do_action "FreezeSociety"
  do_action "Sleep", 10.minutes
  do_action "SynchronizeSocietyTime"
  do_action "SavePersistenceSnapshot", parameters[:snapshot_name]
#  do_action "ThawSociety"
#  do_action "Sleep", 1.minutes
end
