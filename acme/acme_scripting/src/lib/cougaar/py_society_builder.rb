# py_society_builder.rb
# Builds a society object from a string of Ruby code arriving 
# via stdin, transforms it according to rules passed in as args, 
# then outputs the new society to stdout as a string of xml.

#~ $:.unshift ".."
#~ $:.unshift "../../../../acme_service/src/redist"

$:.unshift "../../ruby/acme_scripting/src/lib"
$:.unshift "../../ruby/acme_service/src/redist"
require 'cougaar/scripting'

society = eval $stdin.read
engine = Cougaar::Model::RuleEngine.new(society)
engine.load_rules(ARGV.join(";"))
#engine.enable_stdout if @verbose
engine.execute
puts society.to_xml
