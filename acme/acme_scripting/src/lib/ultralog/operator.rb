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
  
    class CreateJarConfigFiles < Cougaar::Action
      PRIOR_STATES = ["OperatorServiceConnected"]
      DOCUMENTATION = Cougaar.document {
        @description = "Creates the Jar config files via operator machine."
        @example = "do_action 'CreateJarConfigFiles'"
      }
    
      def perform
        operator = @run['operator']
        cip = operator.test_cip.strip # strip cleans off whitespace...
        op_host = @run.society.get_service_host('operator')
        @run.comms.new_message(op_host).set_body("command[rexec]#{cip}/operator/createJarConfigFiles").request(30)
      end
    end
    
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
    
    class StartDatagrabberService < Cougaar::Action
      PRIOR_STATES = ['OperatorServiceConnected']
      DOCUMENTATION = Cougaar.document {
        @description = "Starts the Datagrabber service on the operator machine."
        @example = "do_action 'StartDatagrabberService'"
      }
      def perform
        operator = @run['operator']
        unless ::UltraLog::DataGrabber.is_running?(::UltraLog::DataGrabber.get_host_from_society(@run.society))
          operator.start_datagrabber_service
          sleep 30
        else
          @run.info_message("DataGrabber service already running...not started")
        end
      end
    end
    
    class StopDatagrabberService < Cougaar::Action
      PRIOR_STATES = ['OperatorServiceConnected']
      DOCUMENTATION = Cougaar.document {
        @description = "Stops the Datagrabber service on the operator machine."
        @example = "do_action 'StopDatagrabberService'"
      }
      def perform
        sleep 20
        operator = @run['operator']
        operator.stop_datagrabber_service
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
      @baseName = Time.now.strftime('%y-%m-%d_%H_%M')
    end
    
    def self.from_run(run, host)
      op = Operator.new(host)
      op.run = run
      op
    end
  
    def test
      send_command('test_cip', 2.minutes)
    end
    
    def reset_crypto
      send_command('reset_crypto', 2.minutes)
    end
    
    def clear_logs
      send_command('clear_logs', 20.minutes)
    end
    
    def clear_pnlogs
      send_command('clear_pnlogs', 20.minutes)
    end
    
    def clear_persistence
      send_command('clear_persistence', 20.minutes)
    end
    
    def archive_logs(runName=nil)
      send_command('archive_logs', 20.minutes, "#{composite_name(runName)} #{Dir.getwd} #{$0}")
    end
    
    def archive_db(runName=nil)
      send_command('archive_db', 20.minutes, composite_name(runName))
    end
    
    def start_datagrabber_service
      send_command('start_datagrabber_service', 2.minutes)
    end
    
    def stop_datagrabber_service
      send_command('stop_datagrabber_service', 2.minutes)
    end
    
    private
    
    def send_command(command, timeout, params="")
      @run.info_message "Sending Operator Command: command[#{command}]#{params}"
      chost = @run.society.hosts[@host]
      reply = @run.comms.new_message(chost).set_body("command[#{command}]#{params}").request(timeout)
      if reply.nil?
        @run.error_message "ERROR SENDING: command[#{command}]#{params}" 
        raise "Operator service timeout or failed connection."
      else
        @run.info_message "Result: #{reply.body}"
      end
      return reply.body
    end
    
    def composite_name(runName=nil)
      runName = @run.name if @run && runName==nil
      runName = "Unspecified" unless runName
      return runName +"_" + @baseName
    end
    
  end
end



