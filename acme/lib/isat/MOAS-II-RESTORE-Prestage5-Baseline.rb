=begin experiment

name: MOAS-II-RESTORE-Basline
description: MOAS-II-preStage5-Restore-Baseline
script: $CIP/csmart/lib/isat/OPRestoreTemplate.rb
parameters:
  - run_count: 1
  - snapshot_name: $CIP/SAVE-PreStage5.tgz
  - archive_dir: $CIP/Logs
  - stages:
    - 5
    - 6
  
include_scripts:
  - script: $CIP/csmart/lib/isat/clearLogs.rb
  - script: $CIP/csmart/lib/isat/datagrabber_include.rb
  - script: $CIP/csmart/assessment/assess/cnccalc_include.rb
    parameters:
      - run_type: base
      - description: Stage 56 Baseline
  - script: $CIP/csmart/assessment/assess/analysis_baseline_cmds.rb
    parameters:
      - only_analyze: "moe1"
      - baseline_name: base2

=end

require 'cougaar/scripting'
Cougaar::ExperimentDefinition.register(__FILE__)
