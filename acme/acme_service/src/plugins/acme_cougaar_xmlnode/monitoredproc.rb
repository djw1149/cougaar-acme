=begin
/* 
 * <copyright>
 *  Copyright 2002-2003 BBNT Solutions, LLC
 *  under sponsorship of the Defense Advanced Research Projects Agency (DARPA).
 * 
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the Cougaar Open Source License as published by
 *  DARPA on the Cougaar Open Source Website (www.cougaar.org).
 * 
 *  THE COUGAAR SOFTWARE AND ANY DERIVATIVE SUPPLIED BY LICENSOR IS
 *  PROVIDED 'AS IS' WITHOUT WARRANTIES OF ANY KIND, WHETHER EXPRESS OR
 *  IMPLIED, INCLUDING (BUT NOT LIMITED TO) ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, AND WITHOUT
 *  ANY WARRANTIES AS TO NON-INFRINGEMENT.  IN NO EVENT SHALL COPYRIGHT
 *  HOLDER BE LIABLE FOR ANY DIRECT, SPECIAL, INDIRECT OR CONSEQUENTIAL
 *  DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE OF DATA OR PROFITS,
 *  TORTIOUS CONDUCT, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 *  PERFORMANCE OF THE COUGAAR SOFTWARE.
 * </copyright>
 */
=end

require 'thread'


class MonitoredProcess
  attr_reader :pid

  def MonitoredProcess.guessPlatform()
    begin
      pid = fork {exit!}
      Process.waitpid(pid)
   
      platform = "unix"
    rescue NotImplementedError
      platform = "windows"
    end
    return platform
  end

  @@platform = MonitoredProcess.guessPlatform()

  def initialize(cmd)
    puts "PLATFORM IS #{@@platform}"
    @cmd = cmd
    @listeners = []
    @stdoutstr = ""
    @stderrstr = ""
    @procactive = true
    Thread.new do 
      listenerThread() 
    end
  end

  def addStdioListener(listener)
    @listeners << listener
  end

  def removeStdioListener(listener)
    @listeners.delete(listener)
  end
  
  def start()
    if @@platform == "unix"
      unix_start()
    else
      windows_start()
    end
  end

  def unix_start()
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
    #puts "pid = #{@pid}"
    Thread.new(@stdout) do |stdout|
      while true
        s = @stdout.getc
        break if s == nil
        @stdoutstr << s
      end
      #puts "stdout exit"
      @outactive = false
    end

    Thread.new(@stderr) do |stderr|
      @erractive = true
      while true
        s = @stderr.getc
        break if s == nil
        @stderrstr << s
      end
      #puts "stderr exit"
      @erractive = false
    end
    Thread.new(@pid) do |pid|
      @procactive = true
      Process.waitpid(pid)
      puts "#{@pid} is DEAD"
      @procactive = false
    end
    pi
  end

  @@last_pid = 0
  def windows_start()
    @pipe = IO.popen(@cmd)
    @procactive = true
    @pid = @pipe.pid.to_s
    if @pid == ''
      @@last_pid = @@last_pid + 1
      @pid = @@last_pid.to_s
    end
	  return @pid
  end


  def alive() 
    #puts "ALIVE: #{@procactive} || #{@erractive} || #{@outactive} || #{(@stdoutstr.length > 0)} || #{(@stderrstr.length > 0)}"
    return @procactive || @erractive || @outactive || (@stdoutstr.length > 0) || (@stderrstr.length > 0)
  end

  def signal(sig)
    if (@@platform == "unix")
      real_pid = find_java(@pid)
      #puts "Kill(#{sig}, #{real_pid})"
      Process.kill(sig, real_pid.to_i)
    else
      @stderrstr << "Unable to signal process on this platform"
    end
  end

  # Unabashedly linux-specific
  def find_java(parent)
    ret = parent
    ps = `pstree -pl`

    if ps =~ /java\(#{parent}\)/
      ret = parent
    elsif ps =~ /\(#{parent}\)[^j]*java\((\d+)\)/
      ret =  $1
    end
    return ret
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
   
        sleep 15
      rescue
        puts "exception #{$!}"
        puts $!.backtrace.join("\n")
      end
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
      @pipe.close()
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

  sleep 200

end
