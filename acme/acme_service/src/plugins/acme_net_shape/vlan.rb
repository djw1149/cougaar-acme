#!/usr/bin/ruby

#
# This script reads the XML file which defines the
# network, and will set up the Router to route
# between each VLAN.
#
require "rexml/document"

$NET = 100

module VlanSupport
  class WANLink
    attr_accessor :to, :bandwidth
    def initialize( to, bandwidth )
      @to = to
      @bandwidth = bandwidth
    end
  end

  class Vlan
    attr_accessor :name, :id, :router, :netmask, :bandwidth, :device, :links, :vlan_names

    def initialize( device ) 
      @device = device
      @links = Array.new
    end

    def add_link( to, bandwidth ) 
      @links.push WANLink.new( to, bandwidth )
    end

    def stop_shaping
      `/sbin/tc qdisc del root dev #{@device}.#{id}`
    end

    def do_shaping
      # Root QDISC for this VLAN.
      `/sbin/tc qdisc add dev #{@device}.#{id} root handle 1:0 htb default 1`
      `/sbin/tc class add dev #{@device}.#{id} parent 1:0 classid 1:1 htb rate 128kbit ceil 128kbit`

      # For each link, create a CLASS
      links.each { |link|
        to_vlan = link.to
        # Add a Class to the primary QDisc
        `/sbin/tc class add dev #{@device}.#{id} parent 1:1 classid 1:#{to_vlan.id} htb rate #{link.bandwidth}Mbit burst 15k ceil #{link.bandwidth}Mbit`

        # Add the SFQ to the Class
        `/sbin/tc qdisc add dev #{@device}.#{id} parent 1:#{to_vlan.id} handle #{to_vlan.id}:1 sfq perturb 10`

        # And a filter, to let it know to use the class.
        `/sbin/tc filter add dev #{@device}.#{id} protocol ip parent 1: prio 1 u32 match ip src 10.#{$NET}.#{to_vlan.id.to_i - $NET}.0/24 flowid 1:#{to_vlan.id}`
#        puts "/sbin/tc filter add dev #{@device}.#{id} protocol ip parent 1: prio 1 u32 match ip src 10.#{$NET}.#{to_vlan.id.to_i - $NET}.0/24 flowid 1:#{to_vlan.id}"
      }
    end

    def up
      `/sbin/vconfig add #{@device} #{@id}`
      `/sbin/ifconfig #{@device}.#{@id} #{@router} netmask #{@netmask} up`
    end

    def down
      `/sbin/ifconfig #{@device}.#{@id} down`
      `/sbin/vconfig rem #{@device}.#{@id}`
    end
  end

  class Network 
    attr_accessor :device, :name, :vlans

    def initialize( xml_file )
      @vlans = Array.new
      @vlan_names = Hash.new

      vlan_config = REXML::Document.new(File.new(xml_file))
      @name = vlan_config.elements["network"].attributes["name"]
      @device = vlan_config.elements["network"].attributes["device"]

      vlan_config.elements.each("network/vlan") { |vlan_el|
        vlan = Vlan.new( @device )
        vlan.id = vlan_el.attributes["id"]
        vlan.name = vlan_el.attributes["name"]
        vlan.router = vlan_el.attributes["router"]
        vlan.netmask = vlan_el.attributes["netmask"]
        vlan.bandwidth = vlan_el.attributes["bandwidth"]

        @vlan_names[vlan.name] = vlan
        @vlans.push vlan
      }

      vlan_config.elements.each("network/vlan") { |vlan_el|
        vlan_from = @vlan_names[vlan_el.attributes["name"]]
        vlan_el.elements.each("link") { |link_el|
          vlan_to = @vlan_names[link_el.attributes["name"]]
          bandwidth = link_el.attributes["bandwidth"]
          vlan_from.add_link( vlan_to, bandwidth )
        } 
      }
    end

    def up
      # Nuke the existing IP Address
      #`/sbin/ifconfig #{device} 0.0.0.0 up`

      @vlans.each { |vlan| vlan.up }
    end

    def down
      @vlans.each { |vlan| vlan.down }
    end

    def do_shaping
      @vlans.each { |vlan| vlan.do_shaping }
    end

    def stop_shaping
      @vlans.each { |vlan| vlan.stop_shaping }
    end

    def shape( from_name, to_name, bandwidth )
      from_vlan = @vlan_names[from_name]
      to_vlan = @vlan_names[to_name]

      `/sbin/tc class change dev #{to_vlan.device}.#{to_vlan.id} parent 1:1 classid 1:#{from_vlan.id} htb rate #{bandwidth}Mbit burst 15k ceil #{bandwidth}Mbit`

#      `/sbin/tc class change dev #{to_vlan.device}.#{to_vlan.id} parent 1:1 classid 1:#{from_vlan.id} htb rate #{bandwidth}Mbit burst 15k ceil #{bandwidth}Mbit`
    end

    def disable_link( from_name, to_name )
      from_vlan = @vlan_names[from_name]
      to_vlan = @vlan_names[to_name]
 
      `/sbin/iptables -I FORWARD -i #{from_vlan.device}.#{from_vlan.id} -o #{to_vlan.device}.#{to_vlan.device} -j DROP`
    end

    def enable_link( from_name, to_name )
      from_vlan = @vlan_names[from_name]
      to_vlan = @vlan_names[to_name]
 
      `/sbin/iptables -I FORWARD -i #{from_vlan.device}.#{from_vlan.id} -o #{to_vlan.device}.#{to_vlan.device} -j ACCEPT`
    end


  end
end

