##########################################################################
# test2.rb
#
# Generic test script for futzing around with the block form of fork/wait
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

# In the child, using block form
fork{
  	7.times { |i|
     	puts "Child: #{i}"
     	sleep 1
  	}
}

# Back in the parent
4.times{ |i|
   	puts "Parent: #{i}"
   	sleep 1
}

Process.wait

puts "Continuing on..."
