=begin script

include_path: clearNodeFiles.rb
description: Connects to operator service and then clears node files in config/nodes

=end

insert_before :setup_run do
  do_action "ConnectOperatorService"
  do_action "ClearNodeFiles"
end
