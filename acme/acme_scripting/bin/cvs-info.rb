require "rexml/document"
require "p-config"

class CVSPlayground
  def initialize
    `rm -rf #{$POLARIS_CVS_HOME}/*`
    @updates = Hash.new
  end

  def last_update( cvs_root )
    @updates[cvs_root]
  end

  def mkdirs( path )
    dirs = path.split( /\// )
    curr_dir = ""
    dirs.each { |next_level|
      curr_dir = File.join( curr_dir, next_level )
      Dir.mkdir( curr_dir ) unless File.exists?( curr_dir )
    }
  end

  def playground_root( cvs_info )
    empty, ext, user, root = cvs_info.root.split( /:/ )

    dirs = root.split( /\// )
    dirs.delete_at( 0 )

    File.join( $POLARIS_CVS_HOME, dirs )
  end

  def update( cvs_info )
    return if (!last_update( cvs_info.root ).nil? && 
		last_update( cvs_info.root ) > Time.now - (30 * 60))
    
    mod, rest = cvs_info.repository.split( /\// )

    play_root = playground_root( cvs_info )
    unless (File.exist?( play_root ))
      mkdirs( play_root )
    end

    mod_root = File.join( play_root, mod )

    pwd = `pwd`.chomp!    
    Dir.chdir( play_root )
    unless (File.exist?( mod_root )) 
      `export CVS_RSH=ssh && cvs -Q -r -f -d#{cvs_info.root} checkout #{mod}`
      @updates[cvs_info.root] = Time.now
    else
      `cvs -Q -r -f -d#{cvs_info.root} -s CVS_RSH=/usr/bin/ssh update #{mod}`
      @updates[cvs_info.root] = Time.now
    end
    Dir.chdir( pwd )
  end

  def get_file( cvs_info )
    update( cvs_info ) if (last_update( cvs_info.root ).nil?)
    update( cvs_info ) if (last_update( cvs_info.root ) < Time.now - (30 * 60))

    play_root = playground_root( cvs_info )
    File.join( play_root, cvs_info.repository.split( /\// ), cvs_info.file_name )
  end
end

class CVSInfo
  attr_accessor :file_name, :root, :repository, :version, :timestamp

  def initialize( arg )
    if arg.instance_of? (String) then
      file = arg
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
    else 
      if (arg.instance_of?(REXML::Element)) then
        element = arg
        @root = element.elements["root"].text
        @repository = element.elements["repository"].text
        @file_name = element.elements["file"].text
      end
    end
  end

  def committed?
    return !(@version.nil?)
  end
end
