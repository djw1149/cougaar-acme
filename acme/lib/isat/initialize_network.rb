=begin script

include_path: initialize_network.rb
description: turn off bandwidth shaping

=end

insert_after :setup_run do
  do_action "InitializeNetwork"
end

