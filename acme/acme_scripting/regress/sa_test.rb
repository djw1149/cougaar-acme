##
#  <copyright>
#  Copyright 2002 InfoEther, LLC
#  under sponsorship of the Defense Advanced Research Projects Agency (DARPA).
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the Cougaar Open Source License as published by
#  DARPA on the Cougaar Open Source Website (www.cougaar.org).
#
#  THE COUGAAR SOFTWARE AND ANY DERIVATIVE SUPPLIED BY LICENSOR IS
#  PROVIDED 'AS IS' WITHOUT WARRANTIES OF ANY KIND, WHETHER EXPRESS OR
#  IMPLIED, INCLUDING (BUT NOT LIMITED TO) ALL IMPLIED WARRANTIES OF
#  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, AND WITHOUT
#  ANY WARRANTIES AS TO NON-INFRINGEMENT.  IN NO EVENT SHALL COPYRIGHT
#  HOLDER BE LIABLE FOR ANY DIRECT, SPECIAL, INDIRECT OR CONSEQUENTIAL
#  DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE OF DATA OR PROFITS,
#  TORTIOUS CONDUCT, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
#  PERFORMANCE OF THE COUGAAR SOFTWARE.
# </copyright>
#

$:.unshift "../src/lib"
$:.unshift "../../acme_service/src/redist"

require 'cougaar/scripting'
require 'ultralog/scripting'

Cougaar::ExperimentMonitor.enable_stdout

Cougaar.new_experiment("MyExperiment").run {
  do_action "LoadSocietyFromCSmart", "FULL-1AD-TRANS-DEFAULT", "u052", "society_config", "s0c0nfig", "asmt02"
  do_action "StartJabberCommunications"
  do_action "VerifyHosts"
  #
  do_action "ConnectOperatorService"
  do_action "ClearPersistenceAndLogs"
  #
  do_action "StartSociety"
  #
  wait_for  "OPlanReady"
  do_action "SendOPlan"
  wait_for  "GLSReady"
  do_action "PublishGLSRoot"
  wait_for  "PlanningComplete"
  #
  wait_for  "Command", "shutdown"
  do_action "StopSociety"
  do_action "StopCommunications"
}
