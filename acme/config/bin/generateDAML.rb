
####### setup_descriptions
def setup_descriptions(text_descriptions)
  text_descriptions["SparePartsProvider"] = "Provide spare parts supply. "
  text_descriptions["FuelSupplyProvider"] = "Provide fuel supply. "
  text_descriptions["SubsistenceSupplyProvider"] = "Provide subsistence supply. "
  text_descriptions["PackagedPOLSupplyProvider"] = "Provide packaged POL supply. "
  text_descriptions["AmmunitionProvider"] = "Provide ammunition supply. "
  text_descriptions["MaterielTransportProvider"] = "Transport materiel. "
  text_descriptions["StrategicTransportationProvider"] = "Provide strategic transportation. "
  text_descriptions["AircraftMaintenanceProvider"] = "Maintain aircraft "
  return text_descriptions
end

####### setup_generic_wsdl
def setup_generic_wsdl(generic_wsdl_table)
  generic_wsdl_table["FuelSupplyProvider"] = "SupplyProvider"
  generic_wsdl_table["PackagedPOLSupplyProvider"] = "SupplyProvider"
  generic_wsdl_table["AmmunitionProvider"] = "SupplyProvider"
  generic_wsdl_table["SparePartsProvider"] = "SupplyProvider"
  generic_wsdl_table["SubsistenceSupplyProvider"] = "SupplyProvider"
  generic_wsdl_table["FuelTransportProvider"] = "TransportProvider"
  generic_wsdl_table["MaterielTransportProvider"] = "TransportProvider"
  generic_wsdl_table["StrategicTransportationProvider"] = "TransportProvider"
  generic_wsdl_table["AircraftMaintenanceProvider"] = "MaintenanceProvider"
  return generic_wsdl_table
end

######
def print_through_ontology(agent, profile_out_file, template_lines, cip)
  path = "file://" + cip + "/servicediscovery/data/serviceprofiles/cougaar.daml"
  template_lines.each do |line|
# note: cip has a \ instead of a /
    line = line.gsub(/%FULL_COUGAAR_DAML_FILEPATH%/, path)
    line = line.gsub(/%AGENT_NAME%/, agent.name)
    profile_out_file.puts(line)
    profile_out_file.flush
    if line.include?("/daml:Ontology")
      return
    end
  end  
end

######
def print_Service(agent, profile_out_file, template_lines, uniqueServiceIndex)
  print = false
  template_lines.each do |line|
    if line.include?("service:Service")
      print = true
    end
    if print
      line = line.gsub(/%AGENT_NAME%/, agent.name)
      line = line.gsub(/%INDEX%/, uniqueServiceIndex)
      profile_out_file.puts(line)
      profile_out_file.flush
    end
    if line.include?("/service:Service")
      return
    end
  end
end

######
def print_ServiceProfile_top(agent, profile_out_file, template_lines, uniqueServiceIndex)

  print = false
  template_lines.each do |line|
    if line.include?("cougaar:ServiceProfile")
      print = true
    end
    if print
      line = line.gsub(/%AGENT_NAME%/, agent.name)
      line = line.gsub(/%INDEX%/, uniqueServiceIndex)
      profile_out_file.puts(line)
      profile_out_file.flush      
    end
    if line.include?("service:isPresentedBy")
      return
    end
  end
end

####
def print_militaryEchelon_top(agent, facet, profile_out_file, template_lines)
  print = false
  template_lines.each do |line|
    if print
      line = line.gsub(/%AGENT_NAME%/, agent.name)
      line = line.gsub(/%ECHELON%/, facet[:echelon_of_support])
      profile_out_file.puts(line)
      profile_out_file.flush      
    end
    if line.include?("<!--militaryEchelon-->")
      print = true
    end
    if line.include?("MilitaryEchelonScheme")
      return
    end
  end
end

######
def print_serviceCategory_bottom(profile_out_file, template_lines)
  print = false
  template_lines.each do |line|
    if line.include?("/cougaar:ServiceCategory>")
      print = true
    end
    if print
      profile_out_file.puts(line)
      profile_out_file.flush      
    end
    if line.include?("/cougaar:serviceCategory>")
      return
    end
  end
