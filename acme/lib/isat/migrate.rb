=begin script

include_path: migrate.rb
description: Uinit Reafiliation Migration
             migrate_location - location in the script to do this
             node_name - node on the host to migrate
             target_network - network name of destination

=end

insert_after parameters[:migrate_location] do
  do_action "Migrate", parameters[:node_name],parameters[:target_network]
end
