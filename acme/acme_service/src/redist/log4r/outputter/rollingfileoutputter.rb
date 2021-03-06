
# :nodoc:
# Version:: $Id: rollingfileoutputter.rb,v 1.1 2003-02-19 03:17:09 rich Exp $

require "log4r/outputter/fileoutputter"
require "log4r/staticlogger"

module Log4r

  # RollingFileOutputter - subclass of FileOutputter that rolls files on size
  # or time. Additional hash arguments are:
  #
  # [<tt>:maxsize</tt>]   Maximum size of the file in bytes.
  # [<tt>:trunc</tt>]	  Maximum age of the file in seconds.
  class RollingFileOutputter < FileOutputter

    attr_reader :count, :maxsize, :maxtime, :startTime#,i:baseFilename

    def initialize(_name, hash={})
      @count = 0
      super(_name, hash)
      if hash.has_key?(:maxsize) || hash.has_key?('maxsize') 
        _maxsize = (hash[:maxsize] or hash['maxsize']).to_i
        if _maxsize.type != Fixnum
          raise TypeError, "Argument 'maxsize' must be an Fixnum", caller
        end
        if _maxsize == 0
          raise TypeError, "Argument 'maxsize' must be > 0", caller
        end
        @maxsize = _maxsize
      end
      if hash.has_key?(:maxtime) || hash.has_key?('maxtime') 
        _maxtime = (hash[:maxtime] or hash['maxtime']).to_i
        if _maxtime.type != Fixnum
          raise TypeError, "Argument 'maxtime' must be an Fixnum", caller
        end
        if _maxtime == 0
          raise TypeError, "Argument 'maxtime' must be > 0", caller
        end
        @maxtime = _maxtime
        @startTime = Time.now
      end
      @baseFilename = File.basename(@filename)
      # roll immediately so all files are of the form "000001-@baseFilename"
      roll
      # initialize the file size counter
      @datasize = 0
    end

    #######
    private
    #######

    # perform the write
    def write(data) 
      # we have to keep track of the file size ourselves - File.size doesn't
      # seem to report the correct size when the size changes rapidly
      @datasize += data.size + 1 # the 1 is for newline
      super
      flush
      roll if requiresRoll
    end

    # construct a new filename from the count and baseFilname
    def makeNewFilename
      fileDir = File.dirname(@filename)
      # note use of hard coded 6 digit counter width - is this enough files?
      pad = "0" * (6 - @count.to_s.length)
      @filename = fileDir + "/" + "#{pad}#{@count}-#{@baseFilename}"
    end 

    # does the file require a roll?
    def requiresRoll
      if !@maxsize.nil? && @datasize > @maxsize
        #puts "Rolling on size***********************[#{@datasize}] @maxsize [#{@maxsize}]"
        @datasize = 0
        return true
      end
      if !@maxtime.nil? && (Time.now - @startTime) > @maxtime
        #puts "Rolling on time***********************[#{Time.now - @startTime}] @maxtime [#{@maxtime}]"
        @startTime = Time.now
        return true
      end
      false
    end 

    # roll the file
    def roll
      begin
        @out.close
      rescue 
        Logger.log_internal {
          "RollingFileOutputter could not close #{@filename}"
        }
      end
      @count += 1
      makeNewFilename
      @out = File.new(@filename, (@trunc ? "w" : "a"))
    end 

  end

end

# this can be found in examples/fileroll.rb as well
if __FILE__ == $0
  require 'log4r'
  include Log4r


  timeLog = Logger.new 'WbExplorer'
  timeLog.outputters = RollingFileOutputter.new("WbExplorer", { "filename" => "TestTime.log", "maxtime" => 10, "trunc" => true })
  timeLog.level = DEBUG

  100.times { |t|
    timeLog.info "blah #{t}"
    sleep(1.0)
  }

  sizeLog = Logger.new 'WbExplorer'
  sizeLog.outputters = RollingFileOutputter.new("WbExplorer", { "filename" => "TestSize.log", "maxsize" => 16000, "trunc" => true })
  sizeLog.level = DEBUG

  100000.times { |t|
    sizeLog.info "blah #{t}"
  }

end
