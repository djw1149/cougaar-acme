require 'csv'
require 'getoptlong'

class EC_Policy
  # AN identifier for policies which are identified by echelon_of_support and commodity
  attr_accessor :echelon_of_support, :commodity
  attr_reader   :policies, :ec_name

  def initialize(echelon_of_support, commodity)
    @echelon_of_support = echelon_of_support
    @commodity = commodity
    @ec_name = echelon_of_support + '-' + commodity
    @policies = Hash.new
  end

  def to_xml
    str = ''
    str = '<!-- Inventory Policy for ' + @commodity + ' at ' + @echelon_of_support + 'echelon of support ' + '-->'
    str
  end

  def print_xml(output=$stdout)
    output.puts self.to_xml
    @policies.each_value { |pol| pol.print_xml(output) }
  end

end

class Policy
 # A single policy
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
  
  attr_reader :ec_policies, :policy_csv_file
  
  def initialize  
    @ec_policies = Hash.new
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
    puts "Creates one ec_policy_type xml file for each distinct echelon_commodity pair in policy.csv"
    puts "Usage:\n\t#$0 -p <policy csv file> [-h]"
    puts "\t-p --policy-csv......  The Policy file (.csv)."
    puts "\t-d --policy-dir......  The directory for writing the policy xml files."
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
      echelon_of_support = list[0]
      commodity = list[1]
      ec_name = echelon_of_support + '_' + commodity
      if @ec_policies.has_key?(ec_name)
        ec_policy = @ec_policies[ec_name]
      else
        ec_policy = EC_Policy.new(echelon_of_support, commodity)
        @ec_policies[ec_name] = ec_policy
      end
      policy_name = list[2]
      policy_class = list[3]
      if ec_policy.policies.has_key?(policy_name)
        policy = ec_policy.policies[policy_name]
      else
        policy = Policy.new(policy_name, policy_class)
        ec_policy.policies[policy_name] = policy
      end
      parameter_name = list[4]
      parameter_type = list[5]
      parameter_value = list[6]
      if policy.policy_parameters.has_key?(parameter_name)
        raise "Duplicate policy parameter #{ec_name}, #{policy_name}, #{parameter_name}"
      else
        policy_parameter = PolicyParameter.new(parameter_name, parameter_type, parameter_value)
        policy.policy_parameters[parameter_name] = policy_parameter
      end
    end
  end
  
  def print_policies
    #Print all Policies
    puts "#{@ec_policies.length}" + " EC Policies"
    @ec_policies.each_value { |ec_pol| ec_pol.print_xml }
  end

  def write_xml_policy_files
    # Output the policies in xml
    @ec_policies.each_value { |ec_pol| 
      output = File.open("#{@policy_directory}/InventoryPolicy-#{ec_pol.ec_name}.ldm.xml", "w")
      output.puts XML_HEADER
      ec_pol.print_xml(output)
      output.puts XML_FOOTER
    }
  end

end

if __FILE__==$0
  # This only executes if you run this file alone (ruby make_policy_files.rb)

  pol = PolicyGenerator.new
  pol.parse
  #pol.print_policies
  pol.write_xml_policy_files
end
