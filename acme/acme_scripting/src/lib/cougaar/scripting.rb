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

$stdout.sync = true

class Integer
  def seconds(value=0)
    return to_i+value
  end
  alias_method :second, :seconds
  
  def minutes(value=0)
    return to_i*60+value
  end
  alias_method :minute, :minutes
  
  def hours(value=0)
    return to_i*60*60+value
  end
  alias_method :hour, :hours
  
  def days(value=0)
    return to_i*24*60*60+value
  end
  alias_method :day, :days
  
end

module Cougaar

  class SimpleFileLogger
    LEVELS = ['disabled', 'error', 'info', 'debug']
    def initialize(logName, logFile, logLevel)
      @logName = logName
      @logFile = logFile
      self.logLevel = logLevel
      @file = File.new(logFile, "a")
      @file.sync = true
      @mutex = Mutex.new
    end
    
    def logLevel=(logLevel)
      logLevel = LEVELS[logLevel] if logLevel.kind_of? Numeric
      @logLevel = logLevel.downcase
      case @logLevel
      when 'disabled'
        @logLevelInt = 0
      when 'error'
        @logLevelInt = 1
      when 'info'
        @logLevelInt = 2
      when 'debug'
        @logLevelInt = 3
      else
        raise "Unknown Logger level: #{@logLevel}"
      end
    end
    
    def close
      @file.close
    end
    
    def time
      Time.now.gmtime.to_s
    end
    
    def error(message)
      return if @logLevelInt < 1
      write "[ERROR] #{time} :: #{message}"
    end
    
    def info(message)
      return if @logLevelInt < 2
      write "[INFO] #{time} :: #{message}"
    end
    
    def debug(message)
      return if @logLevelInt < 3
      write "[DEBUG] #{time} :: #{message}"
    end
    
    def write(line)
      @mutex.synchronize do
        @file.puts line
      end
    end

  end
  
  class Documentation
    attr_accessor :description, :example
    def initialize(&block)
      instance_eval(&block)
      cleanup
    end
    def cleanup
      if @description
        list = @description.split("\n")
        newlist = []
        list.each { |v| newlist << v.strip }
        @description = newlist.join(" ")
      end
      if @example
        list = @example.split("\n")
        if list.size > 1 && list[0].strip==""
          count = 0
          list[1].each_byte do |byte| 
            count+=1 if byte==32
            break if byte != 32
          end
          newlist = []
          list[1..-1].each { |v| newlist << v[count..-1] }
          @example = newlist.join("\n")
        end
      end
    end
    
    def has_parameters?
      if @parameters
        return true
      else
        return false
      end
    end
    
    def has_block_yields?
      if @block_yields
        return true
      else
        return false
      end
    end
    
    def parameter_names
      result = []
      if @parameters
        @parameters.each do |item|
          result << item.keys[0]
        end
      end
      return result
    end
    
    def block_yield_names
      result = []
      if @block_yields
        @block_yields.each do |item|
          result << item.keys[0]
        end
      end
      return result
    end
    
    def each_block_yield
      if @block_yields
        @block_yields.each do |item|
          key = item.keys[0]
          yield key, item[key]
        end
      end
    end
    
    def each_parameter
      if @parameters
        @parameters.each do |item|
          key = item.keys[0]
          yield key, item[key]
        end
      end
    end
    
  end
  
  def self.document(&block)
    Cougaar::Documentation.new(&block)
  end
  
  def self.logger
    unless @logger
      File.delete('run.log') if File.exist?('run.log')
      @logger = SimpleFileLogger.new("ACME Run", "run.log", "info")
    end
    @logger
  end

  def self.debug?
    return self.constants.include?("DEBUG") && DEBUG
  end

end

require 'cougaar/society_model'
require 'cougaar/experiment'
require 'cougaar/society_utils'
require 'cougaar/society_builder'
require 'cougaar/communications'
require 'cougaar/communities'
require 'cougaar/society_control'
require 'cougaar/society_rule_engine'
require 'cougaar/metrics'
require 'cougaar/persistence'
require 'cougaar/run_logging'