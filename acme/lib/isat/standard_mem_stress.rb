=begin script

include_path: standard_memory_stress.rb
description: This is a standard memory stressor which would take six parameters.
             start_tag - tag symbol after which to start stress.
             start_delay - delay after start tag.
             end_tag - tag symbol before which to stop stress.
             duration - duration of stress
             memory - Amount of memory to waste in "K".
             nodes - Array of nodes to stress.
=end


insert_after parameters[:start_tag] do
  if( parameters[:start_delay] != nil && parameters[:start_delay] > 0 )
    do_action "SleepFrom", parameters[:start_tag], parameters[:start_delay]
  end
  do_action "WasteMemory", parameters[:memory], parameters[:nodes]

at :standard_memory_stress_start
end

if( parameters[:duration] != nil && parameters[:duration] >0 )
  insert_before parameters[:end_tag] do
    do_action "SleepFrom", :standard_memory_stress_start, parameters[:duration]
  end
  do_action "WasteMemory", "0", parameters[:nodes]
end


