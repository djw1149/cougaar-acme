=begin experiment

name: Restore-PreStage34
description: Restore-PreStage34
script: $CIP/csmart/lib/isat/OPRestoreTemplate.rb
parameters:
  - run_count: 1
  - snapshot_name: $CIP/SAVE-PreStage3.tgz
  - archive_dir: $CIP/Logs
  - stages: 
    - 3
    - 4
  
include_scripts:
  - script: $CIP/csmart/lib/isat/clearLogs.rb
  - script: $CIP/csmart/lib/isat/network_shaping.rb
  - script: $CIP/csmart/lib/isat/datagrabber_include.rb

=end

require 'cougaar/scripting'
Cougaar::ExperimentDefinition.register(__FILE__)
