=begin script

include_path: stop_snapshot.rb
description: Stops society at some specified point
             stop_location - point after which to stop the society

=end

insert_after parameters[:stop_location] do
  do_action "StopSociety"
  do_action "StopCommunications"
  do_action "StopRun"
end
