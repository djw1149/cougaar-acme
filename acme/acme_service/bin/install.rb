#! /usr/bin/env ruby

require 'ftools'

SRC = 'src'

Dir.chdir ".." if Dir.pwd =~ /bin.?$/

require 'getoptlong'
require 'find'

opts = GetoptLong.new( [ '--uninstall',	'-u',		GetoptLong::NO_ARGUMENT],
											[ '--target', '-t', GetoptLong::REQUIRED_ARGUMENT ],
											[ '--jabber-host', '-j', GetoptLong::REQUIRED_ARGUMENT ],
											[ '--jabber-account', '-a', GetoptLong::REQUIRED_ARGUMENT ],
											[ '--jabber-password', '-p', GetoptLong::REQUIRED_ARGUMENT ],
											[ '--jvm-path', '-v', GetoptLong::REQUIRED_ARGUMENT ],
											[ '--linux-props', '-l', GetoptLong::REQUIRED_ARGUMENT ],
											[ '--help', '-h', GetoptLong::NO_ARGUMENT],
											[ '--noop', '-n', GetoptLong::NO_ARGUMENT])


destdir = File.join "", "usr", "local", "acme"

uninstall = false
@jabber_host = 'acme'
@jabber_account = nil
@jabber_password = nil
@jvm_path = "/usr/java/j2sdk1.4.1/bin/java"
@linux_props = "/mnt/shared/acme_config/Linux.props"

opts.each do |opt, arg|
	case opt
		when '--uninstall'
			uninstall = true
    when '--jabber-host'
      @jabber_host = arg
    when '--jabber-account'
      @jabber_account = arg
    when '--jabber-password'
      @jabber_password = arg
    when '--jvm-path'
      @jvm_path = arg
    when '--linux-props'
      @linux_props = arg
		when '--target'
			destdir = arg
		when '--help'
			puts "Installs the ACME Service.\nUsage:\n\t#$0 [[-u] [-n] [-t <dir>] [-j <jabberhost>] [-a <account>]\n\t\t\t [-p <pwd>] [-v <jvm path>] [-l <linux props path>] -h]"
			puts "\t-u --uninstall\t\tUninstalls the package"
			puts "\t-t --target\t\tInstalls the software at an absolute location, EG:"
			puts "\t\t\t\t#$0 -t /usr/local/acme"
			puts "\t\t\t\twill put the software directly underneath /usr/local/acme"
      puts "\t-j --jabber-host\tThe jabber host (default 'acme')."
      puts "\t-a --jabber-account\tThe jabber account (default <hostname>)."
      puts "\t-p --jabber-password\tThe jabber password (default <hostname>_password)."
      puts "\t-v --jvm-path\t\tThe JVM path to start nodes with."
      puts "\t\t\t\t(default '/usr/java/j2sdk1.4.1/bin/java')"
      puts "\t-l --linux-props\tThe Linux.props path to start the node with."
      puts "\t\t\t\t(default '/mnt/shared/acme_config/Linux.props')"
			puts "\t-n --noop\t\tDon't actually do anything; just print out what it"
			puts "\t\t\t\twould do."
			exit 0
		when '--noop'
			NOOP = true
	end
end

def install destdir
	puts "Installing in #{destdir}"
	begin
		Find.find(SRC) { |file|
			next if file =~ /CVS|\.svn|\.DS_Store/
      name = file[(SRC.size+1)..-1]
			dst = File.join(destdir, name)
			if defined? NOOP
        puts "<< #{file}"
				puts ">> #{dst}" #if file =~ /\.rb$/
			else
				File.makedirs( File.dirname(dst) ) # unless File.exist?(File.dirname(dst))
        unless File.directory?(file)
          File.install(file, dst, 0644, true) #if file =~ /\.rb$/
        end
			end
		}
	rescue
		puts $!
	end
  unless defined? NOOP
    puts "Writing acme_cougaar_node properties..."
    path = File.join(destdir, 'plugins', 'acme_cougaar_node', 'properties.yaml')
    File.open(path, "wb") do |file|
      file.puts %Q[#### Properties: acme_cougaar_node - Version: 1.0]
      file.puts %Q[properties: ~]
      file.puts %Q["|": ]
      file.puts %Q[  - props_path: "#{@linux_props}"]
      file.puts %Q[  - jvm_path: "#{@jvm_path}"]
      file.puts %Q[  - node_start_prefix: "su -l -c \\""]
      file.puts %Q[  - node_start_suffix: "\\" asmt"]    
    end
    puts "Writing acme_host_jabber_service properties..."
    path = File.join(destdir, 'plugins', 'acme_host_jabber_service', 'properties.yaml')
    File.open(path, "wb") do |file|
      file.puts %Q[#### Properties: acme_host_jabber_service - Version: 1.0]
      file.puts %Q[properties: ~]
      file.puts %Q["|": ]
      file.puts %Q[  - host: "#{@jabber_host}"]
      file.puts %Q[  - account: "#{@jabber_account}"] if @jabber_account
      file.puts %Q[  - password: "#{@jabber_password}"] if @jabber_password
    end
  end  
  puts "Installing acme_scripting libraries in #{destdir}/redist"
	begin
    Dir.chdir "../acme_scripting/src/"
		Find.find("lib") { |file|
			next if file =~ /CVS|\.svn|\.DS_Store/
      name = file[(SRC.size+1)..-1]
			dst = File.join(destdir, "redist", name)
			if defined? NOOP
        puts "<< #{file}"
				puts ">> #{dst}" #if file =~ /\.rb$/
			else
				File.makedirs( File.dirname(dst) ) # unless File.exist?(File.dirname(dst))
        unless File.directory?(file)
          File.install(file, dst, 0644, true) #if file =~ /\.rb$/
        end
			end
		}
	rescue
		puts $!
	end
  
end

def uninstall destdir
	puts "Uninstalling in #{destdir}"
	begin
		puts "Deleting:"
		dirs = []
		Find.find(File.join(destdir)) do |file| 
			if defined? NOOP
				puts "-- #{file}" if File.file? file
			else
				File.rm_f file,true if File.file? file
			end
			dirs << file if File.directory? file
		end
		dirs.sort { |x,y|
			y.length <=> x.length 	
		}.each { |d| 
			if defined? NOOP
				puts "-- #{d}"
			else
				puts d
				Dir.delete d
			end
		}
	rescue
	end
end

if uninstall
	uninstall destdir
else
	install destdir
end
