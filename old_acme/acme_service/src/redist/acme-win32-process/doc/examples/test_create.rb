##########################################################################
# test_create.rb
#
# Simple test program for the Process.create() method.
##########################################################################
if File.basename(Dir.pwd) == "examples"
	require "ftools"
   	Dir.chdir("../..")
	Dir.mkdir("win32") unless File.exists?("win32")
	File.copy("process.so","win32")
	$LOAD_PATH.unshift Dir.pwd
	Dir.chdir("doc/examples")
end

require "win32/process"

p Process::VERSION

Process.create(
   "app_name" => "notepad.exe",
   "creation_flags"    => Process::DETACHED_PROCESS
)

=begin
# Don't run this from an existing terminal
pid = Process.create(
   :app_name       => "cmd.exe",
   :creation_flags => Process::DETACHED_PROCESS,
   :startf_flags   => Process::USEPOSITION,
   :x              => 0,
   :y              => 0,
   :title          => "Hi Dan"
)

puts "Pid of new process: #{pid}"
=end
