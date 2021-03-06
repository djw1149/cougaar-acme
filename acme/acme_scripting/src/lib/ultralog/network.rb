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

require 'ultralog/network_model'

module Cougaar; module Actions
  class MigratoryHelper
    def initialize( run, net, host )
      @run = run
      @net = net
      @host = host
    end

    def lookup( hostname )
      nslookup = `nslookup -sil #{hostname}`
      addr = nil
      nslookup.each_line do |line|
        case line
          when /Address: /
            addr = /Address: (.*)/.match( line )[1]
        end
      end
      addr
    end

    def switch_to( subnet )
      # Next, we manipulate DNS
      new_subnet = @net.subnet[ subnet ]
      old_ip = lookup( @host.name )
      new_ip = new_subnet.make_ip_address( old_ip )

      @run.info_message "Changing host #{@host.name} to use subnet #{subnet}/New IP: #{new_ip}"
 
      isUp = false
      if (@net.migratory_active_subnet.has_key?(@host)) then
        # Is it up or down?
        ifg = @run.comms.new_message(@host).set_body("command[rexec]ifconfig #{@net.subnet[@net.migratory_active_subnet[@host]].make_interface(@host.get_facet(:interface))}").send(30)
        isUp = ifg.body["UP BROADCAST"]
      else 
        isUp = true
      end

      @net.migratory_active_subnet[@host] = subnet

      # First, we disable all of the subnets.
      @host.get_facet(:subnet).split(/,/).each { |subnet_name|
                
        t_subnet = @net.subnet[ subnet_name ]
        @run.comms.new_message(@host).set_body("command[net]reset(#{t_subnet.make_interface(@host.get_facet(:interface))})").send()
        @run.comms.new_message(@host).set_body("command[net]disable(#{t_subnet.make_interface(@host.get_facet(:interface))})").send()
      }

      # Trigger the DNS changes
      @run.society.each_service_host('dns') do |dns_host|
        result = @run.comms.new_message(dns_host).set_body("command[dns]move(#{@host.name},#{new_ip})").send(30)
        @run.error_message("Unable to update IP Address.") if result.nil?
      end

      # Now, we activate the apropriate subnet. . . but only if it was up before.
      if (isUp) then
        @run.comms.new_message(@host).set_body("command[net]enable(#{new_subnet.make_interface(@host.get_facet(:interface))})").send()
      end
    end
  end

  class RouterInformation < Cougaar::Action
    DOCUMENTATION = Cougaar.document {
      @description = "Gather i nformation on all routers in the system.  Writes the results out to an XML file specified by the parameters."
      @example = "do_action 'RouterInformation', 'routers-stage-1.xml'"
    }

    def initialize( run, file )
      @run = run
      super( run )

      @file = file
    end

    def to_s
      "#{super.to_s}(#{@file})"
    end

    def perform
      netModel = @run['network']
      out = File.open( @file, "w" )

      out.puts("<?xml version='1.0'?>")
      out.puts("<network-information time='#{Time.now.gmtime}'>")
      
      @run.society.each_host { |host|
        case (host.get_facet(:host_type))
          when "router":
            subnet = netModel.subnet[ host.get_facet(:subnet) ]

            out.puts("  <host name='#{host.name}' host_type='#{host.get_facet(:host_type)}'>") 
            subnet.klink.each_value { |k_link|
              info = @run.comms.new_message(host).set_body("command[net]info(#{k_link.interface})").send(true)
              out.puts "    #{info.body}"

            }
            out.puts("  </host>")
        end
      }
      out.puts("</network-information>")
      out.close
     
      @run.archive_and_remove_file(@file, "Network Status")
    end
  end

  class InitializeNetwork < Cougaar::Action
    DOCUMENTATION = Cougaar.document {
      @description = "Initialize network.  All interfaces up and unshaped.  Migratory hosts either on their default, or restored to their position before a save."
      @example = "do_action 'InitializeNetwork'"
    }

    def initialize( run )
      @run = run
      super( run )

      model = NetworkModel.discover(File.join(ENV['CIP'], "operator"),  "*-net.xml")
      @run.archive_file( model.net_file, "Network Definition" )

      @run['network'] = model
    end

    def perform
      net = @run['network']
      net.migratory_active_subnet = Hash.new
      net.load_MAS

      @run.society.each_service_host("dns") do |dns_host|
         result = @run.comms.new_message( dns_host ).set_body("command[dns]reset").request(60)
         @run.error_message "WARNING! Unable to reset DNS to a known state." if result.nil?
      end

      hosts = []
      @run.society.each_host { |host| hosts << host }
      hosts.each_parallel do |host|
         case (host.get_facet(:host_type))
           # Standard Host
           when "standard":
              result = @run.comms.new_message(host).set_body("command[net]reset(#{host.get_facet(:interface)})").request(30)
              @run.error_message "WARNING!  Unable to reset standard host: #{host.name}" if result.nil?

           # Router Host
           when "router":
              subnet = net.subnet[ host.get_facet(:subnet) ]

              # Reset the C-Link on the Router (Trunk!  Not Standard!)
              result = @run.comms.new_message(host).set_body("command[net]reset(#{subnet.make_interface(host.get_facet(:interface))})").request(30)

              @run.error_message "WARNING!  Unable to reset router host: #{host.name}" if result.nil?
              
              # Each K-Link interface includes the VLAN already.  This is
              # because the VLAN ids are not the same.
              subnet.klink.each_value { |klink|
                 @run.comms.new_message(host).set_body("command[net]reset(#{klink.interface})").send()
              }

           # Migratory Host
           when "migratory":
              helper = MigratoryHelper.new( @run, net, host )
              subnet_home = net.migratory_active_subnet[host.name]
              subnet_home = host.get_facet(:default_subnet) unless subnet_home

              helper.switch_to( subnet_home )
         end
      end
    end
  end


  class ShapeNetwork < Cougaar::Action
    DOCUMENTATION = Cougaar.document {
      @description = "Shape network to default configuration.  All K-Links and C-Links are up and shaped."
      @example = "do_action 'ShapeNetwork'"
    }

    def initialize( run )
      @run = run
      super( run )
    end

    def perform
      net = @run['network']

      @run.society.each_host { |host|
         case (host.get_facet(:host_type))
           when "standard":
              subnet = net.subnet[ host.get_facet(:subnet) ]

              @run.comms.new_message(host).set_body("command[net]shape(#{host.get_facet(:interface)},#{subnet.bw})").send()
           when "router":
              subnet = net.subnet[ host.get_facet(:subnet) ]

              # DO NOT SHAPE the C-Link on the Router!!!
              
              # Each K-Link interface includes the VLAN already.  This is
              # because the VLAN ids are not the same.
              subnet.klink.each_value { |klink|
                 @run.comms.new_message(host).set_body("command[net]shape(#{klink.interface},#{klink.bw})").send()
              }
           when "migratory":
              host.get_facet(:subnet).split(/,/).each { |facet|
                 subnet = net.subnet[ facet ]
                 @run.comms.new_message(host).set_body("command[net]shape(#{subnet.make_interface(host.get_facet(:interface))},#{subnet.bw})").send()
              }
         end
      }
    end
  end

  class ShapeHost < Cougaar::Action
    DOCUMENTATION = Cougaar.document {
      @description = "Shape host to a specified bandwidth.  All C-Links or K-Links shaped as desired."
      @example = "do_action 'ShapeHost', 'REAR-CONUS-ROUTER', '56kbit', 'DIVISION'"
    }

    def initialize( run, facet, bw, target = nil )
      @run = run
      super( run )
      
      @facet = facet
      @bw = bw
      @target = target
    end

    def perform
      net = @run['network']

      @run.society.each_service_host(@facet) { |host|
         case (host.get_facet(:host_type))
           when "standard":
              @run.comms.new_message(host).set_body("command[net]shape(#{host.get_facet(:interface)},#{@bw})").send()
           when "router":
              raise Exception.new( "Target subnet must be specified when shaping router hosts." ) if @target.nil?
              subnet = net.subnet[ host.get_facet(:subnet) ]
              klink = subnet.klink[ @target ]

              raise Exception.new( "Subnet #{@target} is unavailable to router #{host.name}" ) if (klink.nil?)

              @run.comms.new_message(host).set_body("command[net]shape(#{klink.interface},#{@bw})").send
           when "migratory":
              raise Exception.new( "Target subnet must be specified when shaping migratory hosts." ) if @target.nil?
              subnet = net.subnet[ @target ]
              @run.comms.new_message(host).set_body("command[net]shape(#{subnet.make_interface(host.get_facet(:interface))},#{@bw})").send()
         end
      }
    end
  end

  class RestoreHost < Cougaar::Action
    DOCUMENTATION = Cougaar.document {
      @description = "Shape host to a specified bandwidth.  All C-Links or K-Links shaped as desired."
      @example = "do_action 'RestoreHost', 'REAR-CONUS-ROUTER', 'DIVISION'"
    }

    def initialize( run, facet, target = nil )
      @run = run
      super( run )
      
      @facet = facet
      @target = target
    end

    def perform
      net = @run['network']

      @run.society.each_service_host(@facet) { |host|
         case (host.get_facet(:host_type))
           when "standard":
              subnet = net.subnet[ host.get_facet(:subnet) ]
              @run.comms.new_message(host).set_body("command[net]shape(#{host.get_facet(:interface)},#{subnet.bw})").send()
           when "router":
              subnet = net.subnet[ host.get_facet(:subnet) ]
              if (@target.nil?) then
                 subnet.klink.each_value { |klink|
                   @run.comms.new_message(host).set_body("command[net]shape(#{klink.interface},#{klink.bw})").send
                 }
              else
                klink = subnet.klink[ @target ]

                @run.comms.new_message(host).set_body("command[net]shape(#{klink.interface},#{klink.bw})").send
              end
           when "migratory":
              if (@target.nil?) then
                host.each_facet(:subnet) { |facet|
                  subnet = net.subnet[ facet.cdata ]
                  @run.comms.new_message(host).set_body("command[net]shape(#{subnet.make_interface(host.get_facet(:interface))},#{subnet.bw})").send()
                }
              else 
                subnet = net.subnet[ @target ]
                @run.comms.new_message(host).set_body("command[net]shape(#{subnet.make_interface(host.get_facet(:interface))},#{subnet.bw})").send()
              end

         end
      }
    end
  end

  class ShapeSubnet < Cougaar::Action
    DOCUMENTATION = Cougaar.document {
      @description = "Shape an entire subnet to a specified bandwidth.  All C-Links shaped as desired."
      @example = "do_action 'ShapeSubnet', 'CONUS-REAR', '56kbit'"
    }

    def initialize( run, subnet, bw )
      @run = run
      super( run )
      
      @subnet = subnet
      @bw = bw
    end

    def perform
      net = @run['network']

      @run.society.each_host { |host|
         case (host.get_facet(:host_type))
           when "standard":
              if (host.get_facet(:subnet) == @subnet) then
                @run.comms.new_message(host).set_body("command[net]shape(#{host.get_facet(:interface)},#{@bw})").send()
              end
           # DON'T SHAPE ROUTERS!
           when "migratory":
              sn = net.subnet[@subnet]

              if (host.get_facet(:subnet)[@subnet]) then
                @run.comms.new_message(host).set_body("command[net]shape(#{sn.make_interface(host.get_facet(:interface))},#{@bw})").send()
              end
         end
      }
    end
  end

  class RestoreSubnet < Cougaar::Action
    DOCUMENTATION = Cougaar.document {
      @description = "Reshape entire subnet to default bandwidth."
      @example = "do_action 'RestoreSubnet', 'CONUS-REAR'"
    }

    def initialize( run, subnet )
      @run = run
      super( run )
      
      @subnet = subnet
    end

    def perform
      net = @run['network']
      subnet = net.subnet[ @subnet ]

      @run.society.each_host do |host|
         case (host.get_facet(:host_type))
           when "standard":
              if (host.get_facet(:subnet) == @subnet) then
                @run.comms.new_message(host).set_body("command[net]shape(#{host.get_facet(:interface)},#{subnet.bw})").send()
              end
           # DON'T SHAPE THE ROUTERS!
           when "migratory":
              sn = net.subnet[@subnet]
              if (host.get_facet(:subnet)[@subnet]) then
                @run.comms.new_message(host).set_body("command[net]shape(#{sn.make_interface(host.get_facet(:interface))},#{sn.bw})").send()
              end
         end
      end
    end
  end

  class ActivateKLinks < Cougaar::Action
    DOCUMENTATION = Cougaar.document {
      @description = "Turns a K-Link back on for a router.  The first argument is a facet which identifies the router.  The second argument is the target of the K-Link to re-enable.  When the link comes back up, it should have the same shaping as before it was disabled."
      @example = "do_action 'ActivateKLinks', 'CONUS-REAR-router', 'DIV-SUP'"
    }

    def initialize( run, facet, target )
      @run = run
      super( run )
      
      @facet = facet
      @target = target
    end

    def perform
      net = @run['network']

      @run.society.each_service_host(@facet) { |host|
         case (host.get_facet(:host_type))
           when "standard":
              @run.error_message("WARNING!  Trying to activate a K-Link on a standard host.")
           when "router":
              subnet = net.subnet[ host.get_facet(:subnet) ]
              if (@target.nil?) then
                 subnet.klink.each_value { |klink|
                   @run.comms.new_message(host).set_body("command[net]enable(#{klink.interface})").send
                 }
              else
                klink = subnet.klink[ @target ]

                @run.comms.new_message(host).set_body("command[net]enable(#{klink.interface})").send
              end

           when "migratory":
              @run.error_message("WARNING!  Migratory host #{host.name} do not have K-Links.")
         end
      }
    end
  end

  class IntermittentKLinks < CyclicStress
    DOCUMENATION = Cougaar.document {
      @description = "Cyclicly deactivates and re-activates a network interface."
      @parameters = [
        {:handle => "required, Handle to refer to the intermittent thread.",
         :on_time => "required, Amount of time stressor is on.",
         :off_time => "required, Amount of time stressor is off.",
         :router => "required, Router which hosts the K-Link.",
         :subnet => "required, Target subnet of K-Link."}
      ]
      @example = "do_action 'IntermittentKLinks', 'IN-K-001', 4.minutes, 4.minutes, 'CONUS-REAR-router', 'DIV'"
    }
    def initialize(run, handle, on_time, off_time, router, target)
      super(run, handle, on_time, off_time)
      @on_time = on_time
      @off_time = off_time
      @handle = handle
      @router = router
      @target = target
    end

    def to_s
       "#{super.to_s}(#{@on_time}, #{@off_time}, #{@handle}, #{@router}, #{@target})"
    end

    def perform
      net = @run['network']
      @run.society.each_service_host( @router ) { |host|
         case (host.get_facet(:host_type))
           when "standard":
             @run.error_message("WARNING!  Standard Host #{host.name} have no K-Links.")
           when "migratory":
             @run.error_message("WARNING!  Migratory Host #{host.name} not supported.")
           when "router":
             subnet = net.subnet[ host.get_facet(:subnet) ]
             klink = subnet.klink[ @target ]
             @run.error_message("WARNING!  Router #{host.name} has no K-Link to #{@target}") if klink.nil?
         end
      }
      super
    end

    def stress_on
      net = @run['network']
      @run.society.each_service_host( @router ) { |host|
         case (host.get_facet(:host_type))
           when "router":
             subnet = net.subnet[ host.get_facet(:subnet) ]
             klink = subnet.klink[ @target ]
             @run.info_message("Disabling #{host.name}:#{klink.interface} network interface")
             rc = @run.comms.new_message(host).set_body("command[net]disable(#{klink.interface})").send(true)
         end
     }          
    end

    def stress_off
      net = @run['network']
      @run.society.each_service_host( @router ) { |host|
         case (host.get_facet(:host_type))
           when "router":
             subnet = net.subnet[ host.get_facet(:subnet) ]
             klink = subnet.klink[ @target ]
             @run.info_message("Enabling #{host.name}:#{klink.interface} network interface")
             rc = @run.comms.new_message(host).set_body("command[net]enable(#{klink.interface})").send(true)
         end
      }          
    end
  end

  class IntermittentCLinks < CyclicStress
    DOCUMENATION = Cougaar.document {
      @description = "Cyclicly deactivates and re-activates a network interface."
      @parameters = [
        {:handle => "required, Handle to refer to the intermittent thread.",
         :on_time => "required, Amount of time stressor is on.",
         :off_time => "required, Amount of time stressor is off.",
         :facet => "required, Facet on hosts to disable C-Link on."}
      ]
      @example = "do_action 'IntermittentCLinks', 'IN-C-001', 4.minutes, 4.minutes, 'C-LINK-KILLS'"
    }

    def initialize(run, handle, on_time, off_time, facet)
      super(run, handle, on_time, off_time)
      @facet = facet
    end

    def perform
      net = @run['network']
      @run.society.each_service_host( @facet ) { |host|
         case (host.get_facet(:host_type))
           when "migratory":
             @run.error_message("WARNING!  Unable to perform intermittent C-Links on Migratory Host.")
           when "router":
             subnet = net.subnet[ host.get_facet(:subnet) ]
             klink = subnet.klink[ @target ]
             @run.error_message("WARNING!  Must kill C-Links on standard hosts.")
         end
      }
      super
    end

    def stress_on
      net = @run['network']
      @run.society.each_service_host( @facet ) { |host|
         case (host.get_facet(:host_type))
           when "standard":
             @run.info_message("Disabling #{host.name}:#{host.get_facet(:interface)} network interface")
             @run.comms.new_message(host).set_body("command[net]disable(#{host.get_facet(:interface)})").send()
         end
     }          
    end

    def stress_off
      net = @run['network']
      @run.society.each_service_host( @facet ) { |host|
         case (host.get_facet(:host_type))
           when "standard":
             @run.info_message("Enabling #{host.name}:#{host.get_facet(:interface)} network interface")
             @run.comms.new_message(host).set_body("command[net]enable(#{host.get_facet(:interface)})").send
         end
      }          
    end
  end


  class DeactivateKLinks < Cougaar::Action
    DOCUMENTATION = Cougaar.document {
      @description = "Disable a specified network interface.  A facet is passed in which identifies the router to affect.  The subnet field is required, and is the target of the K-Link to deactivate.."
      @example = "do_action 'DeactivateKLinks', 'CONUS-REAR-router', 'DIV-SUP'"
    }

    def initialize( run, facet, target )
      @run = run
      super( run )
      
      @facet = facet
      @target = target
    end

    def perform
      net = @run['network']

      @run.society.each_service_host(@facet) { |host|
         case (host.get_facet(:host_type))
           when "standard":
              @run.error_message("WARNING!  Attempting to disable a K-Link on a standard host.")
           when "router":
              subnet = net.subnet[ host.get_facet(:subnet) ]
              if (@target.nil?) then
                 @run.error_message("WARNING!  Disabling all network interfaces on #{host.name}")
                 subnet.klink.each_value { |klink|
                   @run.comms.new_message(host).set_body("command[net]disable(#{klink.interface})").send
                 }
              else
                klink = subnet.klink[ @target ]
                @run.comms.new_message(host).set_body("command[net]disable(#{klink.interface})").send
              end

           when "migratory":
              @run.error_message("WARNING!  Migratory Hosts have no K-Links.")
         end
      }
    end
  end

  class Migrate < Cougaar::Action
    def initialize( run, node, subnet )
      super( run )
      @nodename = node
      @subnet_name = subnet 
    end

    def perform
      cougaar_node = @run.society.nodes[@nodename]
      cougaar_host = cougaar_node.host

      net = run['network']
     

      if (cougaar_host.get_facet(:host_type) != 'migratory') then
        @run.error_message "Cannot move a host of type: #{cougaar_host.get_facet(:host_type)} / Host = #{cougaar_host.name}"
      else 
        if (net.migratory_active_subnet[cougaar_host] == @subnet_name) then
          @run.error_message "Attempting to move host #{cougaar_host} to #{@subnet_name} when it is already there."
        else
          cougaar_host.each_node do |c_node|
            if (c_node != cougaar_node) then
              @run.error_message "WARNING:  Moving node: #{c_node.name} to #{@subnet_name}"
            end
          end

          helper = MigratoryHelper.new( @run, net, cougaar_host )
          helper.switch_to( @subnet_name )
        end
      end
      net.save_MAS
    end
  end
end; end

