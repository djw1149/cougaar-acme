#!/usr/bin/ruby

#
# This script provides network services on each host to ACME.
#

module ACME; module Plugins

class Interface
  attr_accessor :name
  def initialize( name )
    @name = name
  end

  def state
    `cat /proc/net/PRO_LAN_Adapters/#{@name}/State`.strip!
  end

  def rate
    rate_RE = /rate (\S*)/
    qdisc = `/sbin/tc qdisc show dev #{@name}`

    rate_match = rate_RE.match( qdisc )
    
    rc = nil
    rc = rate_RE.match(qdisc)[1] unless rate_match.nil?

    rc 
  end
end

class Shaper
  extend FreeBASE::StandardPlugin

  def self.start(plugin)
    plugin["instance"].data = Shaper.new( plugin )
    plugin['log/info'] << "ACME::Plugin::Shaper[start]"

    plugin.transition(FreeBASE::RUNNING)
  end

  def self.stop(plugin)
    plugin["instance"].data.reset
    plugin['log/info'] << "ACME::Plugin::Shaper[stop]"

    plugin.transition(FreeBASE::LOADED)
  end

  attr_reader :plugin

  def initialize( plugin )
    super( )
    @plugin = plugin

    cmd = @plugin.properties["command"]
    desc = @plugin.properties["description"]
    
    @interfaces = Hash.new

    @plugin["/plugins/acme_host_communications/commands/#{cmd}/description"].data = desc
    @plugin["/plugins/acme_host_communications/commands/#{cmd}"].set_proc do |msg, cmd|
       case cmd
         # shape( interface, kbps ) - This method will shape the specified
         # interface.
         when /shape\((.*),(.*)\)/
           plugin['log/info'] << "Shaping interface #{$1} to #{$2}Kbps"
           @interfaces[$1] = Interface.new( $1 ) unless @interfaces[$1]
           do_shape( $1, $2 )

           reply = info($1)

         # unshape( interface ) - This method removes shaping on the specified
         # interface
         when /unshape\((.*)\)/
           plugin['log/info'] << "Removing shaping on interface #{$1}"
           @interfaces[$1] = Interface.new( $1 ) unless @interfaces[$1]
           do_unshape( $1 )

           reply = info($1)

         # reset( interface ) - This method will completely reset an interface
         # so it is enabled/not shaped.
         when /reset\((.*)\)/
           plugin['log/info'] << "Resetting interface #{$1}"
           @interfaces[$1] = Interface.new( $1 ) unless @interfaces[$1]
           do_reset( $1 )

           reply = info($1)

         # enable( interface ) - This method will enable a network interface.
         when /enable\((.*)\)/
           plugin['log/info'] << "Enabling Interface #{$1}"
           @interfaces[$1] = Interface.new( $1 ) unless @interfaces[$1]
           do_enable( $1 )
           reply = info($1)

         # disable( interface ) - This method will disable a network interface.
         when /disable\((.*)\)/
           plugin['log/info'] << "Disabling Interface #{$1}"
           @interfaces[$1] = Interface.new( $1 ) unless @interfaces[$1]
           do_disable( $1 )
           reply = info($1)
       
         # info( interface ) - This returns information about the specific interface.
         when /info\((.*)\)/
           @interfaces[$1] = Interface.new( $1 ) unless @interfaces[$1]
           reply = info($1)

         # iperf( host ) - Runs iperf to a specific host.  Returns its output.
         when /iperf\((.*)\)/
          plugin['log/info'] << "Measuring bandwidth to host #{$1}" 
          reply = "#{do_iperf($1)}"
         when /nslookup\((.*)\)/
          plugin['log/info'] << "Looking up #{$1}"
          reply = `nslookup #{$1} -silent | grep Address | grep -v \\# | cut -d: -f2`.strip!
         else 
           reply = "#{cmd} unknown-#{command}"
       end
       msg.reply.set_body( reply ).send
    end           
  end

  def do_shape( interface, bandwidth )
      ifs = @interfaces[interface]

      do_unshape( interface ) unless ifs.rate.nil?
      `/sbin/tc qdisc add dev #{interface} root handle 1:0 tbf limit #{bandwidth} rate #{bandwidth} burst 15k`
  end 

  def do_unshape( interface )
      `/sbin/tc qdisc del root dev #{interface}`
  end

  def do_disable( interface )
      `/sbin/ifdown #{interface}`
  end

  def do_enable( interface )
      `/sbin/ifup #{interface}`
  end

  def do_reset( interface )
      do_enable( interface )
      do_unshape( interface )
  end

  def do_iperf( host )
    `/usr/local/bin/iperf -c #{host} -t 70 -i 10 -f k`
  end

  def info( interface )
    ifs = @interfaces[interface]
    "<interface name=\"#{ifs.name}\" state=\"#{ifs.state}\" rate=\"#{ifs.rate}\" />"
  end

  def info_all
     rc = "<interfaces>"
     @interfaces.each_key { |if_name|
        rc += info( if_name )
     }
     rc += "</interfaces>"
  end

  def reset
    plugin['log/info'] << "Resetting Network Interfaces at ACME shutdown" 
    @interfaces.each_value { |iface|
      plugin['log/info'] << "Resetting: #{iface}" 
      do_reset( iface )
    }
  end


end

end; end
