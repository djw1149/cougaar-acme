=begin script

include_path: wait_for_ok.rb
description: puts a wait for ok command wherever you like
             wait_for_location - point after which to wait for command ok
             You will need to use the message router client to do this

=end

insert_after parameters[:wait_for_location] do
  wait_for "Command", "ok"
end
