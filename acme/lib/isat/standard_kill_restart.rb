=begin script

include_path: standard_kill_restart.rb
description: kill we used in the MOAS in 2003.  Kills REAR-B-NODE, 1-AD-NODE, 123-MSB-NODE, 47-FSB-NODE, 1-35-ARBN-NODE.

=end

insert_after :during_stage_1 do
  wait_for "NodesPersistedFindProviders", "REAR-B-NODE", "1-AD-NODE", "123-MSB-NODE", "47-FSB-NODE", "1-35-ARBN-NODE" 
  do_action "InfoMessage", "##### Killing Nodes REAR-B-NODE, 1-AD-NODE, 123-MSB-NODE, 47-FSB-NODE, 1-35-ARBN-NODE #####"
  do_action "KillNodes", "REAR-B-NODE", "1-AD-NODE", "123-MSB-NODE", "47-FSB-NODE", "1-35-ARBN-NODE" 

  do_action "Sleep", 5.minutes

  do_action "RestartNodes", "REAR-B-NODE", "1-AD-NODE", "123-MSB-NODE", "47-FSB-NODE", "1-35-ARBN-NODE"

end
