=begin script

include_path: standard_continuous_network_stress.rb
description: This is a standard network stressor which would take six parameters.
             start_tag - tag symbol after which to start stress.
             start_delay - delay after start tag.
             end_tag - tag symbol before which to stop stress.
             duration - duration of stress
             bandwidth - value to which K's bandwidth will be set.
             ks_to_stress - array of k's to stress (default=null i.e. all)

=end

insert_after parameters[:start_tag] do
  if( parameters[:start_delay] != nil && parameters[:start_delay] > 0 )
    do_action "SleepFrom", parameters[:start_tag], parameters[:start_delay]
  end
#  do_action "DegradeKs", parameters[:bandwidth], parameters[:ks_to_stress]
  do_action "DegradeKs", parameters[:ks_to_stress]
at :network_stress_start
end
if( parameters[:duration] != nil && parameters[:duration] >0 )
  insert_before parameters[:end_tag] do
    do_action "SleepFrom", :network_stress_start, parameters[:duration]
    do_action "ResetDegradeKs", parameters[:ks_to_stress]
  end
end
