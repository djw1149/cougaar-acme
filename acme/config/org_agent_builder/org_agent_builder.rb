require 'csv'

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
                :uic, :home_location
  attr_reader   :roles, :superior, :subordinates, :support_command_assignments

  def initialize
    @roles = []
    @subordinates = []
    @support_command_assignments = []
  end

  def org_id
    @base_org_id + '.' + @suffix
  end

  def to_s
    org_id
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

  def to_xml(indent=0)
    puts " "*indent + "<agent name='#{org_id}'"
    puts " "*indent + "       class='org.cougaar.core.agent.SimpleAgent'>"
    puts " "*indent + "  <facet org_id='#{org_id}' />"
    puts " "*indent + "  <facet superior_org_id='#{superior.to_s}' />"
    @subordinates.each { |sub| puts " "*indent + "  <facet subordinate_org_id='#{sub.to_s}' />"}
    puts " "*indent + "  <facet home_location='#{home_location}' />" if home_location
    puts " "*indent + "  <facet uic='#{uic}' />" if uic
    puts " "*indent + "  <facet combat_support='#{combat_support}' />" if combat_support
    puts " "*indent + "  <facet echelon='#{echelon}' />" if echelon
    puts " "*indent + "  <facet echelon_group='#{echelon_group}' />" if echelon_group
    puts " "*indent + "  <facet is_deployable='#{is_deployable}' />" if is_deployable
    puts " "*indent + "  <facet has_physical_assets='#{has_physical_assets}' />" if has_physical_assets
    puts " "*indent + "  <facet has_equipment_assets='#{has_equipment_assets}' />" if has_equipment_assets
    puts " "*indent + "  <facet has_personnel_assets='#{has_personnel_assets}' />" if has_personnel_assets
    @roles.each { |role|
      puts " "*indent + "  <facet role='#{role.role_id}'"
      puts " "*indent + "         echelon_of_support='#{role.echelon_of_support}'" if role.echelon_of_support
      puts " "*indent + "         mechanism='#{role.mechanism}'" if role.mechanism
      puts " "*indent + "         note='#{role.note}'" if role.note
      puts " "*indent + "  />" }
    @support_command_assignments.each { |sca|
      puts " "*indent + "  <facet sca_supported_org='#{sca.supported_org}'"
      puts " "*indent + "         sca_echelon_of_support='#{sca.echelon_of_support}'"
      puts " "*indent + "  />" }
    puts " "*indent + "</agent>"
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

  XML_HEADER = %Q{
<?xml version="1.0"?>
<society name='JEFF-BERLINER-PROTO'
 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
 xsi:noNamespaceSchemaLocation="http://www.cougaar.org/2003/society.xsd">
  <host name='localhost'>
    <node name='localnode'>
  }
  
  XML_FOOTER = %Q{
    </node>
  </host>
</society>
  }
  
  attr_reader :organizations, :org_id_list
  
  def initialize  
    @organizations = Hash.new
    @org_id_list = Array.new
  end
  
  def parse
    first = true
    CSV.open('org_data/org_attribute.csv',"r") do |row|
      if first
        first = false
        next
      end
      list = row.to_a
      org = Organization.new
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
      @organizations[org.org_id] = org           # Puts the org in the @organizations hash keyed by the org_id
    end
    
    first = true                                # Process org_hierarchy.csv
    CSV.open('org_data/org_hierarchy.csv',"r") do |row|
      if first
        first = false
        next
      end
      list = row.to_a
      org_id = list[2] + '.' + list[3]
      if list[5]
         sup_org_id = list[5] + '.' + list[6]
         org = @organizations[org_id]
         raise "Unknown organization #{org_id}" unless org
         @organizations[org_id].superior=@organizations[sup_org_id]       # orgs know their superior
      end
    end
    
    first = true                                # Process org_role.csv
    CSV.open('org_data/org_role.csv',"r") do |row|
      if first
        first = false
        next
      end
      list = row.to_a
      org_id = list[1] + '.' + list[2]
      org = @organizations[org_id]
      raise "Unknown organization #{org_id}" unless org
      org.roles<<Role.new(list[3],list[4],list[5],list[6])
    end
    
    first = true                                # Process org_support_cmd_assign.csv
    CSV.open('org_data/org_support_cmd_assign.csv',"r") do |row|
      if first
        first = false
        next
      end
      list = row.to_a
      org_id = list[2] + '.' + list[3]
      org = @organizations[org_id]
      raise "Unknown organization #{org_id}" unless org
      supported_org_id = list[5] + '.' + list[6]
      supported_org = @organizations[supported_org_id]
      raise "Unknown supported organization #{supported_org_id}" unless supported_org
      org.support_command_assignments<<SupportCommandAssignment.new(supported_org,list[7])
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
    # Output the orgs and facets in xml
      puts XML_HEADER
      @org_id_list = @organizations.keys                      # Make a list of the org_ids
      @org_id_list.sort!                                      # Sort the list
      @org_id_list.each { |org_id| @organizations[org_id].to_xml(6) }
      puts XML_FOOTER
  end
end

if __FILE__==$0
  #this only executes if you run this file alone (ruby hnac_generator.rb)
  gen = SocietyGenerator.new
  gen.parse
  #gen.print_hierarchy
  #gen.xml_hierarchy
  gen.xml_list
end
