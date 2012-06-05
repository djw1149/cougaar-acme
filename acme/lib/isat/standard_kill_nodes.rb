=begin script

include_path: standard_kill_nodes.rb
description: This is a standard kill nodes stressor which would take three parameters.
             start_tag - tag symbol after which to kill nodes.
             start_delay - delay after start tag.
             nodes_to_kill - array of nodes to kill.

=end

insert_after parameters[:start_tag] do
  if (parameters[:start_tag] == "during_stage_1")
    wait_for "NodesPersistedFindProviders", *parameters[:nodes_to_kill]
  end
  if( parameters[:start_delay] != nil && parameters[:start_delay] > 0)
    do_action "SleepFrom", parameters[:start_tag], parameters[:start_delay]
  end
  do_action "InfoMessage", "##### Killing Agents #{parameters[:nodes_to_kill].join(',')} #####"
  do_action "KillNodes", *parameters[:nodes_to_kill]
end
