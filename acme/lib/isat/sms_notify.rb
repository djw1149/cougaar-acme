=begin script

include_path: sms_notify.rb
description: adds an on_archive hook which notifies art and mark of failed runs

=end

on_archive do |run, archive_fiile|
  log = File.read('run.log')
  
  # numbers
  art = '7039196618@vtext.com'
  mark = '5716431333@vtext.com'
  rich = '5713326896@voicestream.net'
  joe = '7038696710@messaging.sprintpcs.com'
  phonelist = [art, mark, rich, joe]

  #error checking
  error = nil
  md = /ERROR: Could not verify Society: Could not access host: (.*)/.match(log)
  error = "Verify failed on host #{md[1]}" if md

  #send messages
  if error
    phonelist.each do |number|
      IO.popen("mail -s '#{error}' #{number}", "w") do |io|
        io.putc(4)
        io.putc(13)
      end
      sleep 1
    end
  end   

end  
