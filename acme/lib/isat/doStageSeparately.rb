=begin script

include_path: doStageSeparately.rb
description: For each specified stage number, wait for next stage, publish it, wait for quiescence, collect stats

=end

insert_after parameters[:stage_location] do
  parameters[:stages].each do |stage|
    wait_for "NextOPlanStage", 10.minutes
    do_action "PublishNextStage"
    do_action "InfoMessage", "####### Starting Planning Phase Stage - #{stage} ########"
    wait_for  "SocietyQuiesced", 2.hours
    include "post_stage_data.inc", "Stage#{stage}"
  end
end

