=begin experiment

name: MOAS-II-RESTORE-Stressed-CPU-BW
description: MOAS-II-Stage5-CPU-BW
script: $CIP/csmart/lib/isat/OPRestoreTemplate.rb
parameters:
  - run_count: 1
  - snapshot_name: $CIP/SAVE-PreStage5.tgz
  - archive_dir: $CIP/Logs
  - stages:
    - 5
  
include_scripts:
  - script: $CIP/csmart/lib/isat/clearLogs.rb
  - script: $CIP/csmart/lib/isat/network_shaping.rb
  - script: $CIP/csmart/lib/isat/datagrabber_include.rb
  - script: $CIP/csmart/assessment/assess/inbound_aggagent_include.rb
  - script: $CIP/csmart/assessment/assess/outofbound_aggagent_include.rb
  - script: $CIP/csmart/lib/robustness/objs/deconfliction.rb
  - script: $CIP/csmart/assessment/assess/cnccalc_include.rb
    parameters:
      - run_type: stress
      - description: Stage 5 Stressed CPU 25

  - script: $CIP/csmart/assessment/assess/analysis_stress_cmds.rb
    parameters:
      - only_analyze: "moe1,moe3"
      - baseline_name: base2

  - script: $CIP/csmart/lib/isat/standard_kill_nodes.rb
    parameters:
      - start_tag: starting_stage
      - start_delay: 60
      - nodes_to_kill:
        - AmmoTRANSCOM-NODE
        - 127-DASB-NODE
        - 501-FSB-NODE
        - 47-FSB-NODE
        - 125-FSB-NODE
        - 191-ORDBN-NODE
        - 1-CA-SEC-MGMT-NODE
        - 1-CA-ROB-MGMT-NODE
        - 2-CA-SEC-MGMT-NODE
        - 2-CA-ROB-MGMT-NODE
        - 3-CA-SEC-MGMT-NODE
        - 3-CA-ROB-MGMT-NODE
        - FSB-FUEL-WATER-SECTION-NODE
        - 123-MSB-HQ-NODE
        - 123-MSB-FOOD-NODE
        - 123-MSB-POL-NODE
        - 123-MSB-PARTS-NODE
        - 123-MSB-ORD-NODE

  - script: $CIP/csmart/assessment/assess/standard_mem_stress.rb
    parameters:
      - start_tag: society_restored
      - start_delay: 0
      - end_tag: ending_stage
      - duration: 900
      - mem_stress: 25
      - nodes_to_stress:
        - AmmoTRANSCOM-NODE
        - 127-DASB-NODE
        - 501-FSB-NODE
        - 47-FSB-NODE
        - 125-FSB-NODE
        - 191-ORDBN-NODE
        - 1-CA-SEC-MGMT-NODE
        - 1-CA-ROB-MGMT-NODE
        - 2-CA-SEC-MGMT-NODE
        - 2-CA-ROB-MGMT-NODE
        - 3-CA-SEC-MGMT-NODE
        - 3-CA-ROB-MGMT-NODE
        - FSB-FUEL-WATER-SECTION-NODE
        - 123-MSB-HQ-NODE
        - 123-MSB-FOOD-NODE
        - 123-MSB-POL-NODE
        - 123-MSB-PARTS-NODE
        - 123-MSB-ORD-NODE

  - script: $CIP/csmart/assessment/assess/standard_cpu_stress.rb
    parameters:
      - start_tag: society_restored
      - start_delay: 0
      - end_tag: ending_stage
      - duration: 900
      - cpu_stress: 25
      - nodes_to_stress:
        - AmmoTRANSCOM-NODE
        - 127-DASB-NODE
        - 501-FSB-NODE
        - 47-FSB-NODE
        - 125-FSB-NODE
        - 191-ORDBN-NODE
        - 1-CA-SEC-MGMT-NODE
        - 1-CA-ROB-MGMT-NODE
        - 2-CA-SEC-MGMT-NODE
        - 2-CA-ROB-MGMT-NODE
        - 3-CA-SEC-MGMT-NODE
        - 3-CA-ROB-MGMT-NODE
        - FSB-FUEL-WATER-SECTION-NODE
        - 123-MSB-HQ-NODE
        - 123-MSB-FOOD-NODE
        - 123-MSB-POL-NODE
        - 123-MSB-PARTS-NODE
        - 123-MSB-ORD-NODE

  - script: $CIP/csmart/lib/isat/standard_shape_K_links.rb
    parameters:
      - start_tag: society_restored
      - start_delay: 30
      - end_tag: ending_stage
      - duration: 1800
      - bandwidth: 
      - ks_to_stress:
#        - link 
#          - router: CONUS-REAR-router
#          - target: DIVISION
#          - bandwidth: 762kbit
#        - link 
#          - router: DIV-router
#          - target: CONUS-REAR
#          - bandwidth: 762kbit
#        - link
#          - router: CONUS-REAR-router
#          - target: DIV-SUP
#          - bandwidth: 762kbit
#        - link
#          - router: DIV-SUP-router
#          - target: CONUS-REAR
#          - bandwidth: 762kbit
#        - link
#          - router: CONUS-REAR-router
#          - target: 1-UA
#          - bandwidth: 762kbit
#        - link
#          - router: DIV-SUP-router
#          - target: DIV
#          - bandwidth: 762kbit
#        - link
#          - router: DIV-router
#          - target: DIV-SUP
#          - bandwidth: 762kbit
#        - link
#          - router: DIV-router
#          - target: AVN-BDE
#          - bandwidth: 762kbit
#        - link
#          - router: AVN-BDE-router
#          - target: DIV
#          - bandwidth: 762kbit
        - link
          - router: DIV-router
          - target: 1-BDE
          - bandwidth: 762kbit
        - link
          - router: 1-BDE-router
          - target: DIV
          - bandwidth: 762kbit
#        - link
#          - router: DIV-router
#          - target: 2-BDE
#          - bandwidth: 762kbit
#        - link
#          - router: 2-BDE-router
#          - target: DIV
#          - bandwidth: 762kbit
#        - link
#          - router: DIV-router
#          - target: 3-BDE
#          - bandwidth: 762kbit
#        - link
#          - router: 3-BDE-router
#          - target: DIV
#          - bandwidth: 762kbit
#        - link
#          - router: 1-UA-router
#          - target: 1-CA
#          - bandwidth: 762kbit
#        - link
#          - router: 1-CA-router
#          - target: 1-UA
#          - bandwidth: 762kbit
#        - link
#          - router: 1-UA-router
#          - target: 2-CA
#          - bandwidth: 762kbit
#        - link
#          - router: 2-CA-router
#          - target: 1-UA
#          - bandwidth: 762kbit 
        - link
          - router: 1-UA-router
          - target: 3-CA
          - bandwidth: 762kbit
        - link
          - router: 3-CA-router
          - target: 1-UA
          - bandwidth: 762kbit


#  - script: $CIP/csmart/lib/isat/standard_cyclic_network_stress.rb
#    parameters:

=end

require 'cougaar/scripting'
Cougaar::ExperimentDefinition.register(__FILE__)
