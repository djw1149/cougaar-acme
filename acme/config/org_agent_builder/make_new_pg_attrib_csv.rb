require 'csv'
require 'getoptlong'

class Organization
  attr_accessor :base_org_id, :suffix, :orig_org_id, :org_code, :combat_support, :echelon, :echelon_group,
                :is_deployable, :has_physical_assets, :has_equipment_assets, :has_personnel_assets,
                :uic, :home_location, :use_full_org_id, :service, :agency, :is_reserve, :org_nomenclature, :org_type
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

  def to_pgs(writer)
    writer << ["#{self.to_s}","ItemIdentificationPG|AlternateItemIdentification","OrgCode/#{org_code}","0.000000000000000000000000000000","2000-01-01 00:00:00","\\N", " "]
    writer << ["#{self.to_s}","ClusterPG|MessageAddress","#{self.to_s}","0.000000000000000000000000000000","2000-01-01 00:00:00","\\N", " "]
    writer << ["#{self.to_s}","TypeIdentificationPG|TypeIdentification","UAType/#{org_type}","0.000000000000000000000000000000","2000-01-01 00:00:00","\\N", " "]
    writer << ["#{self.to_s}","TypeIdentificationPG|Nomenclature","#{org_type}","0.000000000000000000000000000000","2000-01-01 00:00:00","\\N", " "]
    writer << ["#{self.to_s}","OrganizationPG|Service","#{service}","0.000000000000000000000000000000","2000-01-01 00:00:00","\\N", " "]
    writer << ["#{self.to_s}","OrganizationPG|Agency","#{agency}","0.000000000000000000000000000000","2000-01-01 00:00:00","\\N", " "]
    writer << ["#{self.to_s}","MilitaryOrgPG|UTC","#{org_type}","0.000000000000000000000000000000","2000-01-01 00:00:00","\\N", " "]
    writer << ["#{self.to_s}","MilitaryOrgPG|UIC","#{org_code}","0.000000000000000000000000000000","2000-01-01 00:00:00","\\N", " "]
    reserve = 'TRUE'
    if @is_reserve == 'N'
      reserve = 'FALSE'
    end
    writer << ["#{self.to_s}","MilitaryOrgPG|IsReserve","#{reserve}","0.000000000000000000000000000000","2000-01-01 00:00:00","\\N", " "]
    writer << ["#{self.to_s}","MilitaryOrgPG|HomeLocation","GeoLocCode=#{home_location}","0.000000000000000000000000000000","2000-01-01 00:00:00","\\N", " "]
    writer << ["#{self.to_s}","ItemIdentificationPG|Nomenclature","#{self.to_s}","0.000000000000000000000000000000","2000-01-01 00:00:00","\\N", " "]
    writer << ["#{self.to_s}","ItemIdentificationPG|ItemIdentification","#{self.to_s}","0.000000000000000000000000000000","2000-01-01 00:00:00","\\N", " "]
    @roles.each { |role| role.to_csv(writer) }
  end

  def to_orgs(writer)
    writer << ["#{self.to_s}", "#{self.to_s}", "#{org_code}", "MilitaryOrganization"]
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

  def to_csv(writer)
    writer << ["#{self.to_s}","OrganizationPG|Roles","#{role_id}","0.000000000000000000000000000000","2000-01-01 00:00:00","\\N", " "]
  end
end

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

class Make_NewPG

  attr_reader :organizations, :use_full_org_id, :new_pg_attr_csv, :new_lib_org_csv, :strip, :org_data_directory

