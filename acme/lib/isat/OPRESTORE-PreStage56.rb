=begin experiment

name: Restore-PreStage56
description: Restore-PreStage56
script: $CIP/csmart/lib/isat/OPRestoreTemplate.rb
parameters:
  - run_count: 1
  - archive_dir: $CIP/Logs
  - snapshot_name: $CIP/SAVE-PreStage5.tgz
  - archive_dir: $CIP/Logs
  - stages: 
    - 5
    - 6
  
include_scripts:
  - script: $CIP/csmart/lib/isat/clearLogs.rb
  - script: $CIP/csmart/lib/isat/network_shaping.rb
  - script: $CIP/csmart/lib/isat/datagrabber_include.rb

=end

require 'cougaar/scripting'
Cougaar::ExperimentDefinition.register(__FILE__)
