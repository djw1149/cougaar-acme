=begin script

include_path: clearLogs.rb
description: Connects to operator service and then clears log files

=end

insert_before :setup_run do
  do_action "ConnectOperatorService"
  do_action "ClearLogs"
end