#  attr_reader :orig_org_id, :base_org_id, :suffix, :org_code, :home_location, :org_nomenclature, :org_type, :role, :org_id,
#    :use_full_org_id, :orig_org_id2, :base_org_id2, :suffix2, :service, :agency, :is_reserve

  attr_accessor :writer

  def initialize(use_full_org_id=true)
    @organizations = Hash.new
    @use_full_org_id = use_full_org_id
    @org_data_directory = nil
    @new_pg_attr_csv = nil
    @new_lib_org_csv = nil
    @strip = false
    opts = GetoptLong.new( [ '--org-data-directory', '-d', GetoptLong::OPTIONAL_ARGUMENT],
                          [ '--new-pg-attr', '-p', GetoptLong::REQUIRED_ARGUMENT],
                          [ '--new-lib-organization', '-l', GetoptLong::REQUIRED_ARGUMENT],
                          [ '--strip-headers', '-s', GetoptLong::NO_ARGUMENT],
                          [ '--full-org-id', '-f', GetoptLong::OPTIONAL_ARGUMENT],
                          [ '--help', '-h', GetoptLong::NO_ARGUMENT])

    opts.each do |opt, arg|
      case opt
      when '--org-data-directory'
        @org_data_directory = arg
      when '--new-pg-attr'
        @new_pg_attr_csv = arg
      when '--new-lib-organization'
        @new_lib_org_csv = arg
      when '--strip-headers'
        @strip = (arg != 'true')
      when '--full-org-id'
        @use_full_org_id = (arg != 'false')        # use_full_org_id is true unless arg is false
      when '--help'
        help
        exit 0
      end
    end

    @org_data_directory = '1ad.org_data' unless @org_data_directory               # 1ad.org_data is the default for @org_data_directory

    if @new_lib_org_csv == nil
      @new_lib_org_csv = "new_lib_org.csv"
    end

    if @new_pg_attr_csv == nil
      @new_pg_attr_csv = "new_pg_attr.csv"
    end
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
      org.orig_org_id = list['orig_org_id']
      org.base_org_id = list['base_org_id']
      org.suffix = list['suffix']
      org.org_code = list['org_code']
      org.home_location = list['home_location']
      org.org_nomenclature = list['org_nomenclature']
      org.org_type = list['org_type_id']
      org.service = list['service']
      org.agency = list['agency']
      org.is_reserve = list['is_reserve']
      @organizations[org.org_id] = org            # Puts the org in the @organizations hash keyed by the org_id
    end
    @org_id_list = @organizations.keys            # Make a list of the org_ids

    first = true                                # Process org_role.csv
    CSV.open("#{@org_data_directory}/org_role.csv","r") do |row|
      if first
        header = CSVHeader.new(row)
        first = false
        next
      end
      list = header.list_for(row)
      org_id = list['base_org_id'] + '.' + list['org_id_suffix']
      org = @organizations[org_id]
      raise "Unknown organization #{org_id}" unless org
      org.roles<<Role.new(list['role'],list['echelon_of_support'],list['role_mechanism'],list['notes'])
    end
  end

  def create_pg_attr_file
    @writer = CSV.open("#{@org_data_directory}/#{@new_pg_attr_csv}", "w")
    if ! @strip
      @writer << ["ORG_ID", "PG_ATTRIBUTE_LIB_ID", "ATTRIBUTE_VALUE", "ATTRIBUTE_ORDER", "START_DATE", "END_DATE", "BLANK"]
    end
    @org_id_list = @organizations.keys
    @org_id_list.each { |org_id| @organizations[org_id].to_pgs(writer) }
    @writer.close
  end

  def create_lib_org_file
    @writer = CSV.open("#{@org_data_directory}/#{@new_lib_org_csv}", "w")
    if ! @strip
      @writer << ["ORG_ID", "ORG_NAME", "UIC", "ORG_CLASS"]
    end
    @org_id_list = @organizations.keys
    @org_id_list.each { |org_id| @organizations[org_id].to_orgs(writer) }
    @writer.close
  end

  def write_roles
    first2 = true
    header2 = nil
    CSV.open(@org_role, "r") do |row2|
      if first2
        header2 = CSVHeader.new(row2)
        first2 = false;
        next
      end
      list2 = header2.list_for(row2)
      @base_org_id2 = list2['base_org_id']
      @suffix2 = list2['org_id_suffix']
      @orig_org_id2 = list2['orig_org_id']
      role = list2['role']
      if org_id == org_id2
      end
    end
  end

  def help
    puts "Reads in org_attribute.csv and org_role.csv"
    puts "Creates new csv file in the format of org_pg_attribute based on the values in org_attribute.csv"
    puts "If the OrgData directory is not specified, the directory 1ad.org_data/ is used."
    puts "If full-org-id is set false, then the orig-org-id is used, otherwise the full-org-id is used."
    puts "If new-pg-attr is not defined, new_pg_attr.csv is used."
    puts "If new-lib-organization is not defined, new_lib_organization.csv is used."
    puts "Usage: \n\t#$0 [-h]"
    puts "\t-d --org-data-directory....   The OrgData directory (1ad.org_data)."
    puts "\t-p --new-pg-attr...........   The newly created pg-attr csv file"
    puts "\t-l --new-lib-organization..   The newly created lib-organization csv file"
    puts "\t-s --strip-headers.........   Booleam to write a header in the csv file."
    puts "\t-f --full-org-id...........   Boolean to use full-org-id or orig-org_id."
    puts "\t-h --help..................   Prints this help message"
  end

  def write_pg_attr
    @writer << [org_id,"ItemIdentificationPG|AlternateItemIdentification","OrgCode/#@org_code","0.000000000000000000000000000000","2000-01-01 00:00:00","\\N", " "]
    @writer << [org_id,"ClusterPG|MessageAddress",org_id,"0.000000000000000000000000000000","2000-01-01 00:00:00","\\N", " "]
    @writer << [org_id,"TypeIdentificationPG|TypeIdentification","UAType/#@org_type","0.000000000000000000000000000000","2000-01-01 00:00:00","\\N", " "]
    @writer << [org_id,"TypeIdentificationPG|Nomenclature","#@org_type","0.000000000000000000000000000000","2000-01-01 00:00:00","\\N", " "]
    @writer << [org_id,"OrganizationPG|Service","#@service","0.000000000000000000000000000000","2000-01-01 00:00:00","\\N", " "]
    @writer << [org_id,"OrganizationPG|Agency","#@agency","0.000000000000000000000000000000","2000-01-01 00:00:00","\\N", " "]
    @writer << [org_id,"MilitaryOrgPG|UTC","#@org_type","0.000000000000000000000000000000","2000-01-01 00:00:00","\\N", " "]
    @writer << [org_id,"MilitaryOrgPG|UIC","#@org_code","0.000000000000000000000000000000","2000-01-01 00:00:00","\\N", " "]
    reserve = 'TRUE'
    if @is_reserve == 'N'
      reserve = 'FALSE'
    end
    @writer << [org_id,"MilitaryOrgPG|IsReserve","#{reserve}","0.000000000000000000000000000000","2000-01-01 00:00:00","\\N", " "]
    @writer << [org_id,"MilitaryOrgPG|HomeLocation","GeoLocCode=#@home_location","0.000000000000000000000000000000","2000-01-01 00:00:00","\\N", " "]
    @writer << [org_id,"ItemIdentificationPG|Nomenclature",org_id,"0.000000000000000000000000000000","2000-01-01 00:00:00","\\N", " "]
    @writer << [org_id,"ItemIdentificationPG|ItemIdentification",org_id,"0.000000000000000000000000000000","2000-01-01 00:00:00","\\N", " "]
  end
end

pg = Make_NewPG.new
pg.parse
pg.create_pg_attr_file
pg.create_lib_org_file
