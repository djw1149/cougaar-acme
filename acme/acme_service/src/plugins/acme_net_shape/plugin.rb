#!/usr/bin/ruby

#
# This script provides network services on each host to ACME.
#

=begin
 * <copyright>  
 *  Copyright 2001-2004 BBN Technologies
 *
 *  under sponsorship of the Defense Advanced Research Projects  
 *  Agency (DARPA).  
 *   
 *  You can redistribute this software and/or modify it under the 
 *  terms of the Cougaar Open Source License as published on the 
 *  Cougaar Open Source Website (www.cougaar.org <www.cougaar.org> ).   
 *   
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
 *  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
 *  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR 
 *  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT 
 *  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
 *  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT 
 *  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
 *  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY 
 *  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
 *  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
 *  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 * </copyright>  
=end

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

  def rx_bytes
    rx_RE = /RX bytes:(\d*)/

    rx_match = rx_RE.match( `/sbin/ifconfig #{@name}` )

    return rx_match[1] unless rx_match.nil?
    nil
  end

  def tx_bytes
    tx_RE = /TX bytes:(\d*)/

    tx_match = tx_RE.match( `/sbin/ifconfig #{@name}` )

    return tx_match[1] unless tx_match.nil?
    nil
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
    rc = "<interface name=\"#{ifs.name}\" state=\"#{ifs.state}\" rate=\"#{ifs.rate}\" rx=\"#{ifs.rx_bytes}\" tx=\"#{ifs.tx_bytes}\" />"
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
