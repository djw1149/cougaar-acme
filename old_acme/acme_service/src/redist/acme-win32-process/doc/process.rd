=begin
= Description
	win32-process - fork, wait and kill for Win32.
= Synopsis
   require "win32/process"
   	
   # Using fork/wait
   pid = Process.fork
   	
   # Standard version
   if pid.nil?
   	3.times{
   		puts "In child 1"
   		sleep 1
   	}
   	exit
   end
   	
   # Block version
   fork do
   	3.times{
   		puts "In child 2"
   		sleep 1
   	}
   end
   	
   # Meanwhile, back in the parent...
   2.times{
   	puts "In the parent"
   	sleep 1
  	}
   Process.wait   # Wait for children
   puts "Continuing..."
   	
	# Using kill
   begin
     	Process.kill(0,1234) # Is 1234 running?
   rescue
     	puts "Process is NOT running"
   else
     	puts "Process is running"
   end

   begin
      Process.kill(9,1234) # -> hard kill
   rescue
      puts "Process does not exist.  Ignoring"
   end
   	
   # Using create
   Process.create(
   	:app_name => "notepad.exe",
   	:creation_flags => Process::DETACHED_PROCESS
   )

= Class Methods
--- Process.create({args})
	This is a wrapper to the CreateProcess() function.  It executes a process,
	returning the PID of that process.  It accepts a hash as an argument.
	There are four primary keys:
	
	* app_name
	* inherit?        (default: true)
	* creation_flags  (default: 0)
	* cwd             (default: Dir.pwd)
	
	Of these, the ((|app_name|)) must be specified or an error is raised.
	
	The remaining keys are attributes that are part of the StartupInfo struct,
	and are generally only meaningful for GUI or console processes.  See the
	documentation on CreateProcess() and the StartupInfo struct on MSDN for
	more information.
		
	* desktop
	* title
	* x
	* y
	* x_size
	* y_size
	* x_count_chars
	* y_count_chars
	* fill_attribute
	* sw_flags
	* startf_flags
	
	The relevant constants for ((|creation_flags|)), ((|sw_flags|)) and
	((|startf_flags|)) are listed below.  For details on what each of them mean,
	please see the documentation on the MSDN site (there are simply too many
	to document here).	
--- Process.fork({block})
	Creates the equivalent of a subshell via the CreateProcess() function.
	This behaves in a manner that is similar, but not identical to, the
	Kernel.fork method for Unix.
--- Process.kill(signal, pid1, pid2, ...)
	Sends the specified signal to a pid or list of pids.  See "Supported
	Signals" below for a list of valid signals.  Returns an array of pid's
	that were successfully killed.
--- Process.wait
	Waits for any child process to exit and returns the process id of that
	child.
--- Process.wait2
	Waits for any child process to exit and returns an array containing the
	process id and the exit status of that child.
--- Process.waitpid(pid,signal=0)
	Waits for the given child process to exit and returns that pid.  For now,
	((*signal*)) is always 0.
--- Process.waitpid2(pid,signal=0)
	Waits for the given child process to exit and returns an array containing
	the process id and the exit status.  For now, ((*signal*)) is always 0.
= Supported Signals (for the kill method)
	0: Returns the PID if it exists, but does not actually kill the process.

	1: Sends a Ctrl-C to the process.  Note that this is designed only to kill
	   terminal processes.  It won't kill a GUI process.

	2: Sends a Ctrl-Break to the process.  This will not affect GUI processes.

	3-8: The standard way to kill a Win32 Process.  See the notes below for more
	   details.

	9: The most deadly but least clean method of killing a Win32 process.
= Constants
== Standard
--- VERSION
	The current version number of the package returned as a string.
