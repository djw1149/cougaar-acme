#!/usr/bin/ruby
#
# parse network.xml into QuO RSS config file
#
# usage
# ruby Metrics-rss-generate-sites-conf.rb net.xml > $CIP/configs/rss/TIC-Sites.conf
#
networkDef =  ARGV[0]
urlHost =  ARGV[1]
urlNode =  ARGV[2]

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
  a,b,c,d=vlan.router.chomp.split(/\s*\.\s*/)
  if vlan.netmask == "255.255.255.0"
    network="#{a}.#{b}.#{c}.0"
    return "#{network}/24"
  elsif vlan.netmask == "255.255.0.0"
    network="#{a}.#{b}.0.0"
    return "#{network}/16"
  elsif vlan.netmask == "255.255.255.240"
    lower = d.to_i - 1
    network="#{a}.#{b}.#{c}.#{lower}"
    return "#{network}/28"

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
  vlan.links.each { |link|
    # convert bandwidth to kilobits/sec
    bandwidth = link.bandwidth.to_f * 1000
    # convert vlan to <network>/<mask> format
    srcSite = toSite(vlan)
    dstSite = toSite(link.to)
    prefix="http://#{urlHost}:8800/\$#{urlNode}/metrics/writer"
    metric="?key=Site_Flow_#{srcSite}_#{dstSite}_Capacity_Max&value=#{bandwidth}"
    query="#{prefix}#{metric}"
    puts query 
    result = Cougaar::Communications::HTTP.get(query) 
    puts "result = #{result}"
  }
}
  
