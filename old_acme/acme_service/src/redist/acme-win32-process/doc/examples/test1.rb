##########################################################################
# test2.rb
#
# Generic test script for futzing around with the traditional form of
# fork/wait, plus waitpid and waitpid2.
##########################################################################
if File.basename(Dir.pwd) == "examples"
	require "ftools"
   	Dir.chdir("../..")
	Dir.mkdir("win32") unless File.exists?("win32")
	File.copy("process.so","win32")
	$:.unshift Dir.pwd
	Dir.chdir("doc/examples")
end

require 'win32/process'

puts "VERSION: " + Process::VERSION

pid = Process.fork

#child
if pid.nil?
   7.times{ |i|
      puts "Child: #{i}"
      sleep 1
   }
   exit(-1)
end

pid2 = Process.fork

#child2
if pid2.nil?
   7.times{ |i|
      puts "Child2: #{i}"
      sleep 1
   }
   exit(1)
end

#parent
2.times { |i|
   puts "Parent: #{i}"
   sleep 1
}
p Process.waitpid2(pid)
p Process.waitpid2(pid2)

puts "Continuing on..."

