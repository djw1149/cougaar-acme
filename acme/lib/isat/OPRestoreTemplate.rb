CIP = ENV['CIP']

require 'cougaar/scripting'
require 'ultralog/scripting'

include Cougaar

HOSTS_FILE = Ultralog::OperatorUtils::HostManager.new.get_hosts_file

Cougaar::ExperimentMonitor.enable_stdout
Cougaar::ExperimentMonitor.enable_logging

Cougaar.new_experiment().run(parameters[:run_count]) {
  set_archive_path parameters[:archive_dir]

  do_action "LoadSocietyFromPersistenceSnapshot", parameters[:snapshot_name]

at :snaphot_restored

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

at :society_started

  wait_for  "SocietyQuiesced"

  if !(parameters[:stages].index(5).nil? && parameters[:stages].index(6).nil? && parameters[:stages].index(7).nil?)
    include "post_stage_data.inc", "Stage#{parameters[:stages].join("_")}", true
  else
    include "post_stage_data.inc", "Stage#{parameters[:stages].join("_")}"
  end

at :society_running  
at :society_restored
  
  wait_for  "GLSConnection", false
  do_action "Sleep", 30.seconds

at :society_ready

  parameters[:stages].each do |stage|
    wait_for  "NextOPlanStage", 10.minutes
    do_action "PublishNextStage"
    do_action "InfoMessage", "########  Starting Planning Phase Stage - #{stage} #########"
  end

at :starting_stage

at :ending_stage

  wait_for  "SocietyQuiesced", 2.hours
  if !(parameters[:stages].index(5).nil? && parameters[:stages].index(6).nil? && parameters[:stages].index(7).nil?)
    include "post_stage_data.inc", "Stage#{parameters[:stages].join("_")}", true
  else
    include "post_stage_data.inc", "Stage#{parameters[:stages].join("_")}"
  end
  
at :after_stage

#  do_action "InfoMessage", "Advancing time to AUG 14 (C-1), 1 day steps, quiescing between steps"
#  do_action "AdvanceTime", 4.days

at :end_of_run

  do_action "FreezeSociety"

at :society_frozen

  do_action "Sleep", 30.seconds
  do_action "StopSociety"
  
at :society_stopped

  do_action "CleanupSociety"
  do_action "StopCommunications"
}
