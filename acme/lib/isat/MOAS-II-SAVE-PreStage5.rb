=begin experiment

name: Baseline
description: Baseline
script: $CIP/csmart/scripts/definitions/BaselineTemplate.rb
parameters:
  - run_count: 1
  - society_file: $CIP/csmart/config/societies/ua/full-tc20-232a703v.plugins.rb
  - layout_file: $CIP/operator/layouts/FULL-UA-TC20-35H41N-layout.xml
  - archive_dir: $CIP/Logs
  
  - rules:
    - $CIP/csmart/config/rules/isat
    - $CIP/csmart/config/rules/yp
    - $CIP/csmart/config/rules/logistics
    - $CIP/csmart/config/rules/assessment

include_scripts:
  - script: $CIP/csmart/scripts/definitions/clearPnLogs.rb
  - script: $CIP/csmart/scripts/definitions/datagrabber_include.rb
  - script: $CIP/csmart/scripts/definitions/save_snapshot.rb
    parameters:
      - snapshot_name: $CIP/SAVE-PreStage5.tgz
      - snapshot_location: before_stage_5

=end

require 'cougaar/scripting'
Cougaar::ExperimentDefinition.register(__FILE__)
