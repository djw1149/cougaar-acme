=begin script

include_path: standard_move.rb
description: MOVES we used in the MOAS in 2003

=end

insert_after :after_stage_1 do

  do_action "InfoMessage", "##### Moving AGENTS to other  NODES ######"
  do_action "MoveAgent", "1-35-ARBN.2-BDE.1-AD.ARMY.MIL", "AVNBDE-1-AD-NODE"
  do_action "MoveAgent", "1-6-INFBN.2-BDE.1-AD.ARMY.MIL", "1-BDE-1-AD-NODE"
  do_action "MoveAgent", "2-6-INFBN.2-BDE.1-AD.ARMY.MIL", "2-BDE-1-AD-NODE"
  do_action "MoveAgent", "2-BDE.1-AD.ARMY.MIL", "3-BDE-1-AD-NODE"
  do_action "MoveAgent", "4-27-FABN.2-BDE.1-AD.ARMY.MIL", "AVNBDE-1-AD-NODE"
  do_action "MoveAgent", "40-ENGBN.2-BDE.1-AD.ARMY.MIL", "1-BDE-1-AD-NODE"
  do_action "MoveAgent", "47-FSB.DISCOM.1-AD.ARMY.MIL", "3-BDE-1-AD-NODE"
  do_action "MoveAgent", "240-SSCO.7-CSG.5-CORPS.ARMY.MIL", "REAR-C-NODE"
  do_action "MoveAgent", "123-MSB-FOOD.DISCOM.1-AD.ARMY.MIL", "1-BDE-1-AD-NODE"
  do_action "MoveAgent", "123-MSB-ORD.DISCOM.1-AD.ARMY.MIL", "2-BDE-1-AD-NODE"
  do_action "MoveAgent", "123-MSB-PARTS.DISCOM.1-AD.ARMY.MIL", "3-BDE-1-AD-NODE"
  do_action "MoveAgent", "123-MSB-POL.DISCOM.1-AD.ARMY.MIL", "AVNBDE-1-AD-NODE"

  wait_for  "SocietyQuiesced", 1.hours

end
