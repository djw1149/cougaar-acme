##
#  <copyright>
#  Copyright 2002, 2004 BBN Technologies
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

require 'rexml/document'

module Cougaar
  class KLink
    attr_accessor :to, :interface, :bw
    
    def initialize( to, interface, bw )
      @to = to
      @interface = interface
      @bw = bw
    end
  end

  class Subnet
    attr_accessor :name, :ip, :vlan, :bw, :klink

    def initialize( name, ip, vlan, bw )
       @name = name
       @ip = ip
       @bw = bw
       @vlan = vlan
       @klink = Hash.new
    end

    def make_interface( interface="eth0" )
       "#{interface}.#{vlan}"
    end

    def make_ip_address( old_ip )
       host_RE = /\d*\.\d*\.\d*\.(\d*)/
       subnet_RE = /(\d*\.\d*\.\d*)/
       host_num = host_RE.match( old_ip )[1]
       subnet = subnet_RE.match( @ip )[1]
       "#{subnet}.#{host_num}"
    end
  end
      
  class NetworkModel
    attr_accessor :operator, :subnet, :net_file, :migratory_active_subnet

    def initialize
       @subnet = Hash.new
       @migratory_active_subnet = Hash.new
    end

    def self.discover( operator, mask )
      Dir[File.join(operator, mask)].each { |filename|
         netModel = NetworkModel.from_xml_file( filename )
         if (netModel.operator == `hostname`.chomp!) then
           netModel.net_file = filename
           return netModel
         end
      }

      throw Exception.new("Unable to find apropriate network description file.")

    end

    def self.from_xml_file( filename )
       rc = NetworkModel.new
       doc = REXML::Document.new(File.new( filename ))
       doc.elements.each("network") { |netL|
          rc.operator = netL.attributes["operator"]
          netL.elements.each("subnet") { |subnetL|
            subnet = Subnet.new( 
                       subnetL.attributes["name"],
                       subnetL.attributes["ip"],
                       subnetL.attributes["vlan"],
                       subnetL.attributes["bw"])

            subnetL.elements.each("k-link") { |klL|
               klink = KLink.new( klL.attributes["to"], 
                                  klL.attributes["interface"],
                                  klL.attributes["bw"] )

               subnet.klink[klL.attributes["to"]] = klink
            }
          
            rc.subnet[subnetL.attributes["name"]] = subnet
          }                                
       } 
       rc
    end
  end
end


