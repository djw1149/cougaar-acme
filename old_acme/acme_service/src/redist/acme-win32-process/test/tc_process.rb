###############################################################################
# tc_process.rb
#
# Test suite for the win32-process package.  This test suite will start
# at least two instances of Internet Explorer on your system, which will then
# be killed. Requires the win32ole package as well as the sys-proctable
# package.
#
# I haven't added a lot of test cases for fork/wait because it's difficult
# to run such tests without causing havoic with TestUnit itself.  Ideas
# welcome.
###############################################################################
if File.basename(Dir.pwd) == "test"
	require "ftools"
   	Dir.chdir("..")
	Dir.mkdir("win32") unless File.exists?("win32")
	File.copy("process.so","win32")
	$LOAD_PATH.unshift Dir.pwd
	Dir.chdir("test")
end

require "test/unit"
require "win32ole"
require "win32/process"

begin
   require "sys/proctable"
rescue LoadError => e
   STDERR.puts "Stopping!"
   STDERR.puts "The sys/proctable module is required to run this test suite"
   STDERR.puts "You can find it at http://ruby-sysutils.sf.net or the RAA"
   exit!
end   

include Sys

class TC_Win32Process < Test::Unit::TestCase
   @@ie1 		= nil # Used to store an IE instance
   @@ie2		= nil # Ditto
   @@ie_pids 	= []  # A list of all IE pids
  
   def setup
      ProcTable.ps{ |s|
         next unless s.comm =~ /iexplore\.exe/i
         @@ie_pids.push(s.pid)
      }
      
      # Only create one instance each
      unless @@ie1
         @@ie1 = WIN32OLE.new("InternetExplorer.Application")
         @@ie1.visible = true
         @@ie1.gohome
      end
      	
      unless @@ie2
         @@ie2 = WIN32OLE.new("InternetExplorer.Application")
         @@ie2.visible = true
         @@ie2.gohome
      end
      
      ProcTable.ps{ |s|
         next unless s.comm =~ /iexplore\.exe/i
         next if @@ie_pids.include?(s.pid)
         @@ie_pids.push(s.pid)
      }
      
      @pid = @@ie_pids.last
   end
  
   def test_version
      assert_equal("0.3.0",Process::VERSION)
   end
   
   def test_kill_bad_arguments
      assert_raises(ArgumentError){ Process.kill }
      assert_raises(ArgumentError){ Process.kill("bogus") }
      assert_raises(TypeError){ Process.kill("bogus",9999999) }
   end

   # This causes a segfault with the Windows installer version
   def test_process_does_not_exist
      assert_raises(Errno::ENOENT){ Process.kill(0,9999999) }
   end
   
   # The kill(0) must happen before the kill(3)
   def test_01_kill_0
      assert_nothing_raised{ Process.kill(0,@pid) }
   end
   
   def test_02_kill_standard
      assert_nothing_raised{ Process.kill(3,@pid) }
   end
   
   # Wont' actually do anything to a GUI
   #def test_05_kill_1
   #   assert_nothing_raised{ Process.kill(1,@pid) }
   #end
   
   # Wont' actually do anything to a GUI
   #def test_05_kill_2
   #   assert_nothing_raised{ Process.kill(2,@pid) }
   #end
 
   def test_kill_9
      pid = @@ie_pids.last
      msg = "Could not find pid #{pid}"
      assert_nothing_raised(msg){ Process.kill(9,pid) }
   end
  	
   def test_create
   	  assert_respond_to(Process,:create)
   end
   	
   def test_creation_constants
   	  assert_not_nil(Process::CREATE_DEFAULT_ERROR_MODE)
   	  assert_not_nil(Process::CREATE_NEW_CONSOLE)
   	  assert_not_nil(Process::CREATE_NEW_PROCESS_GROUP)
   	  assert_not_nil(Process::CREATE_NO_WINDOW)
   	  assert_not_nil(Process::CREATE_SEPARATE_WOW_VDM)
   	  assert_not_nil(Process::CREATE_SHARED_WOW_VDM)
   	  assert_not_nil(Process::CREATE_SUSPENDED)
   	  assert_not_nil(Process::CREATE_UNICODE_ENVIRONMENT)
   	  assert_not_nil(Process::DEBUG_ONLY_THIS_PROCESS)
   	  assert_not_nil(Process::DEBUG_PROCESS)
   	  assert_not_nil(Process::DETACHED_PROCESS)
   end
   
   def test_fork
      assert_respond_to(Process,:fork)
   end
   
end
