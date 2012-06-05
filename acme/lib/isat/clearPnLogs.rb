=begin script

include_path: clearPnLogs.rb
description: Connects to operator service and then clears old persistence and log files

=end

insert_before :setup_run do
  do_action "ConnectOperatorService"
  do_action "ClearPersistenceAndLogs"
end
