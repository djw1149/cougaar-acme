CIP = ENV['CIP']

require 'cougaar/scripting'
require 'ultralog/scripting'

include Cougaar

HOSTS_FILE = Ultralog::OperatorUtils::HostManager.new.get_hosts_file


Cougaar::ExperimentMonitor.enable_stdout
Cougaar::ExperimentMonitor.enable_logging

Cougaar.new_experiment().run(parameters[:run_count]) {
  set_archive_path parameters[:archive_dir]

  do_action "LoadSocietyFromScript", parameters[:society_file]
  do_action "LayoutSociety", parameters[:layout_file], HOSTS_FILE

  do_action "TransformSociety", false, *parameters[:rules]
  if (!parameters[:community_rules].nil?)
    do_action "TransformSociety", false, *parameters[:community_rules]
  end
  
at :transformed_society
  
  do_action "SaveCurrentSociety", "mySociety.xml"
  do_action 'SaveCurrentCommunities', 'myCommunity.xml'
  
  do_action "StartCommunications"

  do_action "CleanupSociety"
  do_action "Sleep", 10.seconds

  do_action "VerifyHosts"

  do_action "DeployCommunitiesFile"
  do_action "InstallCompletionMonitor"
  do_action "WatchAgentPersists"
  do_action "KeepSocietySynchronized"
  do_action "MarkForArchive", "#{CIP}/workspace/log4jlogs", "*log", "Log4j node log"
  do_action "MarkForArchive", "#{CIP}/configs/nodes", "*xml", "XML node config files"

  do_action "InstallReportChainWatcher"
  
at :setup_run
  
  do_action "StartSociety"

at :wait_for_initialization

  wait_for  "ReportChainReady", 30.minutes

at :society_running

  wait_for  "GLSConnection", false
  do_action "Sleep", 30.seconds
  wait_for  "NextOPlanStage", 10.minutes
  do_action "PublishNextStage"
  do_action "InfoMessage", "########  Starting Initial Planning Phase  Stage-1#########"

at :during_stage_1

  wait_for  "SocietyQuiesced", 2.hours
  include "post_stage_data.inc", "Stage1"

at :after_stage_1

  wait_for  "NextOPlanStage"
  do_action "SaveSocietyCompletion", "comp_stage1#{experiment.name}.xml"
  do_action "Sleep", 10.seconds
  do_action "FullInventory", "Stage1"
  do_action "Sleep", 10.seconds

  do_action "InfoMessage", "Advancing time to AUG 14 (C-1), 1 day steps, quiescing between steps"
  do_action "AdvanceTime", 4.days

at :before_stage_2

  do_action "PublishNextStage"
  do_action "InfoMessage", "########  Starting Next Planning Phase  Stage-2  ########"
  do_action "InfoMessage", "########  OPlan Deployment Date Change for 2-BDE #######"

at :during_stage_2

  wait_for "SocietyQuiesced"

at :after_stage_2

  wait_for  "NextOPlanStage"
  do_action "SaveSocietyCompletion", "comp_stage2#{experiment.name}.xml"
  do_action "Sleep", 10.seconds
  do_action "FullInventory", "Stage2"
  do_action "Sleep", 10.seconds

  do_action "InfoMessage", "Advancing time to SEPT 28 (C+44), 1 day steps, quiescing between steps"
  do_action "AdvanceTime", 45.days

at :before_stage_3

  do_action "PublishNextStage"
  do_action "InfoMessage", "########  Starting Next Planning Phase  Stage-3 #########"
  do_action "InfoMessage", "########  OPlan OPTEMPO Change for 2-BDE on C+46 #########"

at :during_stage_3

  wait_for "SocietyQuiesced"

at :after_stage_3

  wait_for  "NextOPlanStage"
  do_action "SaveSocietyCompletion", "comp_stage3#{experiment.name}.xml"
  do_action "Sleep", 1.minutes


  do_action "InfoMessage", "Advancing time to OCT 10 (C+56), 1 day steps, quiescing between steps"
  do_action "AdvanceTime", 12.days

at :before_stage_4

  do_action "PublishNextStage" 
  do_action "InfoMessage", "########  Starting Next Planning Phase Stage-4 #########"
  do_action "InfoMessage", "########  UA OPlan deployment + day 1.         #########"

at :during_stage_4

  wait_for "SocietyQuiesced"

at :after_stage_4

  wait_for  "NextOPlanStage"
  do_action "SaveSocietyCompletion", "comp_stage4#{experiment.name}.xml"
  do_action "Sleep", 10.seconds
  do_action "FullInventory", "Stage4"
  do_action "Sleep", 10.seconds
  do_action "AggAgentQueryShortfall", "agg_shortfall4.xml"
  do_action "Sleep", 10.seconds

  do_action "InfoMessage", "Advancing time to OCT 14 (C+60), 1 day steps, quiescing between steps"
  do_action "AdvanceTime", 4.days

at :before_stage_5

  do_action "PublishNextStage"
  do_action "InfoMessage", "########  Starting Next Planning Phase Stage5  ########"
  do_action "InfoMessage", "########  UA OPlan Day2 & 1-BDE OPTEMPO changes from Medium to High #######"

at :during_stage_5

  wait_for "SocietyQuiesced"

at :after_stage_5
  
  wait_for  "NextOPlanStage"
  do_action "SaveSocietyCompletion", "comp_stage5#{experiment.name}.xml"
  do_action "Sleep", 10.seconds
  do_action "FullInventory", "Stage5"
  do_action "UAInventory", "ua-Stage5"
  do_action "FCSInventory", "fcs-Stage5"
  do_action "Sleep", 10.seconds
  do_action "AggAgentQueryShortfall", "agg_shortfall5.xml"
  do_action "Sleep", 10.seconds

  do_action "InfoMessage", "Advancing time to OCT 15 (C+61), 1 hour steps, quiescing between steps"
  do_action "AdvanceTime", 1.days, 1.hour

at :before_stage_6

  do_action "PublishNextStage"
  do_action "InfoMessage", "########  Starting Next Planning Phase Stage-6 #########"
  do_action "InfoMessage", "########  UA begins Air Assault   #########"

at :during_stage_6

  wait_for "SocietyQuiesced"

at :after_stage_6

  do_action "SaveSocietyCompletion", "comp_stage6#{experiment.name}.xml"
  do_action "Sleep", 10.seconds
  do_action "FullInventory", "Stage6"
  do_action "UAInventory", "ua-Stage6"
  do_action "FCSInventory", "fcs-Stage6"
  do_action "Sleep", 10.seconds

  do_action "InfoMessage", "Advancing time to OCT 17 (C+63), 1 hour steps, quiescing between steps"
  do_action "AdvanceTime", 2.days, 1.hour

  do_action "InfoMessage", "########  MADE IT TO C+63   #########"

  do_action "SaveSocietyCompletion", "comp_stage6_C63#{experiment.name}.xml"
  do_action "Sleep", 10.seconds
  do_action "FullInventory", "Stage6_C63"
  do_action "UAInventory", "ua-Stage6_C63"
  do_action "FCSInventory", "fcs-Stage6_C63"
  do_action "Sleep", 10.seconds

  do_action "InfoMessage", "Advancing time to OCT 19 (C+65), 1 day steps, quiescing between steps"
  do_action "AdvanceTime", 2.days

  do_action "InfoMessage", "########  MADE IT TO C+65   #########"

at :end_of_run

  do_action "FreezeSociety"

at :society_frozen

  do_action "Sleep", 30.seconds
  do_action "StopSociety"
  
at :society_stopped
  
  do_action "CleanupSociety"
  do_action "StopCommunications"
}
