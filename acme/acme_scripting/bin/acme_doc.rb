#! /usr/bin/env ruby
path = Dir.pwd.split("/")[0...(Dir.pwd.split("/").index("acme_scripting"))]
dir1 = ( ( path + ['src', 'ruby', 'acme_scripting', 'src', 'lib'] ).join("/") )
dir2 = ( ( path + ['src', 'ruby', 'acme_service', 'src', 'redist'] ).join("/") )
dir1 = ( ( path + ['acme_scripting', 'src', 'lib'] ).join("/") ) unless File.exist?(dir1)
dir2 = ( ( path + ['acme_service', 'src', 'redist'] ).join("/") ) unless File.exist?(dir2)
$:.unshift dir1 if File.exist?(dir1)
$:.unshift dir2 if File.exist?(dir2)

require 'cougaar/scripting'
require 'ultralog/scripting'

def output_action(action)
  action = action.allocate
  docs = action.documentation
  puts "Name: #{action.name}"
  puts "Description: #{docs.description}" if docs
  puts "Resultant State: #{action.resultant_state ? action.resultant_state : 'None'}"
  puts "Prior States: #{action.prior_states ? action.prior_states.join(', ') : 'None'}"
  if docs
    if docs.has_parameters?
      puts "Parameters:"
      docs.each_parameter do |param, desc|
        puts "  #{param}: #{desc}"
      end
    end
    if docs.has_block_yields?
      puts "Block syntax: { | #{docs.block_yield_names.join(', ')} | ... }"
      docs.each_block_yield do |param, desc|
        puts "  #{param}: #{desc}"
      end
    end
    if docs.example
      puts "Example:"
      puts
      puts docs.example
    end
  end
end

def output_state(state)
  state = state.allocate
  docs = state.documentation
  puts "Name: #{state.name} #{state.is_noop? ? '(NOOP)' : ''}"
  puts "Description: #{docs.description}" if docs
  return if state.is_noop?
  puts "Default timeout: #{state.default_timeout ? state.default_timeout.to_s+' seconds' : 'None'}"
  puts "Prior States: #{state.prior_states ? state.prior_states.join(', ') : 'None'}"
  if docs
    if docs.has_parameters?
      puts "Parameters:"
      docs.each_parameter do |param, desc|
        puts "  #{param}: #{desc}"
      end
    end
    if docs.has_block_yields?
      puts "Block syntax: { | #{docs.block_yield_names.join(', ')} | ... }"
      docs.each_block_yield do |param, desc|
        puts "  #{param}: #{desc}"
      end
    end
    if docs.example
      puts "Example:"
      puts
      puts docs.example
    end
  end
end

def output_all_actions
  action_list = []
  undocumented_action_list = []
  Cougaar::Actions.each do |action| 
    action = action.allocate
    action_list << action.name if action.documentation
    undocumented_action_list << action.name unless action.documentation
  end
  action_list.sort!
  undocumented_action_list.sort!
  puts "Documented Actions: ---------------------------"
  action_list.each { |action_name| output_action(Cougaar::Actions[action_name]); puts "   -------" }
  if undocumented_action_list.size > 0
    puts "Undocumented Actions: ---------------------------"
    undocumented_action_list.each { |action_name| puts action_name }
  end
end

def output_all_states
  state_list = []
  undocumented_state_list = []
  Cougaar::States.each do |state| 
    state = state.allocate
    state_list << state.name if state.documentation
    undocumented_state_list << state.name unless state.documentation
  end
  state_list.sort!
  undocumented_state_list.sort!
  puts "Documented States: ---------------------------"
  state_list.each { |state_name| output_state(Cougaar::States[state_name]); puts "   -------" }
  if undocumented_state_list.size > 0
    puts "Undocumented States: ---------------------------"
    undocumented_state_list.each { |state_name| puts state_name }
  end
end

if ARGV[0]
  begin
    action = Cougaar::Actions[ARGV[0]]
    puts
    output_action(action)
    puts
  rescue
    begin
      state = Cougaar::States[ARGV[0]]
      puts
      output_state(state)
      puts
    rescue
      put "ERROR: Unknown Action or State '#{ARGV[0]}'"
    end
  end
else
  output_all_actions
  puts 
  output_all_states
end