end
######
def print_militaryRole_top(agent, facet, profile_out_file, template_lines)
  print = false
  template_lines.each do |line|
    if print
      line = line.gsub(/%AGENT_NAME%/, agent.name)
      line = line.gsub(/%ROLE_NAME%/, facet[:role])
      profile_out_file.puts(line)
      profile_out_file.flush      
    end
    if line.include?("<!--militaryRole-->")
      print = true
    end
    if line.include?("MilitaryServiceScheme")
      return
    end
  end
end

######
def print_military(agent, facet, profile_out_file, template_lines)
  print_militaryEchelon_top(agent, facet, profile_out_file, template_lines)
  print_serviceCategory_bottom(profile_out_file, template_lines)

  print_militaryRole_top(agent, facet, profile_out_file, template_lines)
  print_serviceCategory_bottom(profile_out_file, template_lines)
end

######
def print_ServiceProfile_bottom(agent, facet, profile_out_file, template_lines, text_description)

  print = false
  template_lines.each do |line|
    if line.include?("profile:textDescription")
      print = true
    end
    if print
      line = line.gsub(/%AGENT_NAME%/, agent.name)
      desc = text_description[facet[:role]] 
      line = line.gsub(/%SERVICE_DESCRIPTION%/, desc)
      profile_out_file.puts(line)
      profile_out_file.flush      
    end
    if line.include?("/cougaar:ServiceProfile")
      return
    end
  end
end

######
def print_WsdlGrounding(agent, profile_out_file, template_lines, uniqueServiceIndex, cip)

  print = false
# note cip \ problem
  path = "file://" + cip + "/servicediscovery/data/servicegroundings/" + uniqueServiceIndex + "-" + agent.name + ".wsdl"
  template_lines.each do |line|
    if line.include?("cougaar:WsdlGrounding")
      print = true
    end
    if print
      line = line.gsub(/%AGENT_NAME%/, agent.name)
      line = line.gsub(/%INDEX%/, uniqueServiceIndex)
      line = line.gsub(/%FULL_GROUNDING_FILEPATH%/, path)
      profile_out_file.puts(line)
      profile_out_file.flush      
    end
    if line.include?("/cougaar:WsdlGrounding")
      return
    end
  end
end
      
######
def output_wsdl_file(agent, facet, generic_wsdl, cip, uniqueServiceIndex)

  generic = generic_wsdl[facet[:role]]
  generic_file = generic + "CougaarGrounding.wsdl"
#  specific_path = cip + "/servicediscovery/data/servicegroundings/" + uniqueServiceIndex + "-" + agent.name + ".wsdl"
  specific_path = cip + "/servicediscovery/data/servicegroundings/" + uniqueServiceIndex + "-" + agent.name + ".wsdl"
  generic_path = "file://" + cip + "/servicediscovery/data/servicegroundings/" + generic_file
  cougaar_path = "file://" + cip + "/servicediscovery/data/servicegroundings/" + "cougaar.wsdl"
  generic_binding = generic + "CougaarBinding";
  
  wsdl_template = File.open(cip + "/servicediscovery/data/servicegroundings/template-CougaarGrounding.txt", "r")  
  wsdl_lines = wsdl_template.readlines
  wsdl_output = File.open(specific_path, "w")  

  wsdl_lines.each do |line|
    line = line.gsub(/%AGENT_NAME%/, agent.name)
    line = line.gsub(/%INDEX%/, uniqueServiceIndex)
    line = line.gsub(/%SPECIFIC_GROUNDING_FILEPATH%/, "file://" + specific_path)
    line = line.gsub(/%GENERIC_GROUNDING_FILEPATH%/, generic_path)
    line = line.gsub(/%COUGAAR_GROUNDING_FILEPATH%/, cougaar_path)
    line = line.gsub(/%GENERIC_PROVIDER_BINDING%/, generic_binding)  
    wsdl_output.puts(line)
    wsdl_output.flush      
  end
  wsdl_output.flush
  wsdl_output.close
  wsdl_template.close
end

######
def print_end_rdf(profile_out_file)
  profile_out_file.puts("</rdf:RDF>")
end

