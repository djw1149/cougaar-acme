#! /usr/bin/env ruby

require 'ftools'

SRC = 'src'

Dir.chdir ".." if Dir.pwd =~ /bin.?$/

require 'getoptlong'
require 'find'

opts = GetoptLong.new([ '--target', '-t', GetoptLong::REQUIRED_ARGUMENT ],
											[ '--jabber-host', '-j', GetoptLong::REQUIRED_ARGUMENT ],
											[ '--jabber-account', '-a', GetoptLong::REQUIRED_ARGUMENT ],
											[ '--jabber-password', '-p', GetoptLong::REQUIRED_ARGUMENT ],
											[ '--jvm-path', '-v', GetoptLong::REQUIRED_ARGUMENT ],
											[ '--server-props', '-s', GetoptLong::REQUIRED_ARGUMENT ],
                      [ '--cip', '-c', GetoptLong::REQUIRED_ARGUMENT ],
											[ '--cmd-prefix', '-b', GetoptLong::REQUIRED_ARGUMENT ],
											[ '--cmd-suffix', '-e', GetoptLong::REQUIRED_ARGUMENT ],
											[ '--cmd-user', '-w', GetoptLong::REQUIRED_ARGUMENT ],
											[ '--help', '-h', GetoptLong::NO_ARGUMENT],
											[ '--noop', '-n', GetoptLong::NO_ARGUMENT])


@destdir = File.join("", "usr", "local", "acme")

@jabber_host = nil
@jabber_account = nil
@jabber_password = nil
@jvm_path = ''
@server_props = ''
@cmd_prefix =''
@cmd_suffix = ''
@cmd_user = ''
@cip = ''

opts.each do |opt, arg|
	case opt
  when '--jabber-host'
    @jabber_host = arg
  when '--jabber-account'
    @jabber_account = arg
  when '--jabber-password'
    @jabber_password = arg
  when '--jvm-path'
    @jvm_path = arg
  when '--cip'
    @cip = arg
  when '--server-props'
    @server_props = arg
  when '--cmd-prefix'
    @cmd_prefix = arg
  when '--cmd-suffix'
    @cmd_suffix = arg
  when '--cmd-user'
    @cmd_user = arg
  when '--target'
    @destdir = arg
  when '--help'
    puts "Installs the ACME Service.\nUsage:\n\t#$0 -j <jabberhost> [ [-n] [-h] [-t <dir>] [-a <account>] [-p <pwd>]"
    puts "\t\t\t[-v <jvm path>] [-c <cougaar install path>] [-l <server props path>]"
    puts "\t\t\t[-b <command prefix>] [-e <command suffix>] [-w <user>] -u]"
    puts "\t-j --jabber-host\tThe jabber host (required)."
    puts "\t-h --help\tPrint this help file."
    puts "\t-n --noop\t\tDon't actually do anything; just print out what it"
    puts "\t\t\t\twould do."
    puts "\t-t --target\t\tInstalls the software at an absolute location, EG:"
    puts "\t\t\t\t#$0 -t /usr/local/acme"
    puts "\t\t\t\twill put the software directly underneath /usr/local/acme"
    puts "\t-a --jabber-account\tThe jabber account (default <hostname>)."
    puts "\t-p --jabber-password\tThe jabber password (default <hostname>_password)."
    puts "\t-v --jvm-path\t\tThe JVM path to start nodes with."
    puts "\t\t\t\t(default 'java')"
    puts "\t-c --cip\t\tThe Cougaar Install Path"
    puts "\t\t\t\t(default computed from environment)"
    puts "\t-s --server-props\tThe server.props path to start the node with."
    puts "\t\t\t\t(default computed from $COUGAAR_INSTALL_PATH/server/bin/server.props)"
    puts "\t-b --cmd-prefix\tThe prefix to use when starting java."
    puts "\t\t\t\t(default empty string)"
    puts "\t-e --cmd-suffix\tThe suffix to use when starting java."
    puts "\t\t\t\t(default empty string)"
    puts "\t-w --cmd-user\tWho to use (userid) when starting java and computing $COUGAAR_INSTALL_PATH."
    puts "\t\t\t\t(default empty string)"
    puts "\t-u --uninstall\tUninstall ACME."
    exit 0
  when '--noop'
    NOOP = true
	end
end

unless @jabber_host
  puts "Must specify --jabber-host <hostname> to install"
  exit
end

def install
	puts "Installing in #{@destdir}"
	begin
		Find.find(SRC) { |file|
			next if file =~ /CVS|\.svn|\.DS_Store/
      name = file[(SRC.size+1)..-1]
			dst = File.join(@destdir, name)
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
    path = File.join(@destdir, 'plugins', 'acme_cougaar_node', 'properties.yaml')
    File.open(path, "wb") do |file|
      file.puts %Q[#### Properties: acme_cougaar_node - Version: 1.0]
      file.puts %Q[properties: ~]
      file.puts %Q["|": ]
      file.puts %Q[  - server_props: "#{@server_props}"]
    end
    puts "Writing acme_cougaar_xmlnode properties..."
    path = File.join(@destdir, 'plugins', 'acme_cougaar_xmlnode', 'properties.yaml')
    File.open(path, "wb") do |file|
      file.puts %Q[#### Properties: acme_cougaar_xmlnode - Version: 1.0]
      file.puts %Q[properties: ~]
      file.puts %Q["|": ]
      file.puts %Q[  - conference: ~]    
    end
    puts "Writing acme_host_jabber_service properties..."
    path = File.join(@destdir, 'plugins', 'acme_host_jabber_service', 'properties.yaml')
    File.open(path, "wb") do |file|
      file.puts %Q[#### Properties: acme_host_jabber_service - Version: 1.0]
      file.puts %Q[properties: ~]
      file.puts %Q["|": ]
      file.puts %Q[  - host: "#{@jabber_host}"]
      file.puts %Q[  - account: "#{@jabber_account}"] if @jabber_account
      file.puts %Q[  - password: "#{@jabber_password}"] if @jabber_password
    end
    path = File.join(@destdir, 'plugins', 'acme_cougaar_config', 'properties.yaml')
    File.open(path, "wb") do |file|
      file.puts %Q[#### Properties: acme_cougaar_config - Version: 1.0]
      file.puts %Q[properties: ~]
      file.puts %Q["|": ]
      file.puts %Q[  - cougaar_install_path: "#{@cip}"]
      file.puts %Q[  - jvm_path: "#{@jvm_path}"]
      file.puts %Q[  - cmd_prefix: "#{@cmd_prefix}"]
      file.puts %Q[  - cmd_suffix: "#{@cmd_suffix}"]    
      file.puts %Q[  - cmd_user: "#{@cmd_user}"]    
    end
  end
  puts "Installing acme_scripting libraries in #{@destdir}/redist"
	begin
    Dir.chdir "../acme_scripting/src/"
		Find.find("lib") { |file|
			next if file =~ /CVS|\.svn|\.DS_Store/
      name = file[(SRC.size+1)..-1]
			dst = File.join(@destdir, "redist", name)
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

install
