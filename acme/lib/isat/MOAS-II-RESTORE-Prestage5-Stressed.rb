=begin experiment

name: MOAS-II-RESTORE-Stressed-CPU-BW
description: MOAS-II-Stage56-CPU-BW
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
  - script: $CIP/csmart/lib/isat/network_shaping.rb
  - script: $CIP/csmart/lib/isat/datagrabber_include.rb

  - script: $CIP/csmart/assessment/assess/cnccalc_include.rb
    parameters:
      - run_type: stress
      - description: Stage 56 Stressed CPU 50

  - script: $CIP/csmart/assessment/assess/analysis_stress_cmds.rb
    parameters:
      - only_analyze: "moe1"
      - baseline_name: base2

  - script: $CIP/csmart/lib/isat/standard_restart_nodes.rb
    parameters:
      - start_tag: starting_stage
      - start_delay: 90
      - nodes_to_restart:
        - ConusTRANSCOM-NODE
        - REAR-A-NODE
        - 1-AD-NODE
        - 123-MSB-HQ-NODE
        - 123-MSB-FOOD-NODE
        - 123-MSB-POL-NODE
        - 123-MSB-PARTS-NODE
        - 123-MSB-ORD-NODE
        - UA-HHC-NODE
        - FSB-DISTRO-MGT-CELL-NODE
        - FSB-FUEL-WATER-SECTION-NODE
        - 1-CA-BN-INF-CO-A-NODE
        - 2-CA-BN-INF-CO-A-NODE
        - 3-CA-BN-INF-CO-A-NODE

  - script: $CIP/csmart/lib/isat/standard_kill_nodes.rb
    parameters:
      - start_tag: starting_stage
      - start_delay: 30
      - nodes_to_kill:
        - ConusTRANSCOM-NODE
        - REAR-A-NODE
        - 1-AD-NODE
        - 123-MSB-HQ-NODE
        - 123-MSB-FOOD-NODE
        - 123-MSB-POL-NODE
        - 123-MSB-PARTS-NODE
        - 123-MSB-ORD-NODE
        - UA-HHC-NODE
        - FSB-DISTRO-MGT-CELL-NODE
        - FSB-FUEL-WATER-SECTION-NODE
        - 1-CA-BN-INF-CO-A-NODE
        - 2-CA-BN-INF-CO-A-NODE
        - 3-CA-BN-INF-CO-A-NODE

  - script: $CIP/csmart/assessment/assess/standard_cpu_stress.rb
    parameters:
      - start_tag: society_restored
      - start_delay: 0
      - end_tag: ending_stage
      - duration: 120
      - cpu_stress: 50
      - nodes_to_stress:
        - AmmoTRANSCOM-NODE
        - REAR-B-NODE
        - 597-MAINTCO-NODE
        - 565-RPRPTCO-NODE
        - 106-TCBN-NODE
        - 227-SUPPLYCO-NODE
        - 592-ORDCO-NODE
        - 102-POL-SUPPLYCO-NODE
        - DISCOM-1-AD-NODE
        - AVNBDE-1-AD-NODE
        - 1-1-CAVSQDN-NODE
        - 1-BDE-1-AD-NODE
        - 2-BDE-1-AD-NODE
        - UA-HHC-NODE
        - AVN-DET-A-NODE
        - NLOS-A-NODE
        - FSB-CIC-NODE
        - FSB-AREA-FWD-EVAC-SECTION-NODE
        - 1-CA-BN-INF-CO-A-NODE
        - 2-CA-BN-INF-CO-A-NODE
        - 3-CA-BN-INF-CO-A-NODE

  - script: $CIP/csmart/lib/isat/standard_shape_K_links.rb
    parameters:
      - start_tag: society_restored
      - start_delay: 30
      - end_tag: ending_stage
      - duration: 120
      - bandwidth: 
      - ks_to_stress:
        - link 
          - router: CONUS-REAR-router
          - target: DIVISION
          - bandwidth: 256kbit
        - link 
          - router: DIV-router
          - target: CONUS-REAR
          - bandwidth: 256kbit
        - link
          - router: CONUS-REAR-router
          - target: DIV-SUP
          - bandwidth: 256kbit
        - link
          - router: DIV-SUP-router
          - target: CONUS-REAR
          - bandwidth: 256kbit
        - link
          - router: CONUS-REAR-router
          - target: 1-UA
          - bandwidth: 256kbit
        - link
          - router: DIV-SUP-router
          - target: DIV
          - bandwidth: 256kbit
        - link
          - router: DIV-router
          - target: DIV-SUP
          - bandwidth: 256kbit
        - link
          - router: DIV-router
          - target: AVN-BDE
          - bandwidth: 762kbit
        - link
          - router: AVN-BDE-router
          - target: DIV
          - bandwidth: 762kbit
        - link
          - router: DIV-router
          - target: 1-BDE
          - bandwidth: 762kbit
        - link
          - router: 1-BDE-router
          - target: DIV
          - bandwidth: 762kbit
        - link
          - router: DIV-router
          - target: 2-BDE
          - bandwidth: 762kbit
        - link
          - router: 2-BDE-router
          - target: DIV
          - bandwidth: 762kbit
        - link
          - router: DIV-router
          - target: 3-BDE
          - bandwidth: 762kbit
        - link
          - router: 3-BDE-router
          - target: DIV
          - bandwidth: 762kbit
        - link
          - router: 1-UA-router
          - target: 1-CA
          - bandwidth: 762kbit
        - link
          - router: 1-CA-router
          - target: 1-UA
          - bandwidth: 762kbit
        - link
          - router: 1-UA-router
          - target: 2-CA
          - bandwidth: 762kbit
        - link
          - router: 2-CA-router
          - target: 1-UA
          - bandwidth: 762kbit 
        - link
          - router: 1-UA-router
          - target: 3-CA
          - bandwidth: 762kbit
        - link
          - router: 3-CA-router
          - target: 1-UA
          - bandwidth: 762kbit

#  - script: $CIP/csmart/lib/isat/standard_kill_nodes.rb
#    parameters:
#      - start_tag: starting_stage
#      - start_delay: 60
#      - nodes_to_kill:
#        - 123-MSB-NODE

#  - script: $CIP/csmart/lib/isat/standard_cyclic_network_stress.rb
#    parameters:

=end

require 'cougaar/scripting'
Cougaar::ExperimentDefinition.register(__FILE__)
