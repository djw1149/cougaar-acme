=begin script

include_path: sms_notify.rb
description: adds an on_archive hook which notifies art and mark of failed runs

=end

on_archive do |run, archive_fiile|
  log = File.read('run.log')
  
  #error checking
  md = /ERROR: Could not verify Society: Could not access host: (.*)/.match(log)
  Ultralog::OperatorUtils::SMSNotify.new.notify("Verify failed on host #{md[1]}") if md

end  
