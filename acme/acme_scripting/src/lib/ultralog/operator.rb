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
      DOCUMENTATION = Cougaar.document {
        @description = "Indicates that the operator service was successfully connected to."
      }
    end
  end
  
  module Actions
    class ConnectOperatorService < Cougaar::Action
      RESULTANT_STATE = 'OperatorServiceConnected'
      DOCUMENTATION = Cougaar.document {
        @description = "Verifies that the supplied host is running the ACME Service and has the Operator plugins enabled."
        @parameters = [
          {:host => "required, The host running the ACME Service and Operator plugin."}
        ]
        @example = "do_action 'ConnectOperatorService', 'sb022'"
      }
      def initialize(run, host=nil)
        super(run)
        @host = host
      end
      def perform
        unless @host
          ohost = @run.society.get_service_host("operator")
          raise "Could not locate operator host (host with <facet service='operator'/>)" if ohost==nil
          @host = ohost.host_name
        end
        operator = ::UltraLog::Operator.from_run(@run, @host)
        result = operator.test
        if result =~ /ERROR SENDING/ || result =~ /Unregistered command/
          puts "Invalid Operator Service #{@host}\n#{result}"
          Cougaar.logger.error "Invalid Operator Service #{@host}\n#{result}"
        else
          @run['operator'] = operator
        end
      end
    end
    
    class ClearPersistence < Cougaar::Action
      PRIOR_STATES = ['OperatorServiceConnected']
      DOCUMENTATION = Cougaar.document {
        @description = "Clears society persistence data and keystores."
        @example = "do_action 'ClearPersistence'"
      }
      def perform
        operator = @run['operator']
        operator.clear_persistence
      end
    end
    
    class ClearLogs < Cougaar::Action
      PRIOR_STATES = ['OperatorServiceConnected']
      DOCUMENTATION = Cougaar.document {
        @description = "Clears society log data."
        @example = "do_action 'ClearLogs'"
      }
      def perform
        operator = @run['operator']
        operator.clear_logs
      end
    end
    
    class ClearPersistenceAndLogs < Cougaar::Action
      PRIOR_STATES = ['OperatorServiceConnected']
      DOCUMENTATION = Cougaar.document {
        @description = "Clears society persistence, log data and keystores."
        @example = "do_action 'ClearPersistenceAndLogs'"
      }
      def perform
        operator = @run['operator']
        operator.clear_pnlogs
      end
    end
    
    class ArchiveLogs < Cougaar::Action
      PRIOR_STATES = ['OperatorServiceConnected']
      DOCUMENTATION = Cougaar.document {
        @description = "Archives the log data."
        @example = "do_action 'ArchiveLogs'"
      }
      def perform
        operator = @run['operator']
        operator.archive_logs
      end
    end
    
    class ArchiveDatabases < Cougaar::Action
      PRIOR_STATES = ['OperatorServiceConnected']
      DOCUMENTATION = Cougaar.document {
        @description = "Archives database data."
        @example = "do_action 'ArchiveDatabases'"
      }
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
      @run.info_message "Sending Operator Command: command[#{command}]#{params}"
      reply = @run.comms.new_message("#{@host}@#{@run.comms.jabber_server}/acme").set_body("command[#{command}]#{params}").request(timeout)
      @run.error_message "ERROR SENDING: command[#{command}]#{params}" if reply.nil?
      @run.info_message "Result: #{reply.body}"
      return reply.body
    end
    
    def composite_name(runName=nil)
      runName = @run.name if @run && runName==nil
      runName = "Unspecified" unless runName
      return runName +"_" + @baseName
    end
    
  end
end



