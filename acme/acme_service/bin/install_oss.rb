#! /usr/bin/env ruby

=begin
 * <copyright>  
 *  Copyright 2001-2004 InfoEther LLC  
 *  Copyright 2001-2004 BBN Technologies
 *
 *  under sponsorship of the Defense Advanced Research Projects  
 *  Agency (DARPA).  
 *   
 *  You can redistribute this software and/or modify it under the 
 *  terms of the Cougaar Open Source License as published on the 
 *  Cougaar Open Source Website (www.cougaar.org <www.cougaar.org> ).   
 *   
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
 *  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
 *  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR 
 *  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT 
 *  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
 *  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT 
 *  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
 *  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY 
 *  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
 *  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
 *  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 * </copyright>  
=end

require 'ftools'

SRC = 'src'

Dir.chdir ".." if Dir.pwd =~ /bin.?$/

require 'getoptlong'
require 'find'

opts = GetoptLong.new([ '--target', '-t', GetoptLong::REQUIRED_ARGUMENT ],
											[ '--jabber-host', '-j', GetoptLong::REQUIRED_ARGUMENT ],
											[ '--message-router', '-r', GetoptLong::REQUIRED_ARGUMENT ],
											[ '--port', '-o', GetoptLong::REQUIRED_ARGUMENT ],
											[ '--jabber-account', '-a', GetoptLong::REQUIRED_ARGUMENT ],
											[ '--jabber-password', '-p', GetoptLong::REQUIRED_ARGUMENT ],
											[ '--jvm-path', '-v', GetoptLong::REQUIRED_ARGUMENT ],
                      [ '--cip', '-c', GetoptLong::REQUIRED_ARGUMENT ],
											[ '--cmd-prefix', '-b', GetoptLong::REQUIRED_ARGUMENT ],
											[ '--cmd-suffix', '-e', GetoptLong::REQUIRED_ARGUMENT ],
											[ '--cmd-user', '-w', GetoptLong::REQUIRED_ARGUMENT ],
											[ '--help', '-h', GetoptLong::NO_ARGUMENT],
											[ '--noop', '-n', GetoptLong::NO_ARGUMENT])


@destdir = File.join("", "usr", "local", "acme")

@jabber_host = nil
@message_router = "localhost"
@message_router_port = nil
@jabber_account = nil
@jabber_password = nil
@jvm_path = ''
@cmd_prefix =''
@cmd_suffix = ''
@cmd_user = ''
@cip = ''

opts.each do |opt, arg|
	case opt
  when '--jabber-host'
    @jabber_host = arg
  when '--message-router'
    @message_router = arg
  when '--port'
    @message_router_port = arg
  when '--jabber-account'
    @jabber_account = arg
  when '--jabber-password'
    @jabber_password = arg
  when '--jvm-path'
    @jvm_path = arg
  when '--cip'
    @cip = arg
  when '--cmd-prefix'
    @cmd_prefix = arg
  when '--cmd-suffix'
    @cmd_suffix = arg
  when '--cmd-user'
    @cmd_user = arg
  when '--target'
    @destdir = arg
  when '--help'
    puts "Installs the ACME Service."
    puts "Command Options:"
    puts "\t-j --jabber-host\tThe jabber host (instead of message router)."
    puts "\t-r --message-router\tThe message router host (default 'localhost')."
    puts "\t-o --port\t\tThe message router port"
    puts "\t-t --target\t\tInstalls the software at an absolute location, EG:"
    puts "\t\t\t\t#$0 -t /usr/local/acme"
    puts "\t\t\t\twill put the software directly underneath /usr/local/acme"
    puts "\t-a --jabber-account\tThe jabber account (default <hostname>)."
    puts "\t-p --jabber-password\tThe jabber password (default <hostname>_password)."
    puts "\t-v --jvm-path\t\tThe JVM path to start nodes with."
    puts "\t\t\t\t(default 'java')"
    puts "\t-c --cip\t\tThe Cougaar Install Path"
    puts "\t\t\t\t(default computed from environment)"
    puts "\t-b --cmd-prefix\t\tThe prefix to use when starting java."
    puts "\t\t\t\t(default empty string)"
    puts "\t-e --cmd-suffix\t\tThe suffix to use when starting java."
    puts "\t\t\t\t(default empty string)"
    puts "\t-w --cmd-user\t\tWho to use (userid) when starting java and computing $COUGAAR_INSTALL_PATH."
    puts "\t\t\t\t(default empty string)"
    puts "\t-n --noop\t\tDon't actually do anything; just print out what it"
    puts "\t\t\t\twould do."
    puts "\t-h --help\tPrint this help file."
    exit 0
  when '--noop'
    NOOP = true
	end
end

unless @jabber_host || @message_router
  puts "Must specify --jabber-host <hostname> or --message-router <hostname> to install"
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
  Dir.mkdir File.join(@destdir, "bin")
  
  unless defined? NOOP
    puts "Writing acme_cougaar_xmlnode properties..."
    path = File.join(@destdir, 'plugins', 'acme_cougaar_xmlnode', 'properties.yaml')
    File.open(path, "wb") do |file|
      file.puts %Q[#### Properties: acme_cougaar_xmlnode - Version: 1.0]
      file.puts %Q[properties: ~]
      file.puts %Q["|": ]
      file.puts %Q[  - conference: ~]    
    end
    puts "Writing acme_host_communications properties..."
    path = File.join(@destdir, 'plugins', 'acme_host_communications', 'properties.yaml')
    File.open(path, "wb") do |file|
      file.puts %Q[#### Properties: acme_host_communications - Version: 1.0]
      file.puts %Q[properties: ~]
      file.puts %Q["|": ]
      if @jabber_host
        file.puts %Q[  - host: "#{@jabber_host}"]
        file.puts %Q[  - service_type: jabber]
      else
        file.puts %Q[  - host: "#{@message_router}"]
        file.puts %Q[  - start_router_service: true]
        file.puts %Q[  - service_type: router]
        if @message_router_port
          file.puts %Q[  - port: #{@message_router_port}]
        end
      end
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
      file.puts %Q[  - tmp_dir: "configs"]
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
