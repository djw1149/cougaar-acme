##
#  <copyright>
#  Copyright 2002 InfoEther, LLC
#  under sponsorship of the Defense Advanced Research Projects Agency (DARPA).
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the Cougaar Open Source License as published by
#  DARPA on the Cougaar Open Source Website (www.cougaar.org).
#
#  THE COUGAAR SOFTWARE AND ANY DERIVATIVE SUPPLIED BY LICENSOR IS
#  PROVIDED 'AS IS' WITHOUT WARRANTIES OF ANY KIND, WHETHER EXPRESS OR
#  IMPLIED, INCLUDING (BUT NOT LIMITED TO) ALL IMPLIED WARRANTIES OF
#  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, AND WITHOUT
#  ANY WARRANTIES AS TO NON-INFRINGEMENT.  IN NO EVENT SHALL COPYRIGHT
#  HOLDER BE LIABLE FOR ANY DIRECT, SPECIAL, INDIRECT OR CONSEQUENTIAL
#  DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE OF DATA OR PROFITS,
#  TORTIOUS CONDUCT, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
#  PERFORMANCE OF THE COUGAAR SOFTWARE.
# </copyright>
#
require 'net/http'

module Cougaar
  module Actions
    class StartDatagrabber < Cougaar::Action
      def initialize(run, host)
        super(run)
        @host = host
      end
      def perform
        ::UltraLog::DataGrabber.new(@host).new_run
      end
    end
    class ConnectToDatagrabber < Cougaar::Action
      def initialize(run, host, &block)
        super(run)
        @host = host
        @action = block if block_given
      end
      def perform
        @action.call(::UltraLog::DataGrabber.new(@host))
      end
    end
  end
end

module UltraLog
  
  ##
  # The DataGrabber class wraps access to a running DataGrabber
  #  Usage:
  #  require 'ultralog/datagrabber'
  #  dg = UltraLog::DataGrabber.new("u049")
  #  run = dg.new_run
  #  run.wait_for_completion
  #
  class DataGrabber
  
    ##
    # Constructs a DataGrabber instance pointed to the host and port
    #
    # host:: [String] The host that is running datagrabber
    # port:: [Integer=7000] The port that datagrabber is running on
    #
    def initialize(host, port=7000)
      @host = host
      @port = port
    end
    
    ##
    # The DataGrabber::Run class holds the status of a dg request
    #
    class Run
      attr_reader :datagrabber, :id, :status, :action
      
      ##
      # Constructs a Run instance
      #
      # datagrabber:: [UltraLog::DataGrabber] The datagrabber instance
      # id:: [String] The id of the run instance
      # status:: [String] The current status
      # action:: [String] The action of the run instance
      #
      def initialize(datagrabber, id, status, action)
        @datagrabber = datagrabber
        @id = id
        @status = status
        @action = action
      end
      
      ##
      # Waits for completion, polling at the requested interval.  This will
      # not return until after the action marks the run as completed, failed
      # or deleted.
      #
      # poll_interval:: [Integer=60] The interval in seconds to poll at
      #
      def wait_for_completion(poll_interval=60)
        completed = false
        until completed
          @datagrabber.get_runs.each do |run|
            if run.id == @id
              @status = run.status
              @action = run.action
              completed = true if run.action.include? "Delete"
              break
            end
          end
          sleep poll_interval unless completed
        end
      end
    end
    
    ##
    # Creates a new run
    #
    # return:: [Cougaar::DataGrabber::Run] The run instance
    #
    def new_run
      c = Net::HTTP.new(@host, @port)
      resp = c.get("/controller/newrun")
      sleep 5
      return get_runs.last
    end
    
    ##
    # Gets a run by ID
    #
    # id:: [String] the run id
    # return:: [Cougaar::DataGrabber::Run] The run instance
    #
    def get_run(id)
      get_runs.each {|run| return run if run.id==id}
    end
    
    ##
    # Gets the runs available within the datagrabber
    #
    # return:: [Array(Cougaar::DataGrabber::Run)] The list of runs
    #
    def get_runs
      c = Net::HTTP.new(@host, @port)
      resp = c.get("/controller/listruns")
      resp = resp[1]
      lines = resp.split("\n")
      offset = 25
      runs = []
      while lines[offset].strip=="<TR>"
        offset = offset + 1
        id = strip_tags(lines[offset].strip).to_i
        status = strip_tags(lines[offset+5].strip)
        action = strip_tags(lines[offset+6].strip)
        runs << Run.new(self, id, status, action)
        offset = offset + 7
      end
      return runs
    end
    
    private
    
    def strip_tags(string)
      count = 0
      while (md = /<([^<]*)>/.match(string))
        string = md.pre_match + md.post_match
      end
      string
    end
    
  end
  
end


if __FILE__ == $0
  dg = UltraLog::DataGrabber.new("u093")
  run = dg.new_run
  puts "Waiting for datagrabber..."
  run.wait_for_completion
  puts "Final status: #{run.status}"
end