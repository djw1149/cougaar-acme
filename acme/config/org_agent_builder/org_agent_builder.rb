require 'csv'
require 'getoptlong'

class CSVHeader
  def initialize(row)
    a = row.to_a
    @column = {}
    a.each_index { |i| @column[a[i].to_s] = i }
  end
  
  def list_for(row)
    @row = row.to_a
    return self
  end
  
  def [](index)
  
    if index.kind_of?(String)
      @row[@column[index]]
    else
      @row[index]
    end
  end
end

class Role
  attr_accessor :role_id, :echelon_of_support, :mechanism, :note

  def initialize(role_id, echelon_of_support=nil, mechanism=nil, note=nil)
    @role_id = role_id
    @echelon_of_support = echelon_of_support
    @mechanism = mechanism
    @note = note
  end

  def to_s
    str = ''
    str << role_id if @role_id
    str << '|'
    str << @echelon_of_support if @echelon_of_support
    str << '|'
    str << @mechanism if @mechanism
    str << '|'
    str << @note if @note
    str
  end

end

class SupportCommandAssignment
  attr_accessor :supported_org, :echelon_of_support

  def initialize(supported_org, echelon_of_support=nil)
    @supported_org = supported_org
    @echelon_of_support = echelon_of_support
  end

  def to_s
    str = ''
    str << @supported_org.to_s if @supported_org
    str << '|'
    str << @echelon_of_support if @echelon_of_support
    str
  end

end
 
class Organization
  attr_accessor :base_org_id, :suffix, :orig_org_id, :org_code, :combat_support, :echelon, :echelon_group,
                :is_deployable, :has_physical_assets, :has_equipment_assets, :has_personnel_assets,
                :uic, :home_location, :use_full_org_id
  attr_reader   :roles, :superior, :subordinates, :support_command_assignments

  def initialize(use_full_org_id=true)
    @use_full_org_id = use_full_org_id              # Optional argument to allow using orig_org_id in the society xml file
    @roles = []
    @subordinates = []
    @support_command_assignments = []
  end

  def org_id
    @base_org_id + '.' + @suffix
  end

  def to_s
    if @use_full_org_id
      org_id
    else
      orig_org_id
    end
  end

  def hierarchy_to_s(indent=0)
    puts " "*indent + self.to_s
    puts " "*indent + " is_deployable" if is_deployable
    puts " "*indent + " has_physical_assets" if has_physical_assets
    puts " "*indent + " has_equipment_assets" if has_equipment_assets
    puts " "*indent + " has_personnel_assets" if has_personnel_assets
    puts " "*indent + " uic: " + uic if uic
    puts " "*indent + " home_location: " + home_location if home_location
    @roles.each { |role| puts " "*indent + " role: " + role.to_s }
    @support_command_assignments.each { |sca| puts " "*indent + " sca:  " + sca.to_s }
    @subordinates.each { |sub| sub.hierarchy_to_s(indent+4) }
  end

  def hierarchy_to_xml(indent=0)
    self.to_xml(indent)
    @subordinates.each { |sub| sub.hierarchy_to_xml(indent) }
  end

  def to_xml(indent=0, output=$stdout)
    output.puts " "*indent + "<agent name='#{self.to_s}'"
    output.puts " "*indent + "       class='org.cougaar.core.agent.SimpleAgent'>"
    output.puts " "*indent + "  <facet org_id='#{self.to_s}' />"
    output.puts " "*indent + "  <facet orig_org_id='#{orig_org_id}' />"
    output.puts " "*indent + "  <facet superior_org_id='#{superior.to_s}' />"
    @subordinates.each { |sub| output.puts " "*indent + "  <facet subordinate_org_id='#{sub.to_s}' />"}
    output.puts " "*indent + "  <facet home_location='#{home_location}' />" if home_location
    output.puts " "*indent + "  <facet uic='#{uic}' />" if uic
    output.puts " "*indent + "  <facet combat_support='#{combat_support}' />" if combat_support
    output.puts " "*indent + "  <facet echelon='#{echelon}' />" if echelon
    output.puts " "*indent + "  <facet echelon_group='#{echelon_group}' />" if echelon_group
    output.puts " "*indent + "  <facet is_deployable='#{is_deployable}' />" if is_deployable
    output.puts " "*indent + "  <facet has_physical_assets='#{has_physical_assets}' />" if has_physical_assets
    output.puts " "*indent + "  <facet has_equipment_assets='#{has_equipment_assets}' />" if has_equipment_assets
    output.puts " "*indent + "  <facet has_personnel_assets='#{has_personnel_assets}' />" if has_personnel_assets
    @roles.each { |role|
      output.puts " "*indent + "  <facet role='#{role.role_id}'"
      output.puts " "*indent + "         echelon_of_support='#{role.echelon_of_support}'" if role.echelon_of_support
      output.puts " "*indent + "         mechanism='#{role.mechanism}'" if role.mechanism
      output.puts " "*indent + "         note='#{role.note}'" if role.note
      output.puts " "*indent + "  />" }
    @support_command_assignments.each { |sca|
      output.puts " "*indent + "  <facet sca_supported_org='#{sca.supported_org}'"
      output.puts " "*indent + "         sca_echelon_of_support='#{sca.echelon_of_support}'"
      output.puts " "*indent + "  />" }
    output.puts " "*indent + "</agent>"
  end

  def big_cheese
    return self unless @superior
    @superior.big_cheese
  end

  def superior=(sup)
    if sup.nil?
      @superior = nil
      return
    end
    raise 'superior must be an organization' unless sup.kind_of?(Organization)
    raise 'cannot be my own superior' if sup == self
    @superior = sup
    @superior.subordinates<<self                  # Tell my superior about me

  end

