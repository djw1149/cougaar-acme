=begin experiment

name: BaseBWShaping
description: Baseline with BW shaping turned on
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
  - script: $CIP/csmart/lib/isat/datagrabber_include.rb
  - script: $CIP/csmart/assessment/assess/cnccalc_include.rb
    parameters:
    - run_type: Base
    - description: ISAT Baseline


=end

require 'cougaar/scripting'
Cougaar::ExperimentDefinition.register(__FILE__)
