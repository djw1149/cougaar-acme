=begin script

include_path: klink_reporting.rb
description: Report on the K-Links at good points in the run.
	tag - List of tags to report on K-Link status.

=end

["during_stage_1", "during_stage_2", "during_stage_3", "during_stage_4", "during_stages_3_4", "during_stage_5", "during_stage_6", "during_stages_5_6", "during_stage_7", "after_stage_1", "after_stage_2", "after_stage_3", "after_stage_4", "after_stages_3_4", "after_stage_5", "after_stage_6", "after_stage_5_6", "after_stage_7", "starting_stage", "ending_stage" ].each do |tag|
  unless (sequence.index_of(tag).nil?) then
    insert_after tag do
      do_action "RouterInformation", "router-#{tag}.xml"
    end
  end
end

