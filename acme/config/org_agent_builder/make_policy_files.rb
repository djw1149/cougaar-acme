require 'csv'
require 'getoptlong'

class PolicyOrgType
  attr_accessor :policy_org_type_name
  attr_reader   :policies

  def initialize(policy_org_type_name)
    @policy_org_type_name = policy_org_type_name
    @policies = Hash.new
  end

  def to_xml
    str = ''
    str = '<!-- Inventory Policy for ' + @policy_org_type_name + '-->'
    str
  end

  def print_xml(output=$stdout)
    output.puts self.to_xml
    @policies.each_value { |pol| pol.print_xml(output) }
  end

end

class Policy
  attr_accessor :policy_name, :policy_class
  attr_reader   :policy_parameters

  def initialize(policy_name, policy_class)
    @policy_name = policy_name
    @policy_class = policy_class
    @policy_parameters = Hash.new
  end

  def to_xml
    str = ''
    str << ' <Policy name = "' + @policy_name + '" type="' + @policy_class + '">'
    str
  end

  def print_xml(output=$stdout)
    output.puts self.to_xml
    @policy_parameters.each_value { |param| param.print_xml(output) }
    output.puts ' </Policy>'
  end

end

class PolicyParameter
  attr_accessor :parameter_name, :parameter_type, :parameter_value

  def initialize(parameter_name, parameter_type, parameter_value)
    @parameter_name = parameter_name
    @parameter_type = parameter_type
    @parameter_value = parameter_value
  end

  def to_xml
    str = ''
    str << '    <RuleParam name="' + @parameter_name + '">' + "\n"
    str << '        <' + @parameter_type + ' value = "' + @parameter_value +  '"'
    if @parameter_type == 'Integer'
      str << ' min="0" max="1000"'
    end
    str << ">\n"
    str << '        </' + @parameter_type + '>' + "\n"
    str << '    </RuleParam>'
    str
  end

  def print_xml(output=$stdout)
    output.puts self.to_xml
  end

end

class PolicyGenerator

  XML_HEADER = %Q{<?xml version="1.0"  encoding="US-ASCII"?>
<!DOCTYPE Policy SYSTEM "Policy.ldm.dtd" []>
<Policies>}
  XML_FOOTER = %Q{</Policies>}
  
  attr_reader :policy_org_types, :policy_csv_file
  
  def initialize  
    @policy_org_types = Hash.new
    @policy_csv_file = nil

    opts = GetoptLong.new( [ '--policy-csv', '-p', GetoptLong::REQUIRED_ARGUMENT],
                           [ '--policy-dir', '-d', GetoptLong::OPTIONAL_ARGUMENT],
						   [ '--help',    '-h', GetoptLong::NO_ARGUMENT])

    opts.each do |opt, arg|
      case opt
      when '--policy-csv'
        @policy_csv_file = arg
      when '--policy-dir'
        @policy_directory = arg
      when '--help'
        help
        exit 0
      end
    end

    if @policy_csv_file
      unless (File.basename(@policy_csv_file)!=File.basename(@policy_csv_file, ".csv"))
        raise "Policy CSV file type must be .csv: #{@policy_csv_file}"
      end
    else
      raise "Policy CSV file is a required argument."
    end

    unless @policy_directory
      @policy_directory = 'policy'
    end

  end
  
  def help
    puts "Reads policy.csv"
    puts "Creates one policy_org_type xml file for each org_type in policy.csv"
    puts "Usage:\n\t#$0 -p <policy csv file> [-h]"
    puts "\t-p --policy-csv......  The Policy file (.csv)."
    puts "\t-p --policy-dir......  The directory for writing the policy xml files."
    puts "\t-h --help............  Prints this help message."
  end

  def parse
    first = true                                # Process policy_csv_file
    CSV.open(@policy_csv_file,"r") do |row|
      if first
        first = false
        next
      end
      list = row.to_a
      policy_org_type_name = list[0]
      if @policy_org_types.has_key?(policy_org_type_name)
        policy_org_type = @policy_org_types[policy_org_type_name]
      else
        policy_org_type = PolicyOrgType.new(policy_org_type_name)
        @policy_org_types[policy_org_type_name] = policy_org_type
      end
      policy_name = list[1]
      policy_class = list[2]
      if policy_org_type.policies.has_key?(policy_name)
        policy = policy_org_type.policies[policy_name]
      else
        policy = Policy.new(policy_name, policy_class)
        policy_org_type.policies[policy_name] = policy
      end
      parameter_name = list[3]
      parameter_type = list[4]
      parameter_value = list[5]
      if policy.policy_parameters.has_key?(parameter_name)
        raise "Duplicate policy parameter #{policy_org_type_name}, #{policy_name}, #{parameter_name}"
      else
        policy_parameter = PolicyParameter.new(parameter_name, parameter_type, parameter_value)
        policy.policy_parameters[parameter_name] = policy_parameter
      end
    end
  end
  
  def print_policies
    #Print all Policies
    puts "#{@policy_org_types.length}" + " Policy Orgs"
    @policy_org_types.each_value { |pot| pot.print_xml }
  end

  def write_xml_policy_files
    # Output the orgs and facets in xml
    @policy_org_types.each_value { |pot| 
      output = File.open("#{@policy_directory}/InventoryPolicy-#{pot.policy_org_type_name}.ldm.xml", "w")
      output.puts XML_HEADER
      pot.print_xml(output)
      output.puts XML_FOOTER
    }
  end

  def xml_list
    # Open the output and write the orgs and facets in xml
    if @society_file
      output = File.open(@society_file, "w")
    else
      output = $stdout
    end
    output.puts XML_HEADER
    @org_id_list = @organizations.keys                      # Make a list of the org_ids
    if @society_member_file
      xml_list = @org_id_list && @society_member_list
    else
      xml_list = @org_id_list
    end
    xml_list.sort!
    xml_list.each { |org_id| @organizations[org_id].to_xml(6,output) }
    output.puts XML_FOOTER
  end

end

if __FILE__==$0
  # This only executes if you run this file alone (ruby hnac_generator.rb)

  pol = PolicyGenerator.new
  pol.parse
  #pol.print_policies
  pol.write_xml_policy_files
  #pol.xml_list
end
