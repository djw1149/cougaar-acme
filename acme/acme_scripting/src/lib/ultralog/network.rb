##
#  <copyright>
#  Copyright 2002 BBN Technologies
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

module Cougaar; module Actions
  class WANLink
    @@links = Hash.new
    attr_accessor :noc, :from_vlan, :to_vlan

    def initialize( run, noc, from_vlan, to_vlan )
       @run = run
       @noc = noc
       @from_vlan = from_vlan
       @to_vlan = to_vlan
    end

    def disable
      @run.comms.new_message( @noc ).set_body("command[rexec]iptables -I FORWARD -i eth0.#{@from_v} -o eth0.#{@to_v} -j DROP").request(30)
    end

    def enable
      @run.comms.new_message( @noc ).set_body("command[rexec]iptables -I FORWARD -i eth0.#{@from_v} -o eth0.#{@to_v} -j DROP").request(30)
    end

    def set_bandwidth( bw )
       @run.comms.new_message( @noc ).set_body("command[rexec]/sbin/tc class change dev eth0.#{@to_vlan} parent 1:1 classid 1:#{@from_vlan} htb rate #{bw}Mbit burst 15k ceil #{bw}Mbit").request( 30 )
    end

    def start_intermittent( on_time, off_time )
      @intermit = Thread.new {
         while( true ) 
           sleep( on_time )
           disable
           sleep( off_time )
           enable
         end
      }
    end

    def stop_intermittent
      @intermit.kill
    end

    def WANLink.find( name )
      @@links[name]
    end

    def WANLink.store( name, wl ) 
      @@links[name] = wl
    end

  end

  class DefineWANLink < Cougaar::Action
    DOCUMENTATION = Cougaar.document {
      @description = "Define a WAN Link for further actions."
      @parameters = [
        {:name=>"required, Name of the WAN Link.",
         :noc=>"required, Network Operation Controller",
         :from_vlan=>"required, VLAN which originates traffic.",
         :to_vlan=>"required, VLAN which is the target of the traffic."}]
      @example = "do_action 'DefineWANLink', 'link.2.3', 2, 3"
    }

    def initialize( run, name, noc, from_vlan, to_vlan )
      super( run )
      @name = name; @noc = noc; @from_vlan = from_vlan; @to_vlan = to_vlan
    end

    def perform
      wl = WANLink.new( @run, @run.society.hosts[@noc], @from_vlan, @to_vlan)
      WANLink.store( @name, wl )
    end
  end

  class EnableNetworkShaping < Cougaar::Action
    DOCUMENTATION = Cougaar.document {
      @description = "Enable network shaping at the K level."
      @parameters = [
         {:noc=>"required, Hostname which contains the router."}
      ]
      @example = "do_action 'EnableNetworkShaping', 'sv023'"
    }

    def initialize( run, nocname )
      super( run )
      @nocname = nocname
    end

    def perform
      host = @run.society.hosts[@nocname]
      @run.comms.new_message(host).set_body("command[shape]trigger").send
    end
  end

  class DisableNetworkShaping < Cougaar::Action
    DOCUMENTATION = Cougaar.document {
      @description = "Disable network shaping at the K level."
      @parameters = [
         {:noc=>"required, Hostname which contains the router."}
      ]
      @example = "do_action 'DisableNetworkShaping', 'sv023'"
    }

    def initialize( run, nocname )
      super( run )
      @nocname = nocname
    end

    def perform
      host = @run.society.hosts[@nocname]
      @run.comms.new_message(host).set_body("command[shape]reset").send
    end
  end

  class DisableWANLink < Cougaar::Action
    DOCUMENTATION = Cougaar.document {
      @description = "Disable a WAN link between two VLANs."
      @parameters = [
         {:wan_link=>"required, Name of previously defined WAN Link."}
      ]
      @example = "do_action 'DisableWANLink', 'link.2.3'"
    }

    def initialize( run, wan_link )
      super( run )
      @wan_link = wan_link
    end

    def perform
      WANLink.find( @wan_link ).disable
    end
  end

  class RenableWANLink < Cougaar::Action
    DOCUMENTATION = Cougaar.document {
      @description = "Disable a WAN link between two VLANs."
      @parameters = [
         {:wan_link=>"required, Name of previously defined WAN Link."}
      ]
      @example = "do_action 'RenableWANLink', 'link.2.3'"
    }

    def initialize( run, wan_link )
      super( run )
      @wan_link = wan_link
    end

    def perform
      WANLink.find( @wan_link ).enable
    end
  end

  class StartIntermitWANLink < Cougaar::Action
    DOCUMENTATION = Cougaar.document {
      @description = "Make a WAN link between two VLANs intermittent."
      @parameters = [
         {:wan_link=>"required, Name of previously defined WAN Link.",
          :on_time=>"required, Amount of time for the link to be ON.",
          :off_time=>"required, Amount of time for the link to be OFF."}
      ]
      @example = "do_action 'StartIntermitWANLink', 'link.2.3'"
    }

    def initialize( run, wan_link, on_time, off_time )
      super( run )
      @wan_link = wan_link
      @on_time = on_time
      @off_time = off_time
    end

    def perform
      WANLink.find( @wan_link ).start_intermittent( @on_time, @off_time )
    end
  end

  class StopIntermitWANLink < Cougaar::Action
    DOCUMENTATION = Cougaar.document {
      @description = "Makes a WAN link constant two VLANs."
      @parameters = [
         {:wan_link=>"required, Name of previously defined WAN Link."}
      ]
      @example = "do_action 'StopIntermitWANLink', 'link.2.3'"
    }

    def initialize( run, wan_link )
      super( run )
      @wan_link = wan_link
    end

    def perform
      WANLink.find( @wan_link ).stop_intermittent
    end
  end

  class SetBandwidth < Cougaar::Action
    DOCUMENTATION = Cougaar.document {
      @description = "Changes bandwidth on a WAN Link."
      @parameters = [
         {:wan_link=>"required, Name of previously defined WAN Link.",
          :bandwidth=>"required, New bandwidth on link."}
      ]
      @example = "do_action 'SetBandwidth', 'link.2.3', 0.25"
    }

    def initialize( run, wan_link, bandwidth )
      super( run )
      @wan_link = wan_link
      @bandwidth = bandwidth
    end

    def perform
      WANLink.find( @wan_link ).set_bandwidth( @bandwidth )
    end
  end

end; end

