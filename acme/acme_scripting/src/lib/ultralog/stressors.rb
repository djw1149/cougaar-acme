##
#  <copyright>
#  Copyright 2002 InfoEther, LLC
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

module Cougaar
  module Actions
    class DisableNetworkInterfaces < Cougaar::Action
      PRIOR_STATES = ["SocietyLoaded"]
      DOCUMENTATION = Cougaar.document {
        @description = "Disables the NIC one or more nodes' hosts."
        @parameters = [
          {:nodes=> "required, List of node names."}
        ]
        @example = "do_action 'DisableNetworkInterfaces', 'TRANSCOM-NODE', 'CONUS-NODE'"
      }
      def initialize(run, *nodes)
        super(run)
        @nodes = nodes
      end
      def perform
        @nodes.each do |node|
          cougaar_node = @run.society.nodes[node]
          cougaar_host = cougaar_node.host
          node_names = cougaar_host.nodes.collect { |node| node.name }
                    
          @run.info_message "Taking down network for host #{cougaar_host.name} that has nodes #{node_names.join(', ')}"
          if cougaar_node
            @run.comms.new_message(cougaar_node.host).set_body("command[nic]trigger").send
          else
            raise_failure "Cannot disable nic on node #{node}, node unknown."
          end
        end
      end
      def to_s
        return super.to_s + "(#{@nodes.join(', ')})"
      end
    end
    
    class DisableMemWasterLogging < Cougaar::Action
      PRIOR_STATES = ["SocietyRunning"]
    
      # Take the asset to get the inventory for at this agent
      def initialize(run, *nodes)
        super(run)
        @nodes = nodes
      end
    
      def perform
	if @nodes.empty? then
	  @run.society.each_node do |cougaar_node|
            data, uri = Cougaar::Communications::HTTP.get("#{cougaar_node.uri}/$#{cougaar_node.name}/mem-waster?log=disable")
          end
        else
          @nodes.each do |nodename|
            cougaar_node = @run.society.nodes[nodename]
            if cougaar_node
              data, uri = Cougaar::Communications::HTTP.get("#{cougaar_node.uri}/$#{nodename}/mem-waster?log=disable")
            else
              @run.error_message "DisableMemWasterLogging Could not find node: #{nodename}"
            end
          end
        end
      end
    end 

   class EnableMemWasterLogging < Cougaar::Action
      PRIOR_STATES = ["SocietyRunning"]
    
      # Take the asset to get the inventory for at this agent
      def initialize(run, *nodes)
        super(run)
        @nodes = nodes
      end
    
      def perform
	if @nodes.empty? then
	  @run.society.each_node do |cougaar_node|
            data, uri = Cougaar::Communications::HTTP.get("#{cougaar_node.uri}/$#{cougaar_node.name}/mem-waster?log=enable")
	  end
        else
          @nodes.each do |nodename|
            cougaar_node = @run.society.nodes[nodename]
            if cougaar_node
              data, uri = Cougaar::Communications::HTTP.get("#{cougaar_node.uri}/$#{nodename}/mem-waster?log=enable")
            else
              @run.error_message "EnableMemWasterLogging Could not find node: #{nodename}"
            end
          end
        end
      end
    end 

    class EnableNetworkInterfaces < Cougaar::Action
      PRIOR_STATES = ["SocietyLoaded"]
      DOCUMENTATION = Cougaar.document {
        @description = "Enables the NIC one or more nodes' hosts."
        @parameters = [
          {:nodes=> "required, List of node names."}
        ]
        @example = "do_action 'EnableNetworkInterfaces', 'TRANSCOM-NODE', 'CONUS-NODE'"
      }
      def initialize(run, *nodes)
        super(run)
        @nodes = nodes
      end
      def perform
        @nodes.each do |node|
          cougaar_node = @run.society.nodes[node]
          if cougaar_node
            @run.comms.new_message(cougaar_node.host).set_body("command[nic]reset").send
          else
            raise_failure "Cannot enable nic on node #{node}, node unknown."
          end
        end
      end
      def to_s
        return super.to_s + "(#{@nodes.join(', ')})"
      end
    end

    class StressCPU < Cougaar::Action
      PRIOR_STATES = ["SocietyLoaded"]
      DOCUMENTATION = Cougaar.document {
        @description = "Starts or stops the CPU stressor on one or more hosts."
        @parameters = [
          {:percent=> "required, The percentage of CPU stress to apply."},
          {:hosts=> "optional, The comma-separated list of hosts to stress.  If omitted, all hosts are stressed."}
        ]
        @example = "do_action 'StressCPU', 20, 'sb022,sb023'"
      }

      def initialize(run, percent, hosts = nil)
        super(run)
        @percent = percent
        if hosts
          @hosts = hosts.split(",")
        end
      end

      def perform
        unless @hosts
          @hosts = []
          @run.society.each_service_host("acme") do |host|
            @hosts << host.name
          end
          @hosts.uniq!
        end
        
        cmd = "command[cpu]#{@percent}"
        @hosts.each do |host|
          cougaar_host = run.society.hosts[host]
          @run.comms.new_message(cougaar_host).set_body(cmd).send if cougaar_host
        end
      end
    end
  end
end
