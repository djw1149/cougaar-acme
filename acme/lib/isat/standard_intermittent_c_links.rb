=begin script

include_path: standard_intermittent_c_links.rb
description: This is a standard network stressor which would take six parameters.
             start_tag - tag symbol after which to start stress.
             start_delay - delay after start tag.
             end_tag - tag symbol before which to stop stress.
             duration - duration of stress
             on_time - Time to keep stressor on.
             off_time - Time to keep stressor of.
             nodes - Array of nodes to stress.
=end

$IntermittentCLink = 0 if $IntermittentCLink.nil?

insert_after parameters[:start_tag] do
  if( parameters[:start_delay] != nil && parameters[:start_delay] > 0 )
    do_action "SleepFrom", parameters[:start_tag], parameters[:start_delay]
  end
  do_action "IntermittentNetworkInterfaces", "IN-C-#{$IntermittentCLink}", parameters[:on_time], parameters[:off_time], parameters[:nodes]

at :intermittentClink_network_stress_start
end

if( parameters[:duration] != nil && parameters[:duration] >0 )
  insert_before parameters[:end_tag] do
    do_action "SleepFrom", :intermittentClink_network_stress_start, parameters[:duration]
    do_action "StopCyclicStress", "IN-C-#{$IntermittentCLink}"
  end
end

$IntermittentCLink += 1

