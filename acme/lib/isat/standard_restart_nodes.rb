=begin script

include_path: standard_restart_nodes.rb
description: This is a standard restart nodes stressor which would take three parameters.
             start_tag - tag symbol after which to restart nodes.
             start_delay - delay after start tag.
             nodes_to_restart - array of nodes to restart.

=end

insert_after parameters[:start_tag] do
  if( parameters[:start_delay] != nil && parameters[:start_delay] > 0)
    do_action "SleepFrom", parameters[:start_tag], parameters[:start_delay]
  end
  do_action "InfoMessage", "##### ReStarting Agents #{parameters[:nodes_to_restart].join(',')} #####"
  do_action "RestartNodes", *parameters[:nodes_to_restart]
end
