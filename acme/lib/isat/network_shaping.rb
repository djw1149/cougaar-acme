=begin script

include_path: network_shaping.rb
description: turn on and off bandwidth shaping

=end
insert_after :society_running do
  do_action "ShapeNetwork"
end

insert_after :end_of_run do
  do_action "InitializeNetwork"
end
