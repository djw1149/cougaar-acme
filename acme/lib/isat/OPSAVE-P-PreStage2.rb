=begin experiment

name: SAVE-PreStage2
description: SAVE-PreStage2
script: $CIP/csmart/lib/isat/OPBaselineTemplate.rb
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
  - script: $CIP/csmart/lib/isat/save_snapshot.rb
    parameters:
      - snapshot_name: $CIP/SAVE-PreStage2.tgz
      - snapshot_location: before_stage_2
=end

require 'cougaar/scripting'
Cougaar::ExperimentDefinition.register(__FILE__)
