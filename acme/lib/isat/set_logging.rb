=begin script

include_path: set_logging.rb
description: override logging on specified nodes
             category - tag symbol after which to kill nodes.
             level - delay after start tag.
             nodes - array of nodes to kill.

=end

insert_after :setup_run do
  do_action "SetLogging", parameters[:category], parameters[:level], *parameters[:nodes]
end

