BAD BAD BAD don't run this it'll hurt
#=begin experiment

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
        - CONUS-NODE
        - ConusTRANSCOM-NODE
#        - AmmoTRANSCOM-NODE
#        - EuroTRANSCOM-NODE
        - REAR-A-NODE
#        - 106-TCBN-NODE
#        - 227-SUPPLYCO-NODE
#        - 592-ORDCO-NODE
#        - 102-POL-SUPPLYCO-NODE
        - 1-AD-NODE
#        - 123-MSB-HQ-NODE
#        - 123-MSB-FOOD-NODE
        - 123-MSB-POL-NODE
#        - 123-MSB-PARTS-NODE
#        - 123-MSB-ORD-NODE
        - UA-HHC-NODE
#        - UA-BIC-NODE
        - FSB-DISTRO-MGT-CELL-NODE
#        - FSB-FUEL-WATER-SECTION-NODE
#        - FSB-AREA-FWD-EVAC-SECTION-NODE
        - 1-CA-BN-INF-CO-A-NODE
#        - 1-CA-BN-MCS-CO-A-NODE
        - 2-CA-BN-INF-CO-A-NODE
#        - 2-CA-BN-MORTAR-BTY-NODE
        - 3-CA-BN-INF-CO-A-NODE
#        - 3-CA-BN-RECON-DET-NODE

  - script: $CIP/csmart/lib/isat/standard_kill_nodes.rb
    parameters:
      - start_tag: starting_stage
      - start_delay: 30
      - nodes_to_kill:
        - CONUS-NODE
        - ConusTRANSCOM-NODE
#        - AmmoTRANSCOM-NODE
#        - EuroTRANSCOM-NODE
        - REAR-A-NODE
#        - 106-TCBN-NODE
#        - 227-SUPPLYCO-NODE
#        - 592-ORDCO-NODE
#        - 102-POL-SUPPLYCO-NODE
        - 1-AD-NODE
#        - 123-MSB-HQ-NODE
#        - 123-MSB-FOOD-NODE
        - 123-MSB-POL-NODE
#        - 123-MSB-PARTS-NODE
#        - 123-MSB-ORD-NODE
        - UA-HHC-NODE
#        - UA-BIC-NODE
        - FSB-DISTRO-MGT-CELL-NODE
#        - FSB-FUEL-WATER-SECTION-NODE
#        - FSB-AREA-FWD-EVAC-SECTION-NODE
        - 1-CA-BN-INF-CO-A-NODE
#        - 1-CA-BN-MCS-CO-A-NODE
        - 2-CA-BN-INF-CO-A-NODE
#        - 2-CA-BN-MORTAR-BTY-NODE
        - 3-CA-BN-INF-CO-A-NODE
#        - 3-CA-BN-RECON-DET-NODE

  - script: $CIP/csmart/assessment/assess/standard_cpu_stress.rb
    parameters:
      - start_tag: society_restored
      - start_delay: 0
      - end_tag: ending_stage
      - duration: 120
      - cpu_stress: 50
      - nodes_to_stress:
        - OSD-NODE
        - CONUS-NODE
        - ConusTRANSCOM-NODE
#        - AmmoTRANSCOM-NODE
#        - EuroTRANSCOM-NODE
        - REAR-A-NODE
#        - 240-SSCO-NODE
#        - 343-SUPPLYCO-NODE
#        - REAR-B-NODE
#        - 110-POL-SUPPLYCO-NODE
#        - 900-POL-SUPPLYCO-NODE
#        - 125-ORDBN-NODE
#        - 191-ORDBN-NODE
#        - REAR-C-NODE
        - REAR-D-NODE
#        - 597-MAINTCO-NODE
#        - 565-RPRPTCO-NODE
        - 106-TCBN-NODE
#        - 227-SUPPLYCO-NODE
#        - 592-ORDCO-NODE
#        - 102-POL-SUPPLYCO-NODE
        - 1-AD-NODE
#        - 1-4-ADABN-NODE
#        - DIVARTY-1-AD-NODE
#        - 141-SIGBN-NODE
#        - 501-MIBN-CEWI-NODE
#        - DISCOM-1-AD-NODE
#        - 123-MSB-HQ-NODE
#        - 123-MSB-FOOD-NODE
        - 123-MSB-POL-NODE
#        - 123-MSB-PARTS-NODE
#        - 123-MSB-ORD-NODE
        - AVNBDE-1-AD-NODE
#        - 1-1-CAVSQDN-NODE
#        - 1-501-AVNBN-NODE
#        - 2-501-AVNBN-NODE
#        - 127-DASB-NODE
        - 1-BDE-1-AD-NODE
#        - 1-36-INFBN-NODE
#        - 1-37-ARBN-NODE
#        - 16-ENGBN-NODE
#        - 2-3-FABN-NODE
#        - 2-37-ARBN-NODE
#        - 501-FSB-NODE
        - 2-BDE-1-AD-NODE
#        - 1-35-ARBN-NODE
#        - 1-6-INFBN-NODE
#        - 40-ENGBN-NODE
#        - 4-27-FABN-NODE
#        - 2-6-INFBN-NODE
#        - 47-FSB-NODE
        - UA-HHC-NODE
#        - UA-BIC-NODE
        - AVN-DET-A-NODE
#        - AVN-DET-B-NODE
        - NLOS-A-NODE
#        - NLOS-B-NODE
#        - NLOS-BTY-A-NODE
        - FSB-CIC-NODE
#        - FSB-CO-HQ-NODE
#        - FSB-DISTRO-MGT-CELL-NODE
#        - FSB-DISTRO-PLT-HQ-NODE
        - FSB-DRY-CARGO-SECTION-NODE
#        - FSB-EVAC-PLT-HQ-NODE
#        - FSB-HOLDING-DET-NODE
#        - FSB-MED-CO-HQ-NODE
#        - FSB-MAINT-PLT-NODE
#        - FSB-STAFF-CELL-NODE
#        - FSB-SURG-PLT-NODE
#        - FSB-SUSTAIN-CO-HQ-NODE
#        - FSB-TREATMENT-PLT-NODE
#        - FSB-UAV-SUSTAIN-MAINT-SECTION-NODE
        - FSB-FUEL-WATER-SECTION-NODE
        - FSB-AREA-FWD-EVAC-SECTION-NODE
        - 1-CA-BN-INF-CO-A-NODE
#        - 1-CA-BN-INF-CO-B-NODE
#        - 1-CA-BN-MCS-CO-A-NODE
#        - 1-CA-BN-MCS-CO-B-NODE
#        - 1-CA-BN-MORTAR-BTY-NODE
#        - 1-CA-BN-RECON-DET-NODE
#        - 1-CA-BN-SUPPORT-SECTION-NODE
        - 2-CA-BN-INF-CO-A-NODE
#        - 2-CA-BN-INF-CO-B-NODE
#        - 2-CA-MCS-CO-A-NODE
#        - 2-CA-BN-MCS-CO-B-NODE
#        - 2-CA-BN-MORTAR-BTY-NODE
#        - 2-CA-BN-RECON-DET-NODE
#        - 2-CA-BN-SUPPORT-SECTION-NODE
        - 3-CA-BN-INF-CO-A-NODE
#        - 3-CA-BN-INF-CO-B-NODE
#        - 3-CA-BN-MCS-CO-A-NODE
#        - 3-CA-BN-MCS-CO-B-NODE
#        - 3-CA-BN-MORTAR-BTY-NODE
#        - 3-CA-BN-RECON-DET-NODE
#        - 3-CA-BN-SUPPORT-SECTION-NODE


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
