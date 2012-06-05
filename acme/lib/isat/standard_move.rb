=begin script

include_path: standard_move.rb
description: MOVES we used in the MOAS in 2003

=end

insert_after :after_stage_1 do

  do_action "InfoMessage", "##### Moving AGENTS to other  NODES ######"
  do_action "MoveAgent", "1-35-ARBN.2-BDE.1-AD.ARMY.MIL", "1-AD-BDES-NODE"
  do_action "MoveAgent", "1-6-INFBN.2-BDE.1-AD.ARMY.MIL", "1-AD-BDES-NODE"
  do_action "MoveAgent", "2-6-INFBN.2-BDE.1-AD.ARMY.MIL", "1-AD-BDES-NODE"
  do_action "MoveAgent", "2-BDE.1-AD.ARMY.MIL", "1-AD-BDES-NODE"
  do_action "MoveAgent", "4-27-FABN.2-BDE.1-AD.ARMY.MIL", "1-AD-BDES-NODE"
  do_action "MoveAgent", "40-ENGBN.2-BDE.1-AD.ARMY.MIL", "1-AD-BDES-NODE"
  do_action "MoveAgent", "47-FSB.DISCOM.1-AD.ARMY.MIL", "1-AD-BDES-NODE"
  do_action "MoveAgent", "240-SSCO.7-CSG.5-CORPS.ARMY.MIL", "REAR-C-NODE"
  do_action "MoveAgent", "123-MSB-FOOD.DISCOM.1-AD.ARMY.MIL", "2-BDE-NODE"
  do_action "MoveAgent", "123-MSB-ORD.DISCOM.1-AD.ARMY.MIL", "2-BDE-NODE"
  do_action "MoveAgent", "123-MSB-PARTS.DISCOM.1-AD.ARMY.MIL", "2-BDE-NODE"
  do_action "MoveAgent", "123-MSB-POL.DISCOM.1-AD.ARMY.MIL", "2-BDE-NODE"

  do_action "MoveAgent", "5-CORPS.ARMY.MIL", "REAR-XNODE"
  do_action "MoveAgent", "110-POL-SUPPLYCO.37-TRANSGP.21-TSC.ARMY.MIL", "REAR-XNODE"
  do_action "MoveAgent", "3-SUPCOM-HQ.5-CORPS.ARMY.MIL", "REAR-XNODE"
  do_action "MoveAgent", "900-POL-SUPPLYCO.7-CSG.5-CORPS.ARMY.MIL", "REAR-XNODE"
  do_action "MoveAgent", "565-RPRPTCO.7-CSG.5-CORPS.ARMY.MIL", "REAR-XNODE"
  do_action "MoveAgent", "343-SUPPLYCO.29-SPTGP.21-TSC.ARMY.MIL", "REAR-XNODE"

  wait_for  "SocietyQuiesced", 1.hours

end
