=begin experiment

name: RESTORE-StressedCPU50-56-Experiment-1
description: Stage-56-cpu50
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
#  - script: $CIP/csmart/lib/isat/network_shaping.rb
  - script: $CIP/csmart/lib/isat/datagrabber_include.rb
  - script: $CIP/csmart/assessment/assess/standard_cpu_stress.rb
    parameters:
      - start_tag: starting_stage
      - start_delay: 0
      - end_tag: ending_stage
      - duration: 36
      - cpu_stress: 50
      - nodes_to_stress:
        - OSD-NODE
        - CONUS-NODE

  - script: $CIP/csmart/assessment/assess/cnccalc_include.rb
    parameters:
      - run_type: stress
      - description: Stage 56 Stressed CPU 50
  - script: $CIP/csmart/assessment/assess/analysis_stress_cmds.rb
    parameters:
      - only_analyze: "moe1"
      - baseline_name: base2

#  - script: $CIP/csmart/lib/isat/standard_kill_nodes.rb
#    parameters:
#      - start_tag: starting_stage
#      - start_delay: 60
#      - nodes_to_kill:
#        - 123-MSB-NODE
#  - script: $CIP/csmart/lib/isat/std_continuous_network_stress.rb
#    parameters:
#      - start_tag: starting_stage
#      - start_delay: 120
#      - end_tag: ending_stage
#      - duration: 240
#      - bandwidth: 
#      - ks_to_stress:
#        - link 
#          - router: CONUS-REAR-router
#          - target: DIVISION
#          - bandwidth: 512kbit
#        - link 
#          - router: DIVISION-router
#          - target: CONUS-REAR
#          - bandwidth: 512kbit
#  - script: $CIP/csmart/lib/isat/standard_cyclic_network_stress.rb
#    parameters:

=end

require 'cougaar/scripting'
Cougaar::ExperimentDefinition.register(__FILE__)
