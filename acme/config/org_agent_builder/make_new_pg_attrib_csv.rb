require 'csv'
require 'getoptlong'

class Orginization
  def initialize()
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

  attr_reader :orig_org_id, :base_org_id, :suffix, :org_code, :home_location, :org_nomenclature, :org_type, :role, :org_id,
    :use_full_org_id, :orig_org_id2, :base_org_id2, :suffix2, :service, :agency, :is_reserve
  
  attr_accessor :writer
  
  def initialize(use_full_org_id=true)
    @use_full_org_id = use_full_org_id
    @strip = false
    opts = GetoptLong.new( [ '--org-attribute-csv', '-o', GetoptLong::REQUIRED_ARGUMENT],
			  [ '--new-pg-attr', '-n', GetoptLong::REQUIRED_ARGUMENT],
			  [ '--org-role-csv', '-r', GetoptLong::REQUIRED_ARGUMENT],
			  [ '--strip-headers', '-s', GetoptLong::NO_ARGUMENT],
			  [ '--full-org-id', '-f', GetoptLong::OPTIONAL_ARGUMENT],
			  [ '--help', '-h', GetoptLong::NO_ARGUMENT])
    
    opts.each do |opt, arg|
      case opt
      when '--org-attribute-csv'
	@org_attribute = arg
      when '--new-pg-attr'
	@new_csv = arg
      when '--org-role-csv'
	@org_role = arg
      when '--strip-headers'
	@strip = true
      when '--full-org-id'
	@use_full_org_id = (arg != 'false')        # use_full_org_id is true unless arg is false
      when '--help'
	help
	exit 0
      end
    end
  end

  def org_id
    if @use_full_org_id
      @base_org_id + '.' + @suffix
    else
      @orig_org_id
    end
  end

  def org_id2
    if @use_full_org_id
      @base_org_id2 + '.' + @suffix2
    else
      @orig_org_id2
    end
  end

  def parse
    first = true;
    header = nil;
    @writer = CSV.open(@new_csv, "w")
    if ! @strip
      @writer << ["ORG_ID", "PG_ATTRIBUTE_LIB_ID", "ATTRIBUTE_VALUE", "ATTRIBUTE_ORDER", "START_DATE", "END_DATE", "BLANK"]
    end
    CSV.open(@org_attribute, "r") do |row|
      if first
        header = CSVHeader.new(row)
	first = false
	next
      end
      list = header.list_for(row)
      @orig_org_id = list['orig_org_id']
      @base_org_id = list['base_org_id']
      @suffix = list['suffix']
      @org_code = list['org_code']
      @home_location = list['home_location']
      @org_nomenclature = list['org_nomenclature']
      @org_type = list['org_type_id']
      @service = list['service']
      @agency = list['agency']
      @is_reserve = list['is_reserve']
      write
      write_roles
    end
    @writer.close();
  end

# Make an org class.

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
	@writer << [org_id,"OrganizationPG|Roles","#{role}","0.000000000000000000000000000000","2000-01-01 00:00:00","\\N", " "]
      end
    end
  end

  def help
    puts "Reads in org_attribute.csv and org_role.csv"
    puts "Creates new csv file in the format of org_pg_attribute based on the values in org_attribute.csv"
    puts "Usage: \n\t#$0 -o <org_attribute.csv. [-h]"
    puts "\t-o --org-attribute-csv.....   The org_attribute.csv file"
    puts "\t-n --new-pg-attr...........   The newly created csv file"
    puts "\t-n --org-role-csv..........   The org_role.csv file"
    puts "\t-n --strip-headers.........   Don't write a header in the csv file."
    puts "\t-h --help..................   Prints this help message"
  end

  def write
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

