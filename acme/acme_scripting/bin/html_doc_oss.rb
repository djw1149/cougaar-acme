#! /usr/bin/env ruby

=begin
 * <copyright>  
 *  Copyright 2001-2004 InfoEther LLC  
 *  Copyright 2001-2004 BBN Technologies
 *
 *  under sponsorship of the Defense Advanced Research Projects  
 *  Agency (DARPA).  
 *   
 *  You can redistribute this software and/or modify it under the 
 *  terms of the Cougaar Open Source License as published on the 
 *  Cougaar Open Source Website (www.cougaar.org <www.cougaar.org> ).   
 *   
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
 *  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
 *  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR 
 *  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT 
 *  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
 *  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT 
 *  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
 *  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY 
 *  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
 *  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
 *  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 * </copyright>  
=end

path = Dir.pwd.split("/")[0...(Dir.pwd.split("/").index("acme_scripting"))]
dir1 = ( ( path + ['src', 'ruby', 'acme_scripting', 'src', 'lib'] ).join("/") )
dir2 = ( ( path + ['src', 'ruby', 'acme_service', 'src', 'redist'] ).join("/") )
dir1 = ( ( path + ['acme_scripting', 'src', 'lib'] ).join("/") ) unless File.exist?(dir1)
dir2 = ( ( path + ['acme_service', 'src', 'redist'] ).join("/") ) unless File.exist?(dir2)
$:.unshift dir1 if File.exist?(dir1)
$:.unshift dir2 if File.exist?(dir2)

require 'cougaar/scripting'

def output_action(action)
  action = action.allocate
  docs = action.documentation
  result =  "<tr><td colspan=2 align='center' bgcolor=black ><font color=white size=+2>Action #{action.name}</font></td></tr>"
  result << "<td valign='top'><b>Description: </b>#{docs ? docs.description : 'undocumented'}</td>"
  result << "<td valign='top'><b>Resultant State: </b>#{action.resultant_state ? action.resultant_state : 'None'}<br><b>Prior States: </b>#{action.prior_states ? action.prior_states.join(', ') : 'None'}</td>"
  result << "</tr><tr>"
  result << "<td valign='top'><b><U>Paramters:</U></b>"
  if docs
    if docs.has_parameters?
      docs.each_parameter do |param, desc|
        result << "<br><b>#{param}: </b>#{desc}"
      end
    else
      result << "<br>None"
    end
  else
    result << "<br>Undocumented"
  end
  result << "</td>"
  result << "<td valign='top'><b><U>Block Yields:</U></b>"
  if docs
    if docs.has_block_yields?
      docs.each_block_yield do |param, desc|
        result << "<br><b>#{param}: </b>#{desc}"
      end
    else
      result << "<br>None"
    end
  else
    result << "<br>Undocumented"
  end
  result << "</td></tr>"
  if docs
    result << "<tr><td valign='top' colspan=2><b><u>Example:</u></b><br>"
    result << "<pre>#{docs.example}</pre>"
    result << "</td></tr><tr><td>&nbsp;</td></tr>"
  end
  result
end

def output_state(state)
  state = state.allocate
  docs = state.documentation
  result =  "<tr><td colspan=2 align='center' bgcolor=black ><font color=white size=+2>State #{state.name}#{state.is_noop? ? ' (NOOP)' : ''}</font></td></tr>"
  result << "<td valign='top'><b>Description: </b>#{docs ? docs.description : 'undocumented'}</td>"
  result << "<td valign='top'><b>Default Timeout: </b>#{state.default_timeout ? state.default_timeout.to_s+' seconds' : 'None'}<br><b>Prior States: </b>#{state.prior_states ? state.prior_states.join(', ') : 'None'}</td>"
  result << "</tr>"
  return result if state.is_noop?
  result << "<tr>"
  result << "<td valign='top'><b><U>Paramters:</U></b>"
  if docs
    if docs.has_parameters?
      docs.each_parameter do |param, desc|
        result << "<br><b>#{param}: </b>#{desc}"
      end
    else
      result << "<br>None"
    end
  else
    result << "<br>Undocumented"
  end
  result << "</td>"
  result << "<td valign='top'><b><U>Block Yields:</U></b>"
  if docs
    if docs.has_block_yields?
      docs.each_block_yield do |param, desc|
        result << "<br><b>#{param}: </b>#{desc}"
      end
    else
      result << "<br>None"
    end
  else
    result << "<br>Undocumented"
  end
  result << "</td></tr>"
  if docs
    result << "<tr><td valign='top' colspan=2><b><u>Example:</u></b><br>"
    result << "<pre>#{docs.example}</pre>"
    result << "</td></tr><tr><td>&nbsp;</td></tr>"
  end
  result
end

def output_all_actions
  action_list = []
  Cougaar::Actions.each do |action| 
    action = action.allocate
    action_list << action.name
  end
  action_list.sort!
  action_list.each { |action_name| puts output_action(Cougaar::Actions[action_name]) }
end

def output_all_states
  state_list = []
  Cougaar::States.each do |state| 
    state = state.allocate
    state_list << state.name 
  end
  state_list.sort!
  state_list.each { |state_name| puts output_state(Cougaar::States[state_name])}
end

HEADER = "<html><body><table width='100%'>"
FOOTER = "</table></html>"

if ARGV[0]
  begin
    action = Cougaar::Actions[ARGV[0]]
    puts HEADER
    puts output_action(action)
    puts FOOTER
  rescue
    begin
      state = Cougaar::States[ARGV[0]]
      puts HEADER
      output_state(state)
      puts FOOTER
    rescue
      put "ERROR: Unknown Action or State '#{ARGV[0]}'"
    end
  end
else
  puts HEADER
  output_all_actions
  output_all_states
  puts FOOTER
end

__END__
      puts "Block syntax: { | #{docs.block_yield_names.join(', ')} | ... }"
