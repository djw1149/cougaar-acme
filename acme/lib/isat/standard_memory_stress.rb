=begin script

include_path: standard_intermittent_c_links.rb
description: This is a standard network stressor which would take six parameters.
             start_tag - tag symbol after which to start stress.
             start_delay - delay after start tag.
             end_tag - tag symbol before which to stop stress.
             duration - duration of stress
             memory - Amount of memory to waste.
             nodes - Array of nodes to stress.
=end

$IntermittentCLink = 0 unless $IntermittentCLink > 0

insert_after parameters[:start_tag] do
  if( parameters[:start_delay] != nil && parameters[:start_delay] > 0 )
    do_action "SleepFrom", parameters[:start_tag], parameters[:start_delay]
  end
  do_action "WasteMemory", parameters[:memory], parameters[:nodes]

at :cyclic_network_stress_start
end

if( parameters[:duration] != nil && parameters[:duration] >0 )
  insert_before parameters[:end_tag] do
    do_action "SleepFrom", :cpu_stress_start, parameters[:duration]
  end
  do_action "WasteMemory", "0", parameters[:nodes]
end

$IntermittentCLink += 1

