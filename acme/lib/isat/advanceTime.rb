=begin script

include_path: advanceTime.rb
description: does the advance time between stages. Give it the time to advance, a la 16.days

=end

insert_after parameters[:advance_location] do
  do_action "InfoMessage", "Advancing time #{parameters[:days]}, 1 day steps, quiescing between steps"
  do_action "AdvanceTime", parameters[:days].days
#  include "post_stage_data.inc", "PostAdvanceAt#{parameters[:advance_location]}"
end

