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
  class InitializeNetwork < Cougaar::Action
    DOCUMENTATION = Cougaar.document {
      @description = "Initialize network.  All interfaces up and unshaped."
      @example = "do_action 'InitializeNetwork'"
    }

    def initialize( run )
      @run = run
      super( run )

      run['network'] = NetworkModel.discover(File.join(ENV['CIP'], "operator"), "*-net.xml")
    end

    def perform
      net = @run['network']

      @run.society.each_host { |host|
         case (host.get_facet(:host_type))
           when "standard":
              @run.comms.new_message(host).set_body("command[net]reset(#{host.get_facet(:interface)})").send()
           when "router":
              subnet = net.subnet[ host.get_facet(:subnet) ]

              # Reset the C-Link on the Router (Trunk!  Not Standard!)
              @run.comms.new_message(host).set_body("command[net]reset(#{subnet.make_interface(host.get_facet(:interface))})").send()
              
              # Each K-Link interface includes the VLAN already.  This is
              # because the VLAN ids are not the same.
              subnet.klink.each_value { |klink|
                 @run.comms.new_message(host).set_body("command[net]reset(#{klink.interface})").send()
              }
           when "migratory":
              host.each_facet(:subnet) { |facet|
                subnet = net.subnet[ facet.data ]
                @run.comms.new_message(host).set_body("command[net]reset(#{subnet.make_interface(host.get_facet(:interface))})").send()
                @run.comms.new_message(host).set_body("command[net]disable(#{subnet.make_interface(host.get_facet(:interface))})").send()
              }

              subnet = net.subnet[ host.get_facet(:default_subnet) ]
              @run.comms.new_message(host).set_body("command[net]enable(#{subnet.make_interface(host.get_facet(:interface))})").send()

              @run.error_message( "WARNING!  Migratory Hosts will not be fully implemented until after the PAD assessment." )
         end
      }
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
              host.each_facet(:subnet) { |facet|
                 subnet = net.subnet[ facet.data ]
                 @run.comms.new_message(host).set_body("command[net]shape(#{subnet.make_interface(host.get_facet(:interface))})").send()
              }
              @run.error_message("WARNING!  Migratory Hosts will not be implemented until after the PAD assessment.")
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
              @run.error_message("WARNING!  Migratory Hosts will not be implemented until after the PAD assessment.")
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
                  subnet = net.subnet[ facet.data ]
                  @run.comms.new_message(host).set_body("command[net]shape(#{subnet.make_interface(host.get_facet(:interface))},#{subnet.bw})").send()
                }
              else 
                subnet = net.subnet[ @target ]
                @run.comms.new_message(host).set_body("command[net]shape(#{subnet.make_interface(host.get_facet(:interface))},#{subnet.bw})").send()
              end

              @run.error_message("WARNING!  Migratory Hosts will not be implemented until after the PAD assessment.")
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
             @run.error_message("Migratory Hosts will not be implemented until after the PAD assessment.")
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

      @run.society.each_host { |host|
         case (host.get_facet(:host_type))
           when "standard":
              if (host.get_facet(:subnet) == @subnet) then
                @run.comms.new_message(host).set_body("command[net]shape(#{host.get_facet(:interface)},#{subnet.bw})").send()
              end
           # DON'T SHAPE THE ROUTERS!
           when "migratory":
             @run.error_message("Migratory Hosts will not be implemented until after the PAD assessment.")
         end
      }
    end
  end

  class ActivateNIC < Cougaar::Action
    DOCUMENTATION = Cougaar.document {
      @description = "Turns a NIC back on.  A facet is passed to determine which hosts NIC are to be restored.  An optional network is also provided to identify which NIC."
      @example = "do_action 'ActivateNIC', 'sv190', 'CONUS-REAR'"
    }

    def initialize( run, facet, target=nil )
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
              @run.comms.new_message(host).set_body("command[net]enable(#{host.get_facet(:interface)})").send

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
              raise Exception.new("You must provide a target to enable a Migratory Host interface!") if @target.nil?

              subnet = net.subnet[ @target ]
              @run.comms.new_message(host).set_body("command[net]enable(#{subnet.make_interface(host.get_facet(:interface))},#{subnet.bw})").send()

              @run.error_message("WARNING!  Migratory Hosts will not be implemented until after the PAD assessment.")
         end
      }
    end
  end

  class DeactivateNIC < Cougaar::Action
    DOCUMENTATION = Cougaar.document {
      @description = "Disable a specified network interface.  A facet is passed in to determine which hosts to disable, and an optional target for hosts with multiple network interfaces."
      @example = "do_action 'DeactivateNIC', 'sv190', 'CONUS-REAR'"
    }

    def initialize( run, facet, target=nil )
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
              @run.comms.new_message(host).set_body("command[net]disable(#{host.get_facet(:interface)})").send

           when "router":
              subnet = net.subnet[ host.get_facet(:subnet) ]
              if (@target.nil?) then
                 @run.error_message("WARNING!  Disabling all network interfaces on #{host.name}")
                 subnet.klink.each_value { |klink|
                   @run.comms.new_message(host).set_body("command[net]disable(#{klink.interface})").send
                 }
              else
                klink = subnet.klink[ @target ]
                puts "command[net]disable(#{klink.interface})"
                @run.comms.new_message(host).set_body("command[net]disable(#{klink.interface})").send
              end

           when "migratory":
              raise Exception.new("You must provide a target to disable a Migratory Host interface!") if @target.nil?

              subnet = net.subnet[ @target ]
              @run.comms.new_message(host).set_body("command[net]disable(#{subnet.make_interface(host.get_facet(:interface))},#{subnet.bw})").send()

              @run.error_message("WARNING!  Migratory Hosts will not be implemented until after the PAD assessment.")
         end
      }
    end
  end
end; end

