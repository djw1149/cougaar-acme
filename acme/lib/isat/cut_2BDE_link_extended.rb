=begin script

include_path: cut_2BDE_link_extended.rb
description: Disable the router interfaces for the K links and subnets given in the arguments.

=end
insert_after :before_stage_2 do
  do_action "InfoMessage", "Advancing time to SEPT 8 (C+24), 1 day steps, quiescing between steps"
  do_action "AdvanceTime", 25.days
#  do_action "DisableNetworkInterfaces", "2-BDE-NODE"

  do_action "InfoMessage", "Deactivate DIV--2-BDE,2-BDE---DIV K links"
  do_action "DeactivateKLinks", "DIV-router", "2-BDE"
  do_action "DeactivateKLinks", "2-BDE-router", "DIV"

  do_action "GenericAction" do |run|
    uri=run.society.agents['123-MSB-POL.DISCOM.1-AD.ARMY.MIL'].uri+"/commStatus?commUp=false&connectedAgentName=47-FSB.DISCOM.1-AD.ARMY.MIL"
    Cougaar::Communications::HTTP.get(uri)
  end
  do_action "GenericAction" do |run|
    uri=run.society.agents['123-MSB-ORD.DISCOM.1-AD.ARMY.MIL'].uri+"/commStatus?commUp=false&connectedAgentName=47-FSB.DISCOM.1-AD.ARMY.MIL"
    Cougaar::Communications::HTTP.get(uri)
  end
  do_action "GenericAction" do |run|
    uri=run.society.agents['123-MSB-PARTS.DISCOM.1-AD.ARMY.MIL'].uri+"/commStatus?commUp=false&connectedAgentName=47-FSB.DISCOM.1-AD.ARMY.MIL"
    Cougaar::Communications::HTTP.get(uri)
  end
  do_action "GenericAction" do |run|
    uri=run.society.agents['123-MSB-FOOD.DISCOM.1-AD.ARMY.MIL'].uri+"/commStatus?commUp=false&connectedAgentName=47-FSB.DISCOM.1-AD.ARMY.MIL"
    Cougaar::Communications::HTTP.get(uri)
  end

  # wait_for "Command", "ok"

  do_action "InfoMessage", "Advance to Sept 9th"
  do_action "AdvanceTime", 1.days, 1.days, false
  do_action "Sleep", 5.minutes

  do_action "InfoMessage", "Advance to Sept 10th"
  do_action "AdvanceTime", 1.days, 1.days, false
  do_action "Sleep", 5.minutes
#  wait_for "Command", "ok"

  do_action "InfoMessage", "Advance to Sept 11th"
  do_action "AdvanceTime", 1.days, 1.days, false
  do_action "Sleep", 5.minutes

  do_action "InfoMessage", "Advance to Sept 12th"
  do_action "AdvanceTime", 1.days, 1.days, false
  do_action "Sleep", 5.minutes

  do_action "InfoMessage", "Advance to Sept 13th"
  do_action "AdvanceTime", 1.days, 1.days, false
  do_action "Sleep", 5.minutes

#  wait_for "Command", "ok"

  include "#{CIP}/csmart/lib/isat/post_stage_data.inc", "5Day_CommLoss"
#  do_action "EnableNetworkInterfaces", "2-BDE-NODE"

  do_action "InfoMessage", "Activate DIV--2-BDE,2-BDE---DIV K links"
  do_action "ActivateKLinks", "DIV-router", "2-BDE"
  do_action "ActivateKLinks", "2-BDE-router", "DIV"

  do_action "GenericAction" do |run|
    uri=run.society.agents['123-MSB-POL.DISCOM.1-AD.ARMY.MIL'].uri+"/commStatus?commUp=true&connectedAgentName=47-FSB.DISCOM.1-AD.ARMY.MIL"
    Cougaar::Communications::HTTP.get(uri)
  end  
  do_action "GenericAction" do |run|
    uri=run.society.agents['123-MSB-ORD.DISCOM.1-AD.ARMY.MIL'].uri+"/commStatus?commUp=true&connectedAgentName=47-FSB.DISCOM.1-AD.ARMY.MIL"
    Cougaar::Communications::HTTP.get(uri)  
  end  
  do_action "GenericAction" do |run|
    uri=run.society.agents['123-MSB-PARTS.DISCOM.1-AD.ARMY.MIL'].uri+"/commStatus?commUp=true&connectedAgentName=47-FSB.DISCOM.1-AD.ARMY.MIL"
    Cougaar::Communications::HTTP.get(uri)  
  end  
  do_action "GenericAction" do |run|
    uri=run.society.agents['123-MSB-FOOD.DISCOM.1-AD.ARMY.MIL'].uri+"/commStatus?commUp=true&connectedAgentName=47-FSB.DISCOM.1-AD.ARMY.MIL"
    Cougaar::Communications::HTTP.get(uri)  
  end  

  do_action "Sleep", 5.minutes
#  wait_for "Command", "ok"
  include "#{CIP}/csmart/lib/isat/post_stage_data.inc", "AFTER_NIC_RESTORE"

  do_action "InfoMessage", "Advance to Sept 28th"
  do_action "AdvanceTime", 15.days
#  wait_for "Command", "ok"
  include "#{CIP}/csmart/lib/isat/post_stage_data.inc", "POST_RESTORE_PLUS_5_DAYS"
end
