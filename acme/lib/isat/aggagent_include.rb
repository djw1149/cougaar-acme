=begin script

include_path: aggagent_include.rb
description: Captures the aggagent data

=end

insert_after :society_frozen do
  do_action "AggAgentQueryBasic", "agg_basic.xml"
  do_action "AggAgentQueryDemand", "agg_demand.xml"
  do_action "AggAgentQueryDemand", "agg_demand_for_comp.xml"
  do_action "AggAgentQueryShortfall", "agg_shortfall.xml"
  do_action "AggAgentQueryJP8", "agg_jp8.xml"
end