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

require 'thread'

class MonitoredProcess
  attr_reader :pid

  def MonitoredProcess.guessPlatform()
    platform = "windows"
    if File::PATH_SEPARATOR == ":"
      platform = "unix"
    end
    puts "PLATFORM IS #{platform}"
    return platform
  end

  @@platform = MonitoredProcess.guessPlatform()

  def initialize(cmd)
    @cmd = cmd
    @listeners = []
    @stdoutstr = ""
    @stderrstr = ""
    @procactive = true
    Thread.new do
      begin
        listenerThread() 
      rescue
        puts $!
        puts $!.backtrace.join("\n")
      end
    end
  end

  def addStdioListener(listener)
    @listeners << listener
  end

  def removeStdioListener(listener)
    @listeners.delete(listener)
  end
  
  def start(&block)
    if @@platform == "unix"
      unix_start()
    else
      windows_start()
    end
  end

  def unix_start
    pw = IO::pipe   # pipe[0] for read, pipe[1] for write
    pr = IO::pipe
    pe = IO::pipe

      # child
      pid = fork{
        pw[1].close
        STDIN.reopen(pw[0])
        pw[0].close

        pr[0].close
        STDOUT.reopen(pr[1])
        pr[1].close

        pe[0].close
        STDERR.reopen(pe[1])
        pe[1].close

        exec(@cmd)
      }

    pw[0].close
    pr[1].close
    pe[1].close
    pi = [pw[1], pr[0], pe[0], pid]
    pw[1].sync = true
    @stdin = pi[0]
    @stdout = pi[1]
    @stderr = pi[2]
    @pid = pi[3]
    puts "root pid = #{@pid}"
    Thread.new(@stdout) do |stdout|
      begin
        while true
          s = @stdout.getc
          break if s == nil
          @stdoutstr << s
        end
        #puts "stdout exit"
        @outactive = false
      rescue
        puts $!
        puts $!.backtrace.join("\n")
      end
    end

    Thread.new(@stderr) do |stderr|
      begin
        @erractive = true
        while true
          s = @stderr.getc
          break if s == nil
          @stderrstr << s
        end
        #puts "stderr exit"
        @erractive = false
      rescue
        puts $!
        puts $!.backtrace.join("\n")
      end
    end
    Thread.new(@pid) do |pid|
      @procactive = true
      retries = 0
      begin
        puts "Starting wait for PID #{@pid}"
        Process.waitpid(pid)
        #block.call if block # optional death check block
        puts "#{@pid} is DEAD"
      rescue
        puts "Exception waiting for PID: #{$!}"
        retries = retries + 1
        retry if (retries < 5)
      end
      @procactive = false
    end
    pi
  end

  def windows_start()
    require "win32/process"
    @pipe = Process.create_piped("app_name" => @cmd)
    @procactive = true
    @pid = @pipe.to_s
    @erractive = true
    @outactive = true
    Thread.new(@pipe) do |pipe|
      begin
        while Process.is_active(@pipe)
          s = Process.get_stdout(@pipe)
          @stdoutstr << s if (s.length() > 0) 
          s = Process.get_stderr(@pipe)
          @stderrstr << s if (s.length() > 0)
          sleep (1)
        end
        @outactive = false
        @erractive = false
      rescue
        puts $!
        puts $!.backtrace.join("\n")
      end
    end
	  return @pid
  end


  def alive() 
    ret = @procactive || @erractive || @outactive || (@stdoutstr.length > 0) || (@stderrstr.length > 0)
    if (@@platform == "windows")
      require "win32/process"
      ret = ret & Process.is_active(@pipe) if @pipe
    end
    return ret
  end

  def signal(sig)
    if (@@platform == "unix")
      real_pid = find_java(@pid)
      puts "Kill(#{sig}, #{real_pid})"
      Process.kill(sig, real_pid)
    else
      @stderrstr << "Unable to signal process on this platform"
    end
  end

  def find_java(pid)
    ret = find_child_process_id('java', get_process(pid))
    ret = pid unless ret
    return ret
  end
          
  def get_processes
    structure = `ps -alxc`
    lines = []
    structure.each_line {|line| lines << line}
    lines = lines.collect { |line| line.split}
    entries = lines[1..-1].collect do |line| 
      map = { :children => [] }
      line.each_with_index {|item, i| map[lines[0][i]]=item}
      map
    end
    entries.each {|entry| entry['PID'] = entry['PID'].to_i;entry['PPID'] = entry['PPID'].to_i}
    structure = {0=>{'PID'=>0, :children=>[]}}
    entries.each {|entry| structure[entry['PID']] = entry}
    structure.each do  |pid, entry| 
      next if pid == 0
      structure[entry['PPID']][:children] << entry
    end
    structure.each {|pid, entry| entry[:children].sort! {|a, b| a['PID'].to_i<=>b['PID'].to_i}}
    structure
  end

  def get_process(pid=Process.pid)
    get_processes[pid]
  end

  def find_child_process_id(name, process = nil)
    process = get_process unless process
    return process['PID'] if process['COMMAND'] == name
    process[:children].each {|child| return find_child_process_id(name, child)}
    return nil
  end

  def listenerThread()

    while alive do
      begin
        if (@stdoutstr.length > 0)
          #puts "STDOUT: #{@stdoutstr}"
          stdout = @stdoutstr
          @stdoutstr = ""
          @listeners.each do |listener|
            listener.stdoutCB(stdout)
          end
        end
        if (@stderrstr.length > 0)
          #puts "STDERR: #{@stderrstr}"
          stderr = @stderrstr
          @stderrstr = ""
          @listeners.each do |listener|
            listener.stderrCB(stderr)
          end
        end
   
        sleep 5
      rescue
        puts "exception #{$!}"
        puts $!.backtrace.join("\n")
      end
    end
    puts "EXIT: \n";
    if (@@platform == "windows")
      Process.free(@pipe)
    end
    @listeners.each do |listener|
      listener.exitCB()
    end
    @listeners = nil

  end
  
  def kill
    if (@@platform == "unix")
      signal(9)
    else
      Process.free(@pipe)
      @procactive = false
    end
  end

end

if $0 == __FILE__ 
  class TestListener 
    def stdoutCB(s)
      puts "OUT: #{s}"
    end
    def stderrCB(s)
      puts "ERR: #{s}"
    end
    def exitCB()
      puts "Exited"
    end
  end

=begin
  x = MonitoredProcess.new("bc")
  tl = TestListener.new()
  x.addStdioListener(tl)
  x.start

  sleep 10
  puts "proc is alive: #{x.alive}"

  x.kill

  puts "killt"
  puts "proc is alive: #{x.alive}"
  sleep 2
  puts "proc is alive: #{x.alive}"
=end

  x = MonitoredProcess.new("ls -l foo .")
  tl = TestListener.new()
  x.addStdioListener(tl)
  x.start

  sleep 30

end

