if include_args.size==0
  raise "In order to include the post_stage_data.inc file you must supply a parameter which uniquely names the files"
else 
  do_action "SaveSocietyCompletion", "comp_#{include_args[0]}.xml"
#  do_action "SaveSocietyShortfall", "shortfall_#{include_args[0]}.xml"
  do_action "RelationshipServlet", "158-AVN-CO-C.5-CORPS.ARMY.MIL", "RELATIONSHIP_SCHEDULE", "Relationship_158-AVN-CO-C_#{include_args[0]}.xml"
  do_action "RelationshipServlet", "159-AVN-CO-F.5-CORPS.ARMY.MIL", "RELATIONSHIP_SCHEDULE", "Relationship_159-AVN-CO-F_#{include_args[0]}.xml"
  do_action "FullInventory", "#{include_args[0]}"
  if include_args.size > 1 && include_args[1] == true
    do_action "UAInventory", "ua-#{include_args[0]}"
    do_action "FCSInventory", "fcs-#{include_args[0]}"
  end
  do_action "CollectMemoryData", "MEM/memdata_#{include_args[0]}"
end
