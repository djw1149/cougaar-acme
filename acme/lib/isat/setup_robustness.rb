=begin script

include_path: setup_robustness.rb
description: special initialization for robustness

=end

CIP = ENV['CIP']

$:.unshift File.join(CIP, 'csmart', 'config', 'lib')
require 'robustness/uc9/deconfliction'

insert_after :society_running do
  do_action "UnleashDefenses"
end
