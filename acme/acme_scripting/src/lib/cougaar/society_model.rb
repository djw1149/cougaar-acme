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

require 'cougaar/society_utils'

$debug_society_model = false

module Cougaar
  module Model

    ##
    # Mixin module for components that have facets
    #
    module Multifaceted
    
      ##
      # The Attribute class holds a collection of key-value pairs so facets can hold complex data.
      #
      class Facet
  
        def initialize(data=nil, &block)
          @map = {}
          unless data.nil?
            if data.kind_of?(Hash)
              data.each_pair { |key, value| self[key] = value }
            else
              @map[:cdata] = data
            end
          end
          yield self if block_given?
        end
        
        ##
        # Direct method for returning cdata
        #
        def cdata
          return @map[:cdata]
        end
        
        ##
        # Direct method for setting cdata
        #
        def cdata=(value)
          @map[:cdata] = value
        end
        
        ##
        # Gets the value of a given facet key
        #
        # key:: [String | Symbol] The facet key to get
        # return:: [String] The facet key's value
        #
        def [](key)
          return @map[make_key(key)]
        end
        
        ##
        # Sets the value of a given facet key
        #
        # key:: [String | Symbol] The facet key
        # value:: [String] The facet value
        #
        def []=(key, value)
          @map[make_key(key)] = value
        end
        
        ##
        # Checks to see if the set of keys is a subset of the total set of keys in this facet
        #
        # keys:: [Array[String|Symbol]] Set of keys to match against
        # return:: [Boolean] true if keys are a subset, otherwise false
        #
        def match?(keys)
          keys = keys.collect { | key | make_key(key) }
          ((@map.keys & keys).size == keys.size)
        end
        
        def to_xml(indent=0)
          xml = "#{' ' * indent}<facet "
          @map.each_pair do |key, value|
            value = 
            xml << "#{key}='#{REXML::Text.normalize(value)}' " if key != :cdata
          end
          if @map.has_key?(:cdata)
            xml << ">#{@map[:cdata]}</facet>\n"
          else
            xml << " />\n"
          end
          xml
        end
        
        def to_ruby(indent, context)
          ruby = "#{' ' * indent}#{context}.add_facet do |facet|\n"
          @map.each_pair do |key, value|
            ruby << "#{' ' * indent}  facet[:#{key}]='#{value}'\n"
          end
          ruby << "#{' ' * indent}end\n"
          ruby
        end
  
        ##
        # Creates a copy of this facet
        #
        def clone
          return Facet.new(@map)
        end
        
        private
        
        def make_key(key)
          unless key.kind_of?(String) || key.kind_of?(Symbol)
            raise "Attribute key must be a String or Symbol, not a #{key.class}" 
          end
          key = key.intern if key.kind_of? String
          return key
        end
        
      end
    
      
      ##
      # Add an facet(s) to the component
      # 
      # facet_data:: [String | Hash] The facet(s) to add
      #
      def add_facet(facet_data=nil, &block)
        @facets ||= []
        if facet_data.kind_of? Facet
          @facets << facet_data
        else
          a = Facet.new(facet_data, &block)
          @facets << a
        end
      end
      
      ##
      # Iterates over each facet
      #
      # yield:: [String] The facet
      #
      def each_facet(*keys)
        return unless @facets
        @facets.each do |facet|
          yield facet if facet.match?(keys)
        end
      end
      
      ##
      # Does this component have a component of the given name
      #
      # name:: [default=nil, String | Symbol] The facet key
      # block:: [yield facet] If your block returns true, the has_facet? will return true
      # return:: [Boolean] True if it has a facet
      #
      def has_facet?(name=nil, &block)
        if name
          return get_facet(name) ? true : false
        else
          @facets.each { | facet | return true if block.call(facet) }
        end
        return false
      end
      
      ##
      # Returns the first facet that contains the specified key name
      #
      # name:: [String | Symbol] The facet key
      # return:: [String] The facet key's value
      #
      def get_facet(name)
        return nil unless @facets
        each_facet(name) { | facet | return facet[name] }
        return nil
      end
      
      ##
      # Removes all facets on this host, node or agent
      #
      def remove_all_facets
        @facets = nil
      end
      
      ##
      # Returns the XML encoding of the components facets
      #
      # indent:: [Integer] The number of spaces to indent
      # return:: [String] The XML encoding of the facets
      #
      def get_facet_xml(indent)
        xml = ""
        each_facet do |facet|
          xml << facet.to_xml(indent)
        end
        return xml
      end
      
      ##
      # Returns the Ruby encoding of the components facets
      #
      # indent:: [Integer] The number of spaces to indent
      # context:: [String] The component context (name) e.g. host, node, agent
      # return:: [String] The Ruby encoding of the facets
      #
      def get_facet_ruby(indent, context)
        ruby = ""
        each_facet do |facet|
          ruby << facet.to_ruby(indent, context)
        end
        return ruby
      end
    end
    
    ##
    # The Cougaar::Society class is the root of the model of the society
    # that is to be run.  A Society is composed of Hosts (computers) that
    # contain node(s) and nodes contain agent(s).
    # 
    # There are several instance varables that represent instances of the
    # Query class, specifically :nodes and :agents.
    #
    class Society
      include Multifaceted
      
      DEFAULT_COUGAAR_PORT = 8800
      
      attr_reader :name, :agents, :nodes, :hosts
      attr_accessor :cougaar_port, :monitor
      
      ##
      # Constructs a Society with an optional name block
      #
      def initialize(name=nil, &block)
        @name = name
        @cougaar_port = DEFAULT_COUGAAR_PORT
        @hostList = []
        @hostIndex = {}
        setup_queries
        yield self if block
      end
      
      ##
      # Adds a host to the society
      #
      # host:: [Cougaar::Host | String] the Host or name of the host
      # block:: [Block] The constructor block
      # return:: [Cougaar::Host] The new host
      #
      def add_host(host, &block)
        if host.kind_of? Host
          if @hostIndex[host.host_name]
            return nil # host names must be unique society wide
          end
          @hostIndex[host.host_name] = host
          @hostList << host
          host.society = self
          $debug_society_model && SocietyMonitor.each_monitor { |m| m.host_added(host) }
          return host
        else
          if @hostIndex[host]
            return nil # host names must be unique society wide
          end
          newHost = Host.new(host)
          @hostIndex[host] = newHost
          newHost.society = self
          @hostList << newHost
          $debug_society_model && SocietyMonitor.each_monitor { |m| m.host_added(newHost) }
          newHost.init_block(&block)
          return newHost
        end
      end
      
      ##
      # Removes a host (and its nodes/agents/components) from the society.
      #
      # host:: [Cougaar::Model::Host | String] The host object or name
      #
      def remove_host(host)
        if host.kind_of? String
          host = @hostIndex[host]
          return if host.nil?
        end
        @hostIndex.delete(host.host_name)
        @hostList.delete(host)
        $debug_society_model && SocietyMonitor.each_monitor { |m| m.host_removed(host) } 
      end
      
      ##
      # Iterates over each host
      #
      # yield:: [Cougaar::Host] The host instance
      #
      def each_host
        @hostList.each {|host| yield host}
      end
      
      ##
      # Iterates over each (active) host, or host that has
      # nodes on it.
      #
      # yield:: [Cougaar::Model::Host] The host instance
      #
      def each_active_host
        @hostList.each {|host| yield host if host.nodes.size > 0}
      end
      
      ##
      # Iterates over each node
      #
      # yield:: [Cougaar::Model::Node] The node instance
      #
      def each_node
        @hostList.each {|host| host.each_node {|node| yield node} }
      end
      
      ##
      # Iterates over each agent (across all nodes and hosts)
      #
      # include_node_agent:: [Boolean] If true, the node agents are included as well as the agents
      # yield:: [Cougaar::Model::Agent] The agent instance
      #
      def each_agent(include_node_agent=false, &block)
        @hostList.each {|host| host.each_node {|node| node.each_agent {|agent| yield agent}}}
        each_node_agent(&block) if include_node_agent
      end
      
      ##
      # Iterates over each node agent
      #
      # yield:: [Cougaar::Agent] The agent instance
      #
      def each_node_agent
        @hostList.each {|host| host.each_node {|node| yield node.agent} }
      end
      
      ##
      # Returns the total number of agents in the society
      #
      # include_node_agent:: [Boolean] If true, the node agents are included in the count as well as the agents
      #
      def num_agents(include_node_agent=false)
        count = 0
        @hostList.each { |host| 
          host.each_node {|node| count += node.agents.size }
          count += host.nodes.size if include_node_agent
        }
        return count
      end

      ##
      # Clones this society/hosts/nodes/agents/plugins
      #
      # return:: [Cougaar::Society] The newly cloned society
      #
      def clone
        society = Society.new(@name)
        each_facet { |facet| society.add_facet(facet.clone) }
        each_host {|host| society.add_host host.clone(society)}
        society
      end
      
      ##
      # Recursively iterates over all hosts, nodes and agents and removed their facet data
      # 
      def remove_all_facets
        @facets = nil
        each_host do |host|
          host.remove_all_facets
          host.each_node do |node|
            node.remove_all_facets
            node.each_agent do |agent|
              agent.remove_all_facets
            end
          end
        end
      end

      ##
      # Returns an XML representation of the society
      #
      # return:: [String] The society XML data
      #
      def to_xml
        xml = "<?xml version='1.0'?>\n" +
              "<society name='#{@name}'\n" +
              "  xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'\n" + 
              "  xsi:noNamespaceSchemaLocation='http://www.cougaar.org/2003/society.xsd'>\n"
        xml << get_facet_xml(2)
        each_host {|host| xml << host.to_xml}
        xml << "</society>"
        return xml
      end
      
      ##
      # Returns a Ruby (source) representation of the society
      #
      # return:: [String] The society Ruby data
      #
      def to_ruby
        ruby =  "Cougaar::Model::Society.new('#{@name}') do |society|\n"
        ruby << get_facet_ruby(2, 'society')
        each_host {|host| ruby << host.to_ruby}
        ruby << "end\n"
        ruby
      end
      
      ##
      # Override the parameter across all nodes
      #
      # param:: [String] The -D parameter to overrride
      # value:: [String] The new value
      #
      def override_parameter(param, value)
        @hostList.each do |host|
          host.each_node do |node|
            node.override_parameter(param, value)
          end
        end
      end
      
      private
      
      ##
      # Sets up query objects responding to 
      # @agents and @nodes
      #
      def setup_queries
        @agents = Query.new(self) do |name|
          result = nil
          each_host do |host|
            host.each_node do |node|
              node.each_agent do |agent| 
                if agent.name==name
                  result = agent
                  break
                end
              end
            end
          end
          result
        end
        @nodes = Query.new(self) do |name|
          result = nil
          each_host do |host|
            host.each_node do |node|
              if node.name==name
                result = node
                break
              end
            end
          end
          result
        end
        @hosts = Query.new(self) do |name|
          result = nil
          name = (name.index('|') ? name[(name.index('|')+1)..-1] : name)
          each_host do |host|
            if host.host_name==name
              result = host
              break
            end
          end
          result
        end
      end
    end
    
    ##
    # Holds the model of a host that is part of an experiment
    #
    class Host
      attr_reader :nodes
      attr_accessor :name, :society
      
      include Multifaceted
      
      ##
      # Constructs a host with the optional name
      #
      # name:: [String=nil] The name of this host
      #
      def initialize(name=nil)
        @name = name
        @nodes = []
        @nodeIndex = {}
        yield self if block_given?
      end
      
      def init_block
        yield self if block_given?
      end
      
      def ip
        hostInfo = `/usr/bin/host #{@name}`
        infoList = hostInfo.split(/ /)
        infoList.pop.chomp!
      end
      
      ##
      # Adds a node to this host
      #
      # node:: [Cougaar::Node | String] the Node or name of the node
      # block:: [Block] the optional block to pass to the node constructor
      # return:: [Cougaar::Node] The new node
      #
      def add_node(node, &block)
        if node.kind_of? Node
          if @society && @society.nodes[node.name]
            return nil # node names must be unique society wide
          end
          @nodeIndex[node.name] = node
          @nodes << node
          node.host = self
          $debug_society_model && SocietyMonitor.each_monitor { |m| m.node_added(node) }
          return node
        else
          if @society && @society.nodes[node]
            return nil # node names must be unique society wide
          end
          newNode = Node.new(node)
          @nodeIndex[node] = newNode
          newNode.host = self
          @nodes << newNode
          $debug_society_model && SocietyMonitor.each_monitor { |m| m.node_added(newNode) }
          newNode.init_block(&block)
          return newNode
        end
      end
      
      ##
      # Removes a node and its agents/components from this host
      #
      # node:: [Cougaar::Model::Node] The node to remove from this host
      #
      def remove_node(node)
        @nodeIndex.delete(node.name)
        @nodes.delete(node)
        $debug_society_model && SocietyMonitor.each_monitor { |m| m.node_removed(node) }
      end
      
      ##
      # Iterates over each node on this host
      #
      # yield:: [Cougaar::Node] The node instance
      #
      def each_node
        @nodes.each {|node| yield node}
      end
      
      ##
      # Removes host from the society
      #
      def remove
        @society.remove_host(self)
      end
      
      ##
      # Clones this host/nodes/agents/plugins
      #
      # return:: [Cougaar::Host] The newly cloned host
      #
      def clone(society)
        host = Host.new(@name, @enclave)
        host.society = society
        each_node { |node| host.add_node(node.clone(host)) }
        each_facet { |facet| host.add_facet(facet.clone) }
        host
      end
      
      def to_xml
        xml = "  <host name='#{@name}'>\n"
        xml << get_facet_xml(4)
        each_node {|node| xml << node.to_xml}
        xml << "  </host>\n"
        return xml
      end
      
      def to_ruby
        ruby =  "  society.add_host('#{@name}') do |host|\n"
        ruby << get_facet_ruby(4, 'host')
        each_node {|node| ruby << node.to_ruby}
        ruby << "  end\n"
        ruby
      end
      
      ##
      # Used for sorting by host_name
      #
      # other:: [Host] The host to compare to
      # 
      def <=>(other)
        return host_name<=>other.host_name
      end
      
      ##
      # If the host's name has a | bar returns the text after the bar
      #
      # return:: [String] The name of this host (stripped of | data)
      #
      def host_name
        @name.index('|') ? @name[(@name.index('|')+1)..-1] : @name
      end
      
      ##
      # If the host's uri name facet or host_name if not set
      #
      # return:: [String] The (uri) name of this host 
      #
      def uri_name
        return get_facet(:uriname) || host_name
      end
      
    end
  
    ##
    # Holds the model of a node that is part of an experiment.
    # Parameters are stored in the #paramters facet
    #
    class Node
      attr_reader :agents, :name, :parameters
      attr_accessor :host, :agent, :prog_parameters, :env_parameters, :classname
      
      include Multifaceted
      
      ##
      # Constructs a node with optional name
      # 
      # name:: [String=nil] The name of the node
      #
      def initialize(name=nil)
        @agents = []
        @agentIndex = {}
        @env_parameters = []
        @prog_parameters = []
        @parameters = []
        self.name = name
        @agent = Agent.new(@name)
        @agent.node = self
        yield self if block_given?
        unless @classname
          @classname = 'org.cougaar.bootstrap.Bootstrapper'
        end
      end
      
      def name=(name)
        @name = name
        add_parameter("-Dorg.cougaar.node.name=#{@name}") unless @parameters.include?("-Dorg.cougaar.node.name=#{@name}")
      end
        
      def cougaar_port
        found = nil
        port = nil
        @parameters.each do |param| 
          found = param if param[0, 32]=='-Dorg.cougaar.lib.web.http.port='
        end
        if found
          begin
            port = found[32..-1].strip.to_i
          rescue
            puts "Malformed Cougaar port on Node #{@name}"
          end
        end
        port = host.society.cougaar_port unless port
        return port
      end
      
      def secure_cougaar_port
        found = nil
        port = nil
        @parameters.each {|param| found = param if param[0, 33]=='-Dorg.cougaar.lib.web.https.port='}
        if found
          begin
            port = found[33..-1].strip.to_i
          rescue
          end
        end
        return port
      end
      
      def uri
        cp = cougaar_port
        protocol = 'http'
        if cp < 0
          cp = secure_cougaar_port
          protocol << 's'
        end
        if cp.nil?
          raise "Could not form valid URL for node #{@name} on host #{@host.uri_name}\nCougaar port set to -1 but HTTPS port not set."
        end
        return "#{protocol}://#{@host.uri_name}:#{cp}"
      end

      def secure_uri
        cp = secure_cougaar_port
        if cp.nil?
          raise "Could not form valid secure URL for node #{@name} on host #{@host.uri_name}\nCougaar HTTPS port not set."
        end
        return "https://#{@host.uri_name}:#{cp}"
      end
      
      def init_block
        yield self if block_given?
      end
      
      #Methods delegated to node agent
      def add_components(array)
        @agent.add_components(array)
      end
      
      def add_component(component=nil, &block)
        @agent.add_component(component, &block)
      end
      
      def remove_component(classname)
        @agent.remove_component(classname)
      end
      
      def each_component(&block)
        @agent.each_component(&block)
      end
      
      def has_component?(name=nil, &block)
        @agent.has_component?(name, &block)
      end
      #End delegated methods
      
      ##
      # Add an agent to this node
      #
      # agent:: [Cougaar::Agent | String] Name or agent instance
      # block:: [Block] Optional constructor block
      # return:: [Cougaar::Agent] Agent instance
      #
      def add_agent(agent, &block)
        if agent.kind_of? Agent
          if @host && @host.society.agents[agent.name]
            return nil # agent name must be unique society wide
          end
          @agentIndex[agent.name] = agent
          @agents << agent
          agent.node = self
          $debug_society_model && SocietyMonitor.each_monitor { |m| m.agent_added(agent) }
          agent
        else
          if @host && @host.society.agents[agent]
            return nil # agent name must be unique society wide
          end
          newAgent = Agent.new(agent)
          @agentIndex[agent] = newAgent
          @agents << newAgent
          newAgent.node = self
          $debug_society_model && SocietyMonitor.each_monitor { |m| m.agent_added(newAgent) }
          newAgent.init_block(&block)
          newAgent
        end
      end
      
      def remove_agent(agent)
        @agentIndex.delete(agent.name)
        @agents.delete(agent)
        $debug_society_model && SocietyMonitor.each_monitor { |m| m.agent_removed(agent) }
      end
      
      def remove_all_agents
        list = @agents
        @agents = []
        @agentIndex = {}
        list.each do |agent|
          $debug_society_model && SocietyMonitor.each_monitor { |m| m.agent_removed(agent) }
        end
      end
      
      ##
      # Iterates over each agent in this node
      #
      # yield:: [Cougaar::Agent] Agent instance
      #
      def each_agent
        @agents.each {|agent| yield agent}
      end
      
      ##
      # Appends 'value' onto the end of the
      # string referenced by param.  Does nothing if
      # value is already in the string.
      #
      #  param=val1;val2;....
      #
      # param:: [String] the -D param to overrride
      # value:: [String] the new value
      #
      def append_value_on_parameter(param, value)
        o = nil
        @parameters.each do |orig|
          o = orig if orig[0..(param.size)]=="#{param}="
        end
        if !o
          @parameters << "#{param}=#{value}\\;"
        else
          if !o.include? value
            @parameters.delete(o)
            @parameters << "#{o}#{value}\\;"
          end
        end
      end

      ##
      # Prepends 'value' onto the beginning of the
      # string referenced by param.  Does nothing if
      # value is already in the string.
      # 
      # This assumes the form of the property is:
      #  param=val1;val2;....
      #
      # param:: [String] the -D param to overrride
      # value:: [String] the new value
      #
      def prepend_value_on_parameter(param, value)
        o = nil
        @parameters.each do |orig|
          o = orig if orig[0..(param.size)]=="#{param}="
        end
        if !o
          @parameters << "#{param}=#{value}\\;"
        else
          if !o.include? value
            property = o.split("=")
            values = property[1].split(/[\\;\"]/)
            values.delete_if {|v| v.empty?}
            values.unshift(value)
            @parameters.delete(o)
            @parameters << "#{property[0]}=#{values.join("\\;")}\\;"
          end
        end
      end

      ##
      # Override a parameter specifically on this node
      #
      # param:: [String] the -D param to overrride
      # value:: [String] the new value
      #
      def override_parameter(param, value)
        o = nil
        @parameters.each do |orig|
          o = orig if orig[0..(param.size)]=="#{param}="
        end
        @parameters.delete(o) if o
        @parameters << "#{param}=#{value}"
      end
      
      ##
      # Removes all parameters matching param_pattern and adds
      # the value as the new parameter.
      #
      # param_pattern:: [Regex | String] The pattern of parameters to remove
      # value:: [String] The new parameter
      #
      def replace_parameter(param_pattern, new_param)
        @parameters.delete_if {|param| param =~ param_pattern}
        @parameters << new_param
      end

      ##
      # Add an env_paramter to this node (or a set of parameters)
      #
      # param:: [Array | String] encoded as param=value
      #
      def add_env_parameter(param)
        if param.kind_of? Array
          @env_parameters.concat param
        else
          @env_parameters << param
        end
      end
      
      ##
      # Iterates over each env_parameter
      #
      # yield:: [String] env_parameter encoded as param=value
      #
      def each_env_parameter
        @env_parameters.each {|param| yield param}
      end

      # Remove an environment parameter specifically on this node
      #
      # param:: [String] the -D param to remove
      #
      def remove_env_parameter(param)
        o = nil
        @env_parameters.each do |orig|
          o = orig if orig[0..(param.size)]=="#{param}="
        end
        @env_parameters.delete(o) if o
      end


      ##
      # Add a prog_paramter to this node (or a set of parameters)
      #
      # param:: [Array | String] encoded as param=value
      #
      def add_prog_parameter(param)
        if param.kind_of? Array
          @prog_parameters.concat param
        else
          @prog_parameters << param
        end
      end
      
      ##
      # Iterates over each prog_parameter
      #
      # yield:: [String] prog_parameter encoded as param=value
      #
      def each_prog_parameter
        @prog_parameters.each {|param| yield param}
      end

      
      ##
      # Add a paramter to this node (or a set of parameters)
      #
      # param:: [Array | String] encoded as param=value
      #
      def add_parameter(param)
        if param.kind_of? Array
          @parameters.concat param
        else
          @parameters << param
        end
        @parameters.uniq!
      end

      # Remove a parameter specifically on this node
      #
      # param:: [String|Regexp] the -D param to remove if String, or pattern if regexp
      #
      def remove_parameter(param)
        if param.kind_of?(String)
          o = nil
          @parameters.each do |orig|
            o = orig if orig[0..(param.size)]=="#{param}="
          end
          @parameters.delete(o) if o
        elsif param.kind_of?(Regexp)
          @parameters.delete_if {|p| p =~ param}
        end
      end
      
      ##
      # Iterates over each parameter
      #
      # yield:: [String] parameter encoded as param=value
      #
      def each_parameter
        @parameters.each {|param| yield param}
      end
      
      def remove
        @host.remove_node(self)
      end
      
      ##
      # Clones this node(parameters)/agents/plugins
      #
      # return:: [Cougaar::Node] The newly cloned node
      #
      def clone(host)
        node = Node.new(@name)
        node.host = host
        each_agent {|agent| node.add_agent agent.clone(host)}
        each_facet { |facet| node.add_facet(facet.clone) }
        node.parameters.concat @parameters
        node.env_parameters.concat @env_parameters
        node.prog_parameters.concat @prog_parameters
        node.classname = @classname
        node.agent = @agent.clone(host)
        node
      end
      
      def to_xml
        xml = "    <node name='#{@name}'>\n"
        xml << "      <class>\n        #{@classname}\n      </class>\n" if @classname
        xml << get_facet_xml(6)
        each_prog_parameter do |param|
          xml << "      <prog_parameter>\n        #{param}\n      </prog_parameter>\n"
        end
        each_env_parameter do |param|
          xml << "      <env_parameter>\n        #{param}\n      </env_parameter>\n"
        end
        each_parameter do |param|
          xml << "      <vm_parameter>\n        #{param}\n      </vm_parameter>\n"
        end
        @agent.each_component do |comp|
          xml << comp.to_xml(6)
        end
        each_agent {|agent| xml << agent.to_xml}
        xml << "    </node>\n"
        return xml
      end
      
      def to_ruby
        ruby =  "    host.add_node('#{@name}') do |node|\n"
        ruby << "      node.classname = '#{@classname}'\n" if @classname
        ruby << get_facet_ruby(6, 'node')
        each_prog_parameter do |param|
          ruby << "      node.add_prog_parameter('#{param}')\n"
        end
        each_env_parameter do |param|
          ruby << "      node.add_env_parameter('#{param}')\n"
        end
        each_parameter do |param|
          ruby << "      node.add_parameter('#{param}')\n"
        end
        @agent.each_component do |comp|
          ruby << comp.to_ruby(self, 6)
        end
        each_agent {|agent| ruby << agent.to_ruby}
        ruby << "    end\n"
        ruby
      end
      
    end
    
    ##
    # Holds the model of an agent that is part of an experiment.
    #
    class Agent
  
      attr_accessor :node
      attr_reader :name
      attr_accessor :name, :classname, :cloned, :uic
      
      include Multifaceted
      
      ##
      # Constructs agent
      #
      # name:: [String=nil] The name of the agent
      # yield:: [Cougaar::Agent] if block_given?
      #
      def initialize(name=nil)
        @name = name
        @classname = "org.cougaar.core.agent.SimpleAgent"
        @components = []
        yield self if block_given?
      end

      def init_block
        yield self if block_given?
      end
      
      def uri
        return @node.uri+"/$#{@name}"
      end
      
      def secure_uri
        return @node.secure_uri+"/$#{@name}"
      end
      
      ##
      # Adds components to this agent
      #
      # array:: [Array] The array of components to add
      #
      def add_components(array)
        array.each {|comp| add_component(comp)}
      end
      
      ##
      # Add a component to this agent
      #
      # component:: [Cougaar::Component | String] component or name
      # return:: [Cougaar::Component] The new component
      #
      def add_component(component=nil, &block)
        if component.kind_of? Component
          if has_component?(component)
            return nil # components must have unique names agent wide
          end
          component.agent = self
          $debug_society_model && SocietyMonitor.each_monitor { |m| m.component_added(component) }
          @components << component
          component
        else
          comp = Component.new(component, &block)
          if has_component?(comp)
            return nil # components must have unique names agent wide
          end
          comp.agent = self
          $debug_society_model && SocietyMonitor.each_monitor { |m| m.component_added(comp) }
          @components << comp
          comp
        end
      end

      ##
      # Remove a component from this agent
      #
      # component:: [String] component class name
      #
      def remove_component(classname)
        each_component do |comp|
          if classname == comp.classname
            @components.delete(comp)
            $debug_society_model && SocietyMonitor.each_monitor { |m| m.component_removed(comp) }
          end
        end
      end

      def each_component
        @components.each {|comp| yield comp}
      end
      
      def has_component?(component=nil, &block)
        if component.kind_of?(String)
          each_component do |comp|
            return true if comp.name == component
          end
          return false
        elsif component.kind_of?(Component)
          each_component do |comp|
            return true if comp == component
          end
          return false
        end
        return false unless block_given?
        each_component do |comp|
          return true if block.call(comp)
        end
        return false
      end
      
      ##
      # The host that this agent is on
      #
      # return:: [Cougaar::Host] The host of this agent's node.
      #
      def host
        @node.host
      end
      
      def remove
        @node.remove_agent(self)
      end
      
      ##
      # Clones this agent/plugins
      #
      # return:: [Cougaar::Node] The newly cloned node
      #
      def clone(node)
        agent = Agent.new(@name)
        agent.node = node
        agent.classname = @classname
        agent.cloned = @cloned
        agent.uic = @uic
        agent.add_components @components.collect {|component| component.clone(agent)}
        each_facet { |facet| agent.add_facet(facet.clone) }
        agent
      end
      
      def to_xml
        xml = "      <agent name='#{@name}'"
        xml << " class='#{@classname}'" if @classname
        xml << " uic='#{@uic}'" if @uic
        xml << ">\n"
        xml << get_facet_xml(8)
        @components.each {|comp| xml << comp.to_xml(8)}
        xml << "      </agent>\n"
        return xml
      end
      
      def to_ruby
        ruby =  "      node.add_agent('#{@name}') do |agent|\n"
        ruby << "        agent.classname='#{@classname}'\n" if @classname
        ruby << "        agent.uic='#{@uic}'\n" if @uic
        ruby << get_facet_ruby(8, 'agent')
        @components.each {|comp| ruby << comp.to_ruby(self, 8)}
        ruby << "      end\n"
        ruby
      end
      
      def move_to(nodename)
        newNode = @node.host.society.nodes[nodename]
        if nodename == @node.name
          return nil # don't move if already there
        end
        @node.agents.delete(self)
        newNode.add_agent(self)
      end
      
    end
    
    ##
    # The component holds the data representing a component in the experiment
    #
    class Component
      PLUGIN = "Node.AgentManager.Agent.PluginManager.Plugin"
      BINDER = "Node.AgentManager.Agent.PluginManager.Binder"
      
      PRIORITY_COMPONENT = "COMPONENT"
      
      attr_accessor :name, :agent, :classname, :priority, :insertionpoint, :arguments
      
      ##
      # Construct a component
      #
      # name:: [String=nil] the component classname and name
      #
      def initialize(name=nil, &block)
        @name = name
        @classname = name
        @arguments = []
        yield self if block_given?
        if @name.nil?
          @name = self.comparison_name
        end
        if @priority.nil?
          priority_component
        end
        if @insertionpoint.nil?
          insertionpoint_plugin
        end
      end
      
      def priority_component
        @priority = PRIORITY_COMPONENT
      end
      
      def insertionpoint_binder
        @insertionpoint = BINDER   
      end
      
      def insertionpoint_plugin
        @insertionpoint = PLUGIN   
      end
      
      def ==(component)
        return component.comparison_name == self.comparison_name
      end
      
      def comparison_name
        "#{@classname}(#{@arguments.join(',')})"
      end
      
      ##
      # Add and argument to this component
      #
      # argument:: [String] the argument string
      #
      def add_argument(value)
        @arguments << Argument.new(value)
      end
      
      ##
      # Iterates over each argument for this component
      #
      # yields:: [String] the argument string
      #
      def each_argument
        @arguments.each {|arg| yield arg}
      end
      
      def has_argument?(value)
        each_argument {|arg| return true if arg.value == value }
        return false
      end
      
      ##
      # Creates a new component with this component's data
      #
      # return:: [Cougaar::Component] The new component clone
      #
      def clone(agent)
        c = Component.new(@name)
        c.agent = agent
        c.classname = @classname
        c.priority = @priority
        c.insertionpoint = @insertionpoint
        each_argument {|arg| c.add_argument(arg.value)}
        return c
      end
      
      def to_xml(i)
        xml =  "#{' '*i}<component\n"
        xml << "#{' '*i}  name='#{@name}'\n"
        xml << "#{' '*i}  class='#{@classname}'\n"
        xml << "#{' '*i}  priority='#{@priority}'\n" if @priority
        xml << "#{' '*i}  insertionpoint='#{@insertionpoint}'>\n"
        each_argument do |arg|
          xml << "#{' '*i}  <argument>\n"
          xml << "#{' '*i}    #{REXML::Text.normalize(arg.value)}\n"
          xml << "#{' '*i}  </argument>\n"
        end
        xml << "#{' '*i}</component>\n"
        return xml
      end
      
      def to_ruby(parent, i)
        ruby =  "#{' '*i}#{parent.kind_of?(Node) ? 'node.agent' : 'agent'}.add_component('#{@name}') do |c|\n"
        ruby << "#{' '*i}  c.classname = '#{@classname}'\n"
        ruby << "#{' '*i}  c.priority = '#{@priority}'\n"
        ruby << "#{' '*i}  c.insertionpoint = '#{@insertionpoint}'\n"
        each_argument do |arg|
          ruby << "#{' '*i}  c.add_argument('#{arg.value}')\n"
        end
        ruby << "#{' '*i}end\n"
        ruby
      end
      
    end
    
    class Argument
      attr_accessor :value
      
      def initialize(value)
        @value = value
      end
      
      def to_s
        @value
      end
    end
    
    ##
    # The query class is a helper used by the society to provide
    # simplified acces to agents and nodes.
    #
    class Query
      
      ##
      # The query accepts the society and the block which is used
      # to fullfil the query by attributes, etc.
      #
      # society:: [Cougaar::Society] The society instance
      # block:: [Block] The block which forms the query
      #
      def initialize(society, &block)
        @society = society
        @query = block
      end
      
      ##
      # Calls the query with the supplied name:
      # query['name'] #=> value
      #
      # name:: [String] The name to pass to the block
      # return:: [Object] The query block's result
      #
      def [](name)
        @query.call(name)
      end
    end
    
  end # Model
  
end # Cougaar

