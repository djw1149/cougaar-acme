
class CVSInfo
  attr_accessor :file_name, :root, :repository, :version, :timestamp

  def initialize( file )
    dir_part, @file_name = File.split( file )
    
    if File.exists?( File.join( dir_part, "CVS" )) then
      root_file = File.new( File.join( dir_part, "CVS", "Root" ))
      repo_file = File.new( File.join( dir_part, "CVS", "Repository" ))
      entr_file = File.new( File.join( dir_part, "CVS", "Entries" ))
  
      root_file.each { |line| @root = line.chomp }
      repo_file.each { |line| @repository = line.chomp }
      entr_file.each { |line|
         data = line.split( /\// )
         if data[1] == @file_name then
           @version = data[2]
           @timestamp = data[3]
         end
      }
    end
  end

  def committed?
    return !(@version.nil?)
  end
end
