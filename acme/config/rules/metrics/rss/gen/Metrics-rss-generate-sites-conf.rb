#!/usr/bin/ruby
#
# parse network.xml into QuO RSS config file
#
# usage
# ruby Metrics-rss-generate-sites-conf.rb net.xml > $CIP/configs/rss/TIC-Sites.conf
#
networkDef =  ARGV[0]
# Setup Ultralog load path
CIP = ENV['CIP']
RULES = File.join(CIP, 'csmart','config','rules')
$:.unshift File.join(CIP, 'csmart', 'acme_scripting', 'src', 'lib')
$:.unshift File.join(CIP, 'csmart', 'acme_service', 'src', 'redist')
$:.unshift File.join(CIP, 'csmart', 'acme_service', 'src', 'plugins')
require 'cougaar/scripting'
require 'ultralog/scripting'
# require code to read network.xml file
require 'acme_net_shape/vlan.rb'

def toSite(vlan)
  if vlan.netmask == "255.255.255.0"
    a,b,c,d=vlan.router.chomp.split(/\s*\.\s*/)
    network="#{a}.#{b}.#{c}.0"
    return "#{network}/24"
  else
    return "#{vlan.router}/??"
  end
end

# where is min?
def min (a, b)
  if a.to_f <= b.to_f
    return a
  else
    return b
  end
end

# Read in network.xml file
network=VlanSupport::Network.new(networkDef)
puts "#############################"
puts "#  Network #{network.name} from file #{networkDef}"
puts "#############################"
puts "#"

# Expand implicit links where the router does not traffic shape
# These links are limited by the intra-vlan bandwidth
# so the link should be the min of the src and dst
network.vlans.each { |srcVlan|
  # add intra-site bandwidth
  srcVlan.add_link(srcVlan,srcVlan.bandwidth)
  # add links for ones that are not already there 
  network.vlans.each {|dstVlan|
    found = false
    srcVlan.links.each { |link|
      if link.to == dstVlan 
	found = true
      end
    }
    if ! found 
      srcVlan.add_link(dstVlan,min(srcVlan.bandwidth,dstVlan.bandwidth))
    end
  }
}

# Output in Sites config format
network.vlans.each { |vlan|
  puts "#"
  puts "# VLAN #{vlan.name} #{vlan.router} #{vlan.netmask} #{vlan.bandwidth}Mbps"
  vlan.links.each { |link|
    # convert bandwidth to kilobits/sec
    bandwidth = link.bandwidth.to_f * 1000
    # convert vlan to <network>/<mask> format
    srcSite = toSite(vlan)
    dstSite = toSite(link.to)
    puts "Site_Flow_#{srcSite}_#{dstSite}_Capacity_Max_value = #{bandwidth}"
  }
}
  
