require 'csv'
require 'getoptlong'

class Make_NewPG

  attr_reader :base_org_id, :suffix, :org_code, :home_location, :nomenclature, :org_type, :role
  attr_accessor :writer

  def initialize 
    @strip = false
    opts = GetoptLong.new( [ '--org-attribute-csv', '-o', GetoptLong::REQUIRED_ARGUMENT],
                           [ '--new-pg-attr', '-n', GetoptLong::REQUIRED_ARGUMENT],
                           [ '--org-role-csv', '-r', GetoptLong::REQUIRED_ARGUMENT],
                           [ '--strip-headers', '-s', GetoptLong::NO_ARGUMENT],
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
        when '--help'
          help
          exit 0
        end
    end
  end

  def parse
    first = true;
    @writer = CSV.open(@new_csv, "w")
    CSV.open(@org_attribute, "r") do |row|
      if first
	first = false
	next
      end
      list = row.to_a
      @base_org_id = list[2]
      @suffix = list[3]
      @org_code = list[13]
      @home_location = list[11]
      @nomenclature = list[14]
      @org_type = list[15]
      write
      writeroles
    end
    @writer.close();
  end

  def writeroles
    first2 = true
    CSV.open(@org_role, "r") do |row2|
      if first2
	first2 = false;
	next
      end
      list2 = row2.to_a
      @role = list2[3]
      if @base_org_id == list2[1]
	@writer << [@base_org_id,"OrganizationPG|Roles","#@role","0.000000000000000000000000000000","2000-01-01 00:00:00","\N", ""]
      end
    end
  end

  def help
    puts "Reads in org_attribute.csv"
    puts "Creates new csv file in the format of org_pg_attribute based on the values in org_attribute.csv"
    puts "Usage: \n\t#$0 -o <org_attribute.csv. [-h]"
    puts "\t-o --org-attribute-csv.....   The org_attribute.csv file"
    puts "\t-n --new-pg-attr...........   The newly created csv file"
    puts "\t-n --org-role-csv..........   The org_role.csv file"
    puts "\t-n --strip-headers.........   Don't write a header in the csv file."
    puts "\t-h --help..................   Prints this help message"
  end

  def write
    if ! @strip
      @writer << ["ORG_ID", "PG_ATTRIBUTE_LIB_ID", "ATTRIBUTE_VALUE", "ATTRIBUTE_ORDER", "START_DATE", "END_DATE", "BLANK"]
    end
    @writer << [@base_org_id,"ItemIdentificationPG|AlternateItemIdentification","UIC/#@org_code","0.000000000000000000000000000000","2000-01-01 00:00:00","\N", ""]
    @writer << [@base_org_id,"ClusterPG|MessageAddress","#@base_org_id","0.000000000000000000000000000000","2000-01-01 00:00:00","\N", ""]
    @writer << [@base_org_id,"TypeIdentificationPG|TypeIdentification","UTC/#@org_type","0.000000000000000000000000000000","2000-01-01 00:00:00","\N", ""]
    @writer << [@base_org_id,"TypeIdentificationPG|Nomenclature","#@nomenclature","0.000000000000000000000000000000","2000-01-01 00:00:00","\N", ""]
    @writer << [@base_org_id,"OrganizationPG|Service","Army","0.000000000000000000000000000000","2000-01-01 00:00:00","\N", ""]
    @writer << [@base_org_id,"OrganizationPG|Agency","ARMY","0.000000000000000000000000000000","2000-01-01 00:00:00","\N", ""]
    @writer << [@base_org_id,"MilitaryOrgPG|UTC","#@org_type","0.000000000000000000000000000000","2000-01-01 00:00:00","\N", ""]
    @writer << [@base_org_id,"MilitaryOrgPG|UIC","#@org_code","0.000000000000000000000000000000","2000-01-01 00:00:00","\N", ""]
    @writer << [@base_org_id,"MilitaryOrgPG|IsReserve","FALSE","0.000000000000000000000000000000","2000-01-01 00:00:00","\N", ""]
    @writer << [@base_org_id,"MilitaryOrgPG|HomeLocation","GeoLocCode=#@home_location","0.000000000000000000000000000000","2000-01-01 00:00:00","\N", ""]
    @writer << [@base_org_id,"ItemIdentificationPG|Nomenclature","#@nomenclature","0.000000000000000000000000000000","2000-01-01 00:00:00","\N", ""]
    @writer << [@base_org_id,"ItemIdentificationPG|ItemIdentification","#@base_org_id","0.000000000000000000000000000000","2000-01-01 00:00:00","\N", ""]
  end

end

pg = Make_NewPG.new
pg.parse

