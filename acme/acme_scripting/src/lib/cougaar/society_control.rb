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

    class StartSociety < Cougaar::Action
      PRIOR_STATES = ["CommunicationsRunning"]
      RESULTANT_STATE = "SocietyRunning"
		  @debug = true
      def initialize(run, debug=false)
        super(run)
        @debug = debug
      end
 
      def perform
        pids = {}
        xml_model = @run["loader"] == "XML"
        node_type = ""
        if xml_model
          node_type = "xml_"
        end
        @run.society.each_active_host do |host|
          host.each_node do |node|
            node.add_parameter("-Dorg.cougaar.event.host=127.0.0.1")
            node.add_parameter("-Dorg.cougaar.event.port=5300")
            node.add_parameter("-Dorg.cougaar.event.experiment=#{@run.name}")
						if xml_model
						  msg_body = launch_xml_node(node)
						else
						  msg_body = launch_db_node(node)
						end
		        puts "Sending message to #{host.name} -- [command[start_#{node_type}node]#{msg_body}] \n" if @debug
            result = @run.comms.new_message(host).set_body("command[start_#{node_type}node]#{msg_body}").request(120)
            if result.nil?
              raise_failure "Could not start node #{node.name} on host #{host.host_name}"
            end
            pids[node.name] = result.body
          end
        end
        @run['pids'] = pids
      end

		def launch_db_node(node)
			 return node.parameters.join("\n")
		end

    class ConfigServer 
			attr_reader :port
		  @debug = false
			@@port = 12345
				
      def initialize(config, debug)
        @debug = debug
	      @config = config
				ready = false
				@port = @@port = @@port + 1
				while (not ready)
					begin
            @server = TCPServer.new(@port)
						ready = true
					  rescue
							@port = @port + 1
					end
				end
	      Thread.new(config) {|config|serveup(config)}
      end

      def serveup(config) 
				puts "Connection waiting on #{@port}\n" if @debug 
		    session = @server.accept
		    puts "Connection from #{session.addr} on #{@port}\n" if @debug
		    session.print(config)
		    session.close
		    puts "Connection closed on #{@port}. \n" if @debug
		    puts "Thread exiting\n" if @debug
				@server.close()
      end
    end

		def launch_xml_node(node)
	    #node.add_parameter("-Xdebug -Xrunjdwp:transport=dt_socket,server=y,address=9001,suspend=n")
	    #node.add_parameter("-Dorg.cougaar.nameserver.verbosity=2")
		
	    #node_society = Cougaar::Model::Society.new("society-for-#{node.name}")
	    #node_host = Cougaar::Model::Host.new(node.host.name)
	    #node_host.add_node(node)
	    #node_society.add_host(node_host)
      node_society = Cougaar::Model::Society.new( "society-for-#{node.name}" ) do |society|
        society.add_host( node.host.name ) do |host|
          host.add_node( node.clone(host) )
        end
      end
      cfg = ConfigServer.new(node_society.to_xml, @debug)
			ipinfo = Socket.getaddrinfo(Socket.gethostname(), cfg.port)
			ipaddr = ipinfo[0][3] # gets IP address
			text = "#{Socket.gethostname()}:#{cfg.port}\n"

      # Use this line if the nodes can't DNS back to the script (DHCP)
      #text = "#{ipaddr}:#{cfg.port}\n"

			return text
		end
    end
    
    class StopSociety <  Cougaar::Action
      PRIOR_STATES = ["SocietyRunning"]
      RESULTANT_STATE = "SocietyStopped"
      def perform
        xml_model = @run["loader"] == "XML"
        node_type = ""
        if xml_model
          node_type = "xml_"
        end
        pids = @run['pids']
        @run.society.each_host do |host|
          host.each_node do |node|
            result = @run.comms.new_message(host).set_body("command[stop_#{node_type}node]#{pids[node.name]}").request(60)
            if result.nil?
              raise_failure "Could not stop node #{node.name}(#{pids[node.name]}) on host #{host.host_name}"
            end
          end
        end
      end
    end
  end
  
  module States
    class SocietyLoaded < Cougaar::NOOPState
    end
    
    class SocietyRunning < Cougaar::NOOPState
    end
    
    class SocietyStopped < Cougaar::NOOPState
    end
    
    class RunStopped < Cougaar::State
      DEFAULT_TIMEOUT = 20.minutes
      PRIOR_STATES = ["SocietyStopped"]
      def process
        while(true)
          return if @run.stopped?
          sleep 2
        end
        puts "Run Stopped"
      end
    end
  end
  
end

  
