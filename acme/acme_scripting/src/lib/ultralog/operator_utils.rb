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

module Ultralog

  module OperatorUtils
    class HostManager
    
      def initialize(dir = nil)
        dir = File.join(ENV['CIP'], 'operator') unless dir
        @dir = dir
        @hostname = Socket.gethostname
        @hostaddress = IPSocket.getaddress(@hostname) 
      end
      
      def load_society(host=nil)
        host = @hostname unless host
        society = nil
        Dir.glob(File.join(@dir, "*hosts.xml")).each do |file|
          ts = Cougaar::SocietyBuilder.from_xml_file(file).society
          society = ts if  ts.get_service_host("operator") && ts.get_service_host("operator").host_name==@hostname
        end
        unless society
          raise "Could not find society for #{@hostname}...you may not be logged into the society operator host"
        end
        return society
      end
      
    end
  end
end