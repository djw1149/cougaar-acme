=begin experiment

name: MOAS-II-Save
description: MOAS-II save pre-Stage5
script: $CIP/csmart/lib/isat/OPBaselineTemplate-ExtOplan.rb
parameters:
  - run_count: 1
  - society_file: $CIP/csmart/config/societies/ua/full-tc20-232a703v.plugins.rb
  - layout_file: $CIP/operator/layouts/04-OP-layout.xml
  - archive_dir: $CIP/Logs
  
  - rules:
    - $CIP/csmart/config/rules/isat
    - $CIP/csmart/config/rules/yp
    - $CIP/csmart/config/rules/logistics
    - $CIP/csmart/config/rules/assessment

include_scripts:
  - script: $CIP/csmart/lib/isat/clearPnLogs.rb
  - script: $CIP/csmart/lib/isat/network_shaping.rb
  - script: $CIP/csmart/lib/isat/datagrabber_include.rb
  - script: $CIP/csmart/assessment/lib/assess/inbound_aggagent_include.rb
  - script: $CIP/csmart/assessment/lib/assess/outofbound_aggagent_include.rb
  - script: $CIP/csmart/assessment/lib/assess/cnccalc_include.rb
  - script: $CIP/csmart/lib/isat/save_snapshot.rb
    parameters:
      - snapshot_name: $CIP/SAVE-PreStage5.tgz
      - snapshot_location: before_stage_5

=end

require 'cougaar/scripting'
Cougaar::ExperimentDefinition.register(__FILE__)
