=begin script

include_path: standard_shape_K_links.rb
description: This is a standard network stressor which would take six parameters.
             start_tag - tag symbol after which to start stress.
             start_delay - delay after start tag.
             end_tag - tag symbol before which to stop stress.
             duration - duration of stress
             bandwidth - value to which K's bandwidth will be set.
             ks_to_stress - array of k's to stress (no default)

=end

insert_after parameters[:start_tag] do
  if( parameters[:start_delay] != nil && parameters[:start_delay] > 0 )
    do_action "SleepFrom", parameters[:start_tag], parameters[:start_delay]
  end

  parameters[:ks_to_stress].each { |link|
     do_action "ShapeHost", link['router'], link['bandwidth'], link['target']
     do_action "InfoMessage", "ShapeHost( #{link['router']}, #{link['bandwidth']}, #{link['target']})"
  }

  at :network_stress_start

end

if( parameters[:duration] != nil && parameters[:duration] >0 )
  insert_before parameters[:end_tag] do
    do_action "SleepFrom", :network_stress_start, parameters[:duration]

    parameters[:ks_to_stress].each { |link|
       do_action "RestoreHost", link['router'], link['target']
    }
  end
end
