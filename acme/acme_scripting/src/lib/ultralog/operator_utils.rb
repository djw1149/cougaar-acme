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

require 'socket'
require 'rexml/document'

module Ultralog

  module OperatorUtils
    
    class HostManager
      def initialize(dir = nil)
        dir = File.join(ENV['CIP'], 'operator') unless dir
        @dir = dir
        @hostname = Socket.gethostname
        @hostaddress = IPSocket.getaddress(@hostname) 
      end
      
      def get_society_name(host=nil)
        society = load_society(host)
        name = society.name
        if name.include?("-")
          return name.split("-")[0]
        else
          return name
        end
      end
      
      def get_hosts_file(host=nil)
        host = @hostname unless host
        localhost_file = nil
        Dir.glob(File.join(@dir, "*hosts.xml")).each do |file|
          ts = Cougaar::SocietyBuilder.from_xml_file(file).society
          return file if ts.get_service_host("operator") && ts.get_service_host("operator").host_name.downcase==host.downcase
          localhost_file = file if ts.get_service_host("operator") && ts.get_service_host("operator").host_name.downcase=="localhost"
        end
        return localhost_file # may be nil
      end
      
      def load_society(host=nil)
        host = @hostname unless host
        society = nil
        localhost_society = nil
        
        Dir.glob(File.join(@dir, "*hosts.xml")).each do |file|
          ts = Cougaar::SocietyBuilder.from_xml_file(file).society
          society = ts if ts.get_service_host("operator") && ts.get_service_host("operator").host_name.downcase==host.downcase
          localhost_society = ts if ts.get_service_host("operator") && ts.get_service_host("operator").host_name.downcase=="localhost"
        end
        society = localhost_society unless society
        unless society
          raise "Could not find society for #{host}...you may not be logged into the society operator host"
        end
        return society
      end
      
    end

    class SMSNotify
      def initialize
        @sms_account = nil
        # voicestream accounts: 'phonenumber@voicestream.net'
        # sprint accounts 'phonenumber@messaging.sprintpcs.com'
        @phonelist = @sms_account ? [@sms_account] : []
      end

      def notify(error, *addresses)
        list = addresses.length > 0 ? addresses : @phonelist
        list.each do |number|
          IO.popen("mail -s '#{error}' #{number}", "w") do |io|
            io.putc(4)
            io.putc(13)
          end
          sleep 1
        end
      end
    end
  end
end

module Cougaar
  module Actions
    class SendSMSNotification < Cougaar::Action
      DOCUMENTATION = Cougaar.document {
        @description = "Sends an SMS message to a list of addresses."
        @parameters = [
          {:message => "Message to be sent."},
          {:addresses => "*addresses, If given, message will be sent to these addresses, otherwise it will be sent to default list"}
        ]
        @example = "do_action 'SendSMSNotification', 'Verify failed on host sm075'"
      }
 
      def initialize(run, message, *addresses)
        super(run)
        @message = message
        @addresses = addresses
      end

      def perform
        Ultralog::OperatorUtils::SMSNotify.new.notify(@message, *@addresses)
      end
    end
  end
end