== Creation Flags
--- CREATE_BREAKAWAY_FROM_JOB
--- CREATE_DEFAULT_ERROR_MODE
--- CREATE_NEW_CONSOLE
--- CREATE_NEW_PROCESS_GROUP
--- CREATE_NO_WINDOW
--- CREATE_PRESERVE_CODE_AUTHZ_LEVEL
--- CREATE_SEPARATE_WOW_VDM
--- CREATE_SHARED_WOW_VDM
--- CREATE_SUSPENDED
--- CREATE_UNICODE_ENVIRONMENT
--- DEBUG_ONLY_THIS_PROCESS
--- DEBUG_PROCESS
--- DETACHED_PROCESS
--- ABOVE_NORMAL
--- BELOW_NORMAL
--- HIGH
--- IDLE
--- NORMAL
--- REALTIME
== Startf Flags
--- FORCEONFEEDBACK
--- FORCEOFFFEEDBACK
--- RUNFULLSCREEN
--- USECOUNTCHARS
--- USEFILLATTRIBUTE
--- USEPOSITION
--- USESHOWWINDOW
--- USESIZE
--- USESTDHANDLES
== Fill Attribute Flags
--- FOREGROUND_BLUE
--- FOREGROUND_GREEN
--- FOREGROUND_RED
--- FOREGROUND_INTENSITY
--- BACKGROUND_BLUE
--- BACKGROUND_GREEN
--- BACKGROUND_RED
--- BACKGROUND_INTENSITY
== ShowWindow Flags
--- SW_HIDE
--- SW_SHOWNORMAL
--- SW_NORMAL
--- SW_SHOWMINIMIZED
--- SW_SHOWMAXIMIZED
--- SW_MAXIMIZE
--- SW_SHOWNOACTIVATE
--- SW_SHOW
--- SW_MINIMIZE
--- SW_SHOWMINNOACTIVE
--- SW_SHOWNA
--- SW_RESTORE
--- SW_SHOWDEFAULT
--- SW_FORCEMINIMIZE
--- SW_MAX
= Exception Classes
== Win32::ProcessError < RuntimeError
	Raised if the fork or wait methods fail.  The kill method does not use
	this class, but calls rb_sys_fail instead (because that's what Ruby does).
= Details
== The fork and wait methods
	The fork() method is emulated on Win32 by spawning a another Ruby process
	against $0 via the CreateProcess() Win32 API function.  It will use its
	parent's environment and starting directory.
	
	The various wait methods are a wrapper for the WaitForSingleObject() or
	WaitForMultipleObjects() Win32 API functions, for the wait* and waitpid*
	methods, respectively.  In the case of wait2 and waitpid2, the exit value
	is returned via the GetExitCodeProcess() Win32API function.
	
	For now the waitpid and waitpid2 calls do not accept a second argument.
	That's because we haven't yet determined if there's a signal we should
	allow to be sent.  It may be removed in a future version, so don't rely
	on it.
	
	Note that because it is calling CreateProcess($0), it will start again from
	the top of the script instead of from the point of the call.
	
	There is also a quirk with regards to processes created via fork() and
	kill() relating to the fact that technically, the fork() method returns a
	process handle, not a PID.  See bug #712 on the project page for more
	details.
== The kill() method	
	Initially, the kill() method will try to get a HANDLE on the PID using the
	OpenProcess() method.  If that succeeds, we know the process is running.

	In the event of signal 1 or signal 2, the GenerateConsoleCtrlEvent()
	method is used to send a signal to that process.  These will not kill
	GUI processes.

	In the event of signal 3-8, the CreateRemoteThread() method is used
	after the HANDLE's process has been identified to create a thread
	within that process.  The ExitProcess() method is then sent to that
	thread.

	In the event of signal 9, the TerminateProcess() method is called.  This
	will almost certainly kill the process, but doesn't give the process a
	chance to necessarily do any cleanup it might otherwise do.
== Differences between Ruby's kill() and the Win32 Utils kill()
	Ruby does not currently use the CreateRemoteThread() + ExitProcess()
	approach which is, according to everything I've read, a cleaner approach.
	
	Also, the way kill() handles multiple pids works slightly differently (and
	better IMHO) in the Win32 Utils version than the way Ruby currently
	provides.
= Notes
	It is unlikely you will be able to kill system processes with this module.
	It's probably better that you don't.
= Known Bugs
	The test suite may segfault.  This appears to be caused by the
	rb_sys_fail() function, though I have not narrowed down why it occurs.  It
	only seems to happen with the Windows Installer version of Ruby.  It does
	not occur when I build Ruby from scratch myself.
	
	None known (though please see the Notes section for quirks).  Any bugs
	should be reported on the project page at
	http://rubyforge.org/projects/win32utils.
= Future Plans
	I'm attempting to add a pure Ruby version that uses OLE + WMI.  You can
	find what I have so far in CVS.  Look for the 'process.rb' file.
	
	Other suggestions welcome.
= License
	Ruby's
= Copyright
	(C) 2003,2004 Daniel J. Berger
	All Rights Reserved	
= Warranty
	This package is provided "as is" and without any express or
	implied warranties, including, without limitation, the implied
	warranties of merchantability and fitness for a particular purpose.
= Author(s)
	Park Heesob
   phasis at nownuri dot net
   phasis68 on IRC (freenode)
    
   Shashank Date
   sdate at everestkc dot net
   sdate on IRC (freenode)
	
	Daniel J. Berger
	djberg96@yahoo.com
	rubyhacker1/imperator (freenode)
=end