######## process_agent
def process_agent(agent, cip, template_lines, text_description, generic_wsdl)
  uniqueServiceIndex = "A"
  profile_file_name = cip + "/servicediscovery/data/serviceprofiles/" + agent.name + ".profile.daml"
  profile_out_file = File.new(profile_file_name, "w")
  print_through_ontology(agent, profile_out_file, template_lines, cip)
  has_roles = false
  agent.each_facet( :role ) { | role | has_roles = true}
  if has_roles
    agent.each_facet( :role) do |facet|
      print_Service(agent, profile_out_file, template_lines, uniqueServiceIndex )
      print_ServiceProfile_top(agent, profile_out_file, template_lines, uniqueServiceIndex)
      print_military(agent, facet, profile_out_file, template_lines)
      print_ServiceProfile_bottom(agent, facet, profile_out_file, template_lines, text_description)
      print_WsdlGrounding(agent, profile_out_file, template_lines, uniqueServiceIndex, cip)
      output_wsdl_file(agent, facet, generic_wsdl, cip, uniqueServiceIndex)
      uniqueServiceIndex = uniqueServiceIndex.succ
    end
  end
  print_end_rdf(profile_out_file)
  profile_out_file.flush
  profile_out_file.close
end


#! /usr/bin/env ruby
fullpath = File.expand_path(__FILE__)
path = fullpath.split("/")[0...(fullpath.split("/").index("config"))]
dir1 = ( ( path + ['src', 'ruby', 'acme_scripting', 'src', 'lib'] ).join("/") )
dir2 = ( ( path + ['src', 'ruby', 'acme_service', 'src', 'redist'] ).join("/") )
dir1 = ( ( path + ['acme_scripting', 'src', 'lib'] ).join("/") ) unless File.exist?(dir1)
dir2 = ( ( path + ['acme_service', 'src', 'redist'] ).join("/") ) unless File.exist?(dir2)
$:.unshift dir1 if File.exist?(dir1)
$:.unshift dir2 if File.exist?(dir2)

require 'cougaar/scripting'

require 'getoptlong'

opts = GetoptLong.new( [ '--input', '-i',       GetoptLong::REQUIRED_ARGUMENT],
                       [ '--template', '-t', GetoptLong::REQUIRED_ARGUMENT ],
                       [ '--help', '-h', GetoptLong::NO_ARGUMENT])

input = nil
template = nil
input_type = :unknown
input_basename = nil

def help
  puts "Produces agent.profile.daml files\nUsage:\n\t#$0 -i <input file> -t <template file> [-h]"
  puts "\t-i --input\tThe input file (.xml or .rb)."
  puts "\t-t --template\tThe DAML profile template file."
  puts "\t-h --help\tThis help text."
end

opts.each do |opt, arg|
	case opt
  when '--input'
    input = arg
    if (File.basename(input)!=File.basename(input, ".xml"))
      input_type = :xml 
      input_basename = File.basename(input, ".xml")
    elsif (File.basename(input)!=File.basename(input, ".rb"))
      input_type = :ruby 
      input_basename = File.basename(input, ".rb")
    end
  when '--template'
    template = arg
  when '--help'
    help
    exit 0
	end
end

unless (input)
  puts "Incorrect usage...must supply input file name.\n"
  help
  exit
end

if (input_type==:unknown)
  puts "Unknown file type on input.  Must be .xml or .rb."
  exit
end

unless File.exist?(input)
  puts "Cannot find file: #{input}"
  exit
end

unless (template)
  puts "Incorrect usage...must supply template file name.\n"
  help
  exit
end

unless File.exist?(template)
  puts "Cannot find file: #{template}"
  exit
end

# Output the Service Profile

print "Loading #{input}..."
$stdout.flush
starttime = Time.now
builder = case input_type
when :ruby
  Cougaar::SocietyBuilder.from_ruby_file(input)
when :xml
  Cougaar::SocietyBuilder.from_xml_file(input)
end
soc = builder.society
puts "done."
text_description = Hash.new("No description found. ")
text_description = setup_descriptions(text_description)
generic_wsdl = Hash.new("SupplyProvider")
generic_wsdl = setup_generic_wsdl(generic_wsdl)
template_file = File.open(template, "r")
template_lines = template_file.readlines
cip = ENV["COUGAAR_INSTALL_PATH"]
cip = cip.gsub(/\\/, "/")
first_agent = true
soc.each_agent do |agent|
  has_roles = false
  agent.each_facet( :role ) { | role | has_roles = true }
  if has_roles
    process_agent(agent, cip, template_lines, text_description, generic_wsdl)
  end
end
template_file.close

puts "finished in #{Time.now - starttime} seconds."
$stdout.flush
puts "done."






