# require 'ultralog/network_mode'

require 'rexml/document'

class NICState
  attr_accessor :name, :state, :rate

  def initialize( message )
    stateDoc = REXML::Document.new( message.body )
    @name = stateDoc.elements["interface"].attributes["name"]
    @state = stateDoc.elements["interface"].attributes["state"]
    @rate = stateDoc.elements["interface"].attributes["rate"]
  end
end

module Cougaar; module Actions
  class HostPairAction < Cougaar::Action
    def initialize( run, group1, group2 )
      @run = run
      super( run )
     
      @group1 = group1
      @group2 = group2
    end

    def perform
      @run.society.each_host { |host1|
         if (host1.get_facet(:group) == @group1) then
           @run.society.each_host { |host2|
              if (host2.get_facet(:group) == @group2) then
                 if (host1 != host2) then
                    result = assert(host1, host2)
                    if (result.nil?) then
                       assert_failed( host1, host2 )
                    end
                 end
              end
           }
         end
      }
    end

    def assert_failed( host1, host2 )
      @run.error_message("Generic Error Message: #{host1} #{host2}")
    end

    def assert( host1, host2 )
      true
    end
  end

  class AssertConnection < HostPairAction
    DOCUMENTATION = Cougaar.document {
      @description = "This verifies that every host specified in parameter 1 can talk to every host specified in parameter 2."
      @example = "do_action 'AssertConnection', 'acme', 'acme'"
    }

    def initialize( run, group1, group2 )
      @run = run
      super( run, group1, group2 )
    end

    def assert_failed( host1, host2 ) 
      @run.error_message("No Connection between #{host1.name} and #{host2.name}")
    end

    def assert( host1, host2 )
      nsl = @run.comms.new_message(host1).set_body("command[net]nslookup(#{host2.name})").send(true)
      return nil if nsl.body == ""

      tr = @run.comms.new_message(host1).set_body("command[rexec]traceroute -w 2 -m 8 #{nsl.body}").send(true)

      tr.body[nsl.body]
    end
  end

  class AssertNoConnection < HostPairAction
    DOCUMENTATION = Cougaar.document {
      @description = "This verifies that no host specified in parameter 1 can talk to every host specified in parameter 2."
      @example = "do_action 'AssertConnection', 'acme', 'acme'"
    }

    def initialize( run, group1, group2 )
      @run = run
      super( run, group1, group2 )
    end

    def assert_failed( host1, host2 ) 
      @run.error_message("No Connection between #{host1.name} and #{host2.name}")
    end

    def assert( host1, host2 )
      nsl = @run.comms.new_message(host1).set_body("command[net]nslookup(#{host2.name})").send(true)
      if nsl.body == "" then
        return true
      end

      tr = @run.comms.new_message(host1).set_body("command[rexec]traceroute -w 2 -m 8 #{nsl.body}").send(true)

      return nil if tr.body[nsl.body]
      true
    end
  end

  class AssertHops < HostPairAction
    DOCUMENTATION = Cougaar.document {
      @description = "This verifies that every host specified in parameter 1 can talk to every host specified in parameter 2."
      @example = "do_action 'AssertConnection', 'acme', 'acme'"
    }

    def initialize( run, group1, group2, hops )
      @run = run
      super( run, group1, group2 )
     
      @hops = hops
    end

    def assert_failed( host1, host2 )
       @run.error_message("Number of hops from #{host1.name} to #{host2.name} expected to be #{@hops}")
    end

    def assert( host1, host2 )
      nsl = @run.comms.new_message(host1).set_body("command[net]nslookup(#{host2.name})").send(true)

      tr = @run.comms.new_message(host1).set_body("command[rexec]traceroute -w 2 -m 15 #{nsl.body}").send(true)

      hop_list = tr.body.split("\n")
      hop_list.pop

      hop_list.length == @hops
    end
  end

  class AssertBandwidth < HostPairAction
    DOCUMENTATION = Cougaar.document {
      @description = "This verifies that the bandwidth is within the range expected.  (Expected +/- Delta)"
      @example = "do_action 'AssertBandwidth', '100', '100', '100000', '1000'"
    }

    def initialize( run, group1, group2, expected, delta ) 
      super(run, group1, group2)
      @expected = expected
      @delta = delta
      @last_bw = "N/A"
    end

    def assert_failed( host1, host2 )
       @run.error_message("Bandwidth from #{host1.name} to #{host2.name} expected to be #{@expected} +/- #{@delta} Kbits/sec")
       @run.error_message("Offending IPERF Line: #{@last_bw}")
    end

    def assert( host1, host2 )
      kbaud_RE = /(\d*(\.\d*)?) Kbits\/sec/

      iperf = @run.comms.new_message(host1).set_body("command[net]iperf(#{host2.name})").send(true)

      iperf_results = iperf.body.split("\n")
      skip = true

      iperf_results.each { |line|
        kb_match = kbaud_RE.match( line )
        if (kb_match) then
          if (skip) then
            # First result has burstiness
            skip = nil
          else
            bw = kb_match[1].to_f

            @last_bw = line
            return nil if (bw < @expected - @delta)
            return nil if (bw > @expected + @delta)
          end
        end
      }

      return true        
    end
  end


  class AssertNonAppServices < Cougaar::Action
    DOCUMENTATION = Cougaar.document {
      @description = "This verifies that every host specified in parameter 1 has access to non-application specific services."
      @example = "do_action 'AssertNonAppServices'"
    }

    def initialize( run, hosts )
      @run = run
      super( run )
     
      @hosts = hosts
    end

    def perform
      @run.society.each_service_host(@hosts) { |host|
         dns_RE = /\d*\.\d*\.\d*\.\d*/

         dns = @run.comms.new_message(host).set_body("command[net]nslookup(#{host.name})").send(true)
         
         if (dns_RE.match(dns.body).nil?) then
           @run.error_message("Service DNS is not available on host #{host.name}")
         end

         nfs = @run.comms.new_message(host).set_body("command[rexec]ls /mnt/shared").send(true)
         if (nfs.body == "") then
           @run.error_message("Service NFS is not available on host #{host.name}")
         end

         nis = @run.comms.new_message(host).set_body("command[rexec]su -c'echo $USER' asmt").send(true)
         if (nis.body.strip! != "asmt") then
           @run.error_message("Service NIS is not available on host #{host.name}")
         end
      }
    end
  end

end; end
