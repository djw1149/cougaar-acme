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
require 'xmlrpc/client'

module Cougaar
  module States
    class OperatorServiceConnected < Cougaar::NOOPState
    end
  end
  
  module Actions
    class ConnectOperatorService < Cougaar::Action
      RESULTANT_STATE = 'OperatorServiceConnected'
      def initialize(run, host)
        super(run)
        @host = run.society.hosts[host]
      end
      def perform
        operator = ::UltraLog::Operator.from_run(@run, @host)
        result = operator.test
        if result =~ /ERROR SENDING/ || result =~ /Unregistered command/
          puts "Invalid Operator Service #{@host.host_name}\n#{result}"
        else
          @run['operator'] = operator
        end
      end
    end
    
    class ResetCrypto < Cougaar::Action
      PRIOR_STATES = ['OperatorServiceConnected']
      def perform
        operator = @run['operator']
        operator.reset_crypto
      end
    end
    
    class ClearPersistence < Cougaar::Action
      PRIOR_STATES = ['OperatorServiceConnected']
      def perform
        operator = @run['operator']
        operator.clear_persistence
      end
    end
    
    class ClearLogs < Cougaar::Action
      PRIOR_STATES = ['OperatorServiceConnected']
      def perform
        operator = @run['operator']
        operator.clear_logs
      end
    end
    
    class ClearPersistenceAndLogs < Cougaar::Action
      PRIOR_STATES = ['OperatorServiceConnected']
      def perform
        operator = @run['operator']
        operator.clear_pnlogs
      end
    end
    
    class ArchiveLogs < Cougaar::Action
      PRIOR_STATES = ['OperatorServiceConnected']
      def perform
        operator = @run['operator']
        operator.archive_logs
      end
    end
    
    class ArchiveDatabases < Cougaar::Action
      PRIOR_STATES = ['OperatorServiceConnected']
      def perform
        operator = @run['operator']
        operator.archive_db
      end
    end
  end
end

module UltraLog

  class Operator
    TIMEOUT = (60*30) #60 seconds * number of minutes
    
    attr_accessor :run
  
    def initialize(host)
      @host = host
      @baseName = Time.now.strftime('%y-%m-%d_%H')
    end
    
    def self.from_run(run, host)
      op = Operator.new(host)
      op.run = run
      op
    end
  
    def test
      send_command('test_cip', 10)
    end
    
    def reset_crypto
      send_command('reset_crypto', 20)
    end
    
    def clear_logs
      send_command('clear_logs', 10)
    end
    
    def clear_pnlogs
      send_command('clear_pnlogs', 30)
    end
    
    def clear_persistence
      send_command('clear_persistence', 20)
    end
    
    def archive_logs(runName=nil)
      send_command('archive_logs', 2.minutes, composite_name(runName))
    end
    
    def archive_db(runName=nil)
      send_command('archive_db', 8.minutes, composite_name(runName))
    end
    
    private
    
    def send_command(command, timeout, params="")
      reply = @run.comms.new_message(@host).set_body("command[#{command}]#{params}").request(timeout)
      return "ERROR SENDING: command[#{command}]#{params}" if reply.nil?
      return reply.body
    end
    
    def composite_name(runName=nil)
      runName = @run.name if @run && runName==nil
      runName = "Unspecified" unless runName
      return runName +"_" + @baseName
    end
    
  end
end