end

class SocietyGenerator

  XML_HEADER = %Q{<?xml version="1.0"?>
<society name='JEFF-BERLINER-PROTO'
 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
 xsi:noNamespaceSchemaLocation="http://www.cougaar.org/2003/society.xsd">
  <host name='localhost'>
    <node name='localnode'>}
  
  XML_FOOTER = %Q{    </node>
  </host>
</society>}
  
  attr_reader :organizations, :org_id_list, :society_member_file, :society_member, :society_file, :use_full_org_id
  
  def initialize  
    @organizations = Hash.new
    @org_id_list = Array.new
    @org_data_directory = nil
    @society_member_file = nil
    @society_member_list = Array.new
    @society_file = nil
    @use_full_org_id = true                     # Default is to use full org_id, not orig_org_id
    opts = GetoptLong.new( [ '--org-data-directory', '-d', GetoptLong::OPTIONAL_ARGUMENT],
                           [ '--society-member', '-m', GetoptLong::OPTIONAL_ARGUMENT],
                           [ '--society',  '-s', GetoptLong::OPTIONAL_ARGUMENT],
                           [ '--full-org-id', '-f', GetoptLong::OPTIONAL_ARGUMENT],
						   [ '--help',    '-h', GetoptLong::NO_ARGUMENT])

    opts.each do |opt, arg|
      case opt
      when '--org-data-directory'
        @org_data_directory = arg
      when '--society-member'
        @society_member_file = arg
      when '--society'
        @society_file = arg
      when '--full-org-id'
        @use_full_org_id = (arg != 'false')        # use_full_org_id is true unless arg is false
      when '--help'
        help
        exit 0
      end
    end

    @org_data_directory = '1ad.org_data' unless @org_data_directory               # 1ad.org_data is the default for @org_data_directory

    if @society_member_file
      @society_member_file = @org_data_directory + '/' + @society_member_file # Look in org_data_directory for society_member_file
      unless File.exist?(@society_member_file)
        raise "Cannot find Society member input file: #{@society_member_file}"
        exit
      end
      unless (File.basename(@society_member_file)!=File.basename(@society_member_file, ".csv"))
        raise "Society member file type must be .csv: #{@society_member_file}"
      end
    end

    if @society_file
      unless (File.basename(@society_file)!=File.basename(@society_file, ".xml"))
        raise "Society file type must be .xml: #{@society_file}"
      end
    end
  end
  
  def help
    puts "Reads OrgData/org_attribute.csv, OrgData/org_hierarchy.csv, OrgData/org_role.csv, and OrgData/org_sca.csv and writes society.xml"
    puts "If the OrgData directory is not specified, the directory 1ad.org_data/ is used."
    puts "If society_member_file is specified, just the orgs in OrgData/society_member_file.csv are included in the society."
    puts "If output file is specified society.xml is written there, otherwise society.xml is written to stdout."
    puts "If full-org-id is set false, then the orig-org-id is used, otherwise the full-org-id is used."
    puts "Usage:\n\t#$0 [-d <org-data-directory>] [-m <society member file>] [-s <society file>] [-h]"
    puts "\t-d --org-data-directory..  The OrgData directory (org_data)."
    puts "\t-m --society-member......  The SocietyMember file (.csv)."
    puts "\t-s --society.............  The society file (.xml)."
    puts "\t-f --full-org-id.........  Boolean to use full-org-id or orig-org_id."
    puts "\t-h --help................  Prints this help message."
  end

  def parse
    header = nil
    first = true                                # Process org_attribute.csv
    CSV.open("#{@org_data_directory}/org_attribute.csv","r") do |row|
      if first
        header = CSVHeader.new(row)
        first = false
        next
      end
      list = header.list_for(row)
      org = Organization.new(@use_full_org_id)
      org.orig_org_id = list[1]
      org.base_org_id = list[2]
      org.suffix = list[3]
      org.combat_support = list[5]
      org.echelon = list[6]
      org.echelon_group = list[7]
      org.is_deployable = 'T' if list[8] =~ /^[yYtT]/
      org.has_physical_assets = 'T' if list[9] =~ /^[yYtT]/
      org.has_equipment_assets = 'T' if list[10] =~ /^[yYtT]/
      org.has_personnel_assets = 'T' if list[11] =~ /^[yYtT]/
      org.uic = list[12]
      org.home_location = list[13]
      @organizations[org.org_id] = org            # Puts the org in the @organizations hash keyed by the org_id
    end
    @org_id_list = @organizations.keys            # Make a list of the org_ids
    
    if @society_member_file
      first = true                                # Process society_member_file (Subset of the orgs to be output)
      CSV.open(@society_member_file,"r") do |row|
        if first
          header = CSVHeader.new(row)
          first = false
          next
        end
        list = header.list_for(row)
        org_id = list[2] + '.' + list[3]
        org = @organizations[org_id]
        raise "Unknown organization #{org_id}" unless org
        @society_member_list<<org_id
      end
    else
      @society_member_list = @org_id_list          # if no society_member_file, all orgs are members
    end

    # @organizations.delete_if { |org_id, org| !@society_member_list.include?(org_id) } # Don't do it this way

    first = true                                # Process org_hierarchy.csv
    CSV.open("#{@org_data_directory}/org_hierarchy.csv","r") do |row|
      if first
        header = CSVHeader.new(row)
        first = false
        next
      end
      list = header.list_for(row)
      org_id = list[2] + '.' + list[3]
      if list[5]
        sup_org_id = list[5] + '.' + list[6]
        org = @organizations[org_id]
        raise "Unknown organization #{org_id}" unless org
        sup_org = @organizations[sup_org_id]
        raise "Unknown superior organization #{sup_org_id}" unless sup_org
        if (@society_member_list.include?(org_id) &&
            @society_member_list.include?(sup_org_id))                  # Make sure org and sup_org are members
          @organizations[org_id].superior=@organizations[sup_org_id]    # orgs know their superior
        end
      end
    end
    
    first = true                                # Process org_role.csv
    CSV.open("#{@org_data_directory}/org_role.csv","r") do |row|
      if first
        header = CSVHeader.new(row)
        first = false
        next
      end
      list = header.list_for(row)
      org_id = list[1] + '.' + list[2]
      org = @organizations[org_id]
      raise "Unknown organization #{org_id}" unless org
      org.roles<<Role.new(list[3],list[4],list[5],list[6])
    end
    
    first = true                                # Process org_sca.csv (Support Command Assignments)
    CSV.open("#{@org_data_directory}/org_sca.csv","r") do |row|
      if first
        header = CSVHeader.new(row)
        first = false
        next
      end
      list = header.list_for(row)
      org_id = list[2] + '.' + list[3]
      org = @organizations[org_id]
      raise "Unknown organization #{org_id}" unless org
      supported_org_id = list[5] + '.' + list[6]
      echelon_of_support = list[7]
      supported_org = @organizations[supported_org_id]
      raise "Unknown supported organization #{supported_org_id}" unless supported_org
      if (@society_member_list.include?(org_id) &&
          @society_member_list.include?(supported_org_id))            # Make sure org and supported_org are members
        org.support_command_assignments<<SupportCommandAssignment.new(supported_org,echelon_of_support)
      end
    end

  end
  
  def print_hierarchy
    #Print org hierarchy
    @organizations.values[0].big_cheese.hierarchy_to_s
  end

  def xml_hierarchy
    # Output the orgs and facets in xml
    puts XML_HEADER
    @organizations.values[0].big_cheese.hierarchy_to_xml(6)
    puts XML_FOOTER
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

  gen = SocietyGenerator.new
  gen.parse
  #gen.print_hierarchy
  #gen.xml_hierarchy
  gen.xml_list
end
