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

$debug_society_model = false

module Cougaar

  module Model
  
    class SocietyMonitor
      
      @@monitors = []
      def self.add(monitor)
        @@monitors << monitor
      end
      
      def self.each_monitor
        @@monitors.each {|monitor| yield monitor}
      end
    
      def initialize
        SocietyMonitor.add(self)
      end
      
      def host_added(host) ; end
      def host_removed(host) ; end
      
      def node_added(node) ; end
      def node_removed(node) ; end
      
      def agent_added(agent) ; end
      def agent_removed(agent) ; end
      
      def component_added(component) ; end
      def component_removed(component) ; end
      
      def self.enable_stdout
        m = SocietyMonitor.new
        def m.host_added(host)
          puts "Host added        #{host.host_name} < #{host.society.name}"
        end
        def m.host_removed(host)
          puts "Host removed      #{host.host_name} < #{host.society.name}"
        end
        def m.node_added(node)
          puts "Node added        #{node.name} < #{node.host.host_name} < #{node.host.society.name}"
        end
        def m.node_removed(node)
          puts "Node removed      #{node.name} < #{node.host.host_name} < #{node.host.society.name}"
        end
        def m.agent_added(agent)
          puts "Agent added       #{agent.name} < #{agent.node.name} < #{agent.node.host.host_name} < #{agent.node.host.society.name}"
        end
        def m.agent_removed(agent)
          puts "Agent removed     #{agent.name} < #{agnet.node.name} on #{agent.node.host.host_name} < #{agent.node.host.society.name}"
        end
        def m.component_added(component)
          puts "Component added   #{component.name} < #{component.agent.name} < #{component.agent.node.name} < #{component.agent.node.host.host_name} < #{component.agent.node.host.society.name}"
        end
        def m.agent_removed(agent)
          puts "Component removed #{component.name} < #{component.agent.name} < #{component.agent.node.name} < #{component.agent.node.host.host_name} < #{component.agent.node.host.society.name}"
        end
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
          @hostIndex[host.host_name] = host
          @hostList << host
          host.society = self
          $debug_society_model && SocietyMonitor.each_monitor { |m| m.host_added(host) }
          return host
        else
          newHost = Host.new(host)
          @hostIndex[host] = newHost
          newHost.society = self
          @hostList << newHost
          $debug_society_model && SocietyMonitor.each_monitor { |m| m.host_added(newHost) }
          newHost.init_block(&block)
          return newHost
        end
      end
      
      def remove_host(host)
        @host_index.delete(host.host_name)
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
      # yield:: [Cougaar::Host] The host instance
      #
      def each_active_host
        @hostList.each {|host| yield host if host.nodes.size > 0}
      end
      
      ##
      # Iterates over each agent (across all nodes and hosts)
      #
      # yield:: [Cougaar::Agent] Teh agent instance
      #
      def each_agent
        @hostList.each {|host| host.each_node {|node| node.each_agent {|agent| yield agent}}}
      end
      
      ##
      # Clones this society/hosts/nodes/agents/plugins
      #
      # return:: [Cougaar::Society] The newly cloned society
      #
      def clone
        society = Society.new(@name)
        each_host {|host| society.add_host host.clone}
        society
      end
      
      def to_xml
        xml = "<?xml version='1.0'?>\n" +
              "<society name='#{@name}'\n" +
              "  xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'\n" + 
              "  xsi:noNamespaceSchemaLocation='http://www.cougaar.org/2003/society.xsd'>\n"
        each_host {|host| xml << host.to_xml}
        xml << "</society>"
        return xml
      end
      
      def to_ruby
        ruby =  "SOCIETY = Cougaar::Model::Society.new('#{@name}') do |society|\n"
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
              @map << {:cdata => data}
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
            xml << "#{key}='#{value}' " if key != :cdata
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
          return self
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
        a = Facet.new(facet_data, &block)
        @facets << a
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
      # Returns the first facet that contains the specified key name
      #
      # name:: [String | Symbol] The facet key
      # return:: [String] The facet key's value
      #
      def get_facet(name)
        return nil unless @facets
        each_facet(name) { | facet | return facet[name] }
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
      
      ##
      # Adds a node to this host
      #
      # node:: [Cougaar::Node | String] the Node or name of the node
      # block:: [Block] the optional block to pass to the node constructor
      # return:: [Cougaar::Node] The new node
      #
      def add_node(node, &block)
        if node.kind_of? Node
          @nodeIndex[node.name] = node
          @nodes << node
          node.host = self
          $debug_society_model && SocietyMonitor.each_monitor { |m| m.node_added(node) }
          return node
        else
          newNode = Node.new(node)
          @nodeIndex[node] = newNode
          newNode.host = self
          @nodes << newNode
          $debug_society_model && SocietyMonitor.each_monitor { |m| m.node_added(newNode) }
          newNode.init_block(&block)
          return newNode
        end
      end
      
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
      
      def remove
        @society.remove_host(self)
      end
      
      ##
      # Clones this host/nodes/agents/plugins
      #
      # return:: [Cougaar::Host] The newly cloned host
      #
      def clone
        host = Host.new(@name)
        each_node { |node| host.add_node(node.clone) }
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
        @name = name
        @agent = Agent.new(@name)
        @agents = []
        @agentIndex = {}
        @env_parameters = []
        @prog_parameters = []
        @parameters = []
        yield self if block_given?
      end

      def init_block
        yield self if block_given?
      end
      
      ##
      # Add an agent to this node
      #
      # agent:: [Cougaar::Agent | String] Name or agent instance
      # block:: [Block] Optional constructor block
      # return:: [Cougaar::Agent] Agent instance
      #
      def add_agent(agent, &block)
        if agent.kind_of? Agent
          @agentIndex[agent.name] = agent
          @agents << agent
          agent.node = self
          $debug_society_model && SocietyMonitor.each_monitor { |m| m.agent_added(newAgent) }
          agent
        else
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
      
      ##
      # Iterates over each agent in this node
      #
      # yield:: [Cougaar::Agent] Agent instance
      #
      def each_agent
        @agents.each {|agent| yield agent}
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
      end

      # Remove a parameter specifically on this node
      #
      # param:: [String] the -D param to remove
      #
      def remove_parameter(param)
        o = nil
        @parameters.each do |orig|
          o = orig if orig[0..(param.size)]=="#{param}="
        end
        @parameters.delete(o) if o
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
      def clone
        node = Node.new(@name)
        each_agent {|agent| node.add_agent agent.clone}
        each_facet { |facet| node.add_facet(facet.clone) }
        node.parameters.concat @parameters
        node.env_parameters.concat @env_parameters
        node.prog_parameters.concat @prog_parameters
        node.classname = @classname
        node.agent = @agent.clone
        node
      end
      
      def to_xml
        xml = "    <node name='#{@name}'>\n"
        xml << "      <class>\n        #{@classname}\n      </class>\n"
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
        each_agent {|agent| xml << agent.to_xml}
        @agent.each_component do |comp|
          xml << comp.to_xml(6)
        end
        xml << "    </node>\n"
        return xml
      end
      
      def to_ruby
        ruby =  "    host.add_node('#{@name}') do |node|\n"
        ruby << "      node.classname = '#{@classname}'\n"
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
        each_agent {|agent| ruby << agent.to_ruby}
        @agent.each_component do |comp|
          ruby << comp.to_ruby(self, 6)
        end
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
        @components = []
        yield self if block_given?
      end

      def init_block
        yield self if block_given?
      end
      
      ##
      # Adds components to this agent
      #
      # array:: [Array] The array of components to add
      #
      def add_components(array)
        @components = @components.concat array
      end
      
      ##
      # Add a component to this agent
      #
      # component:: [Cougaar::Component | String] component or name
      # return:: [Cougaar::Component] The new component
      #
      def add_component(component=nil, &block)
        if component.kind_of? Component
          component.agent = self
          $debug_society_model && SocietyMonitor.each_monitor { |m| m.component_added(component) }
          @components << component
        else
          comp = Component.new(component, &block)
          comp.agent = self
          $debug_society_model && SocietyMonitor.each_monitor { |m| m.component_added(comp) }
          @components << comp
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
      
      def has_component?(&block)
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
      def clone
        agent = Agent.new(@name)
        agent.classname = @classname
        agent.cloned = @cloned
        agent.uic = @uic
        agent.add_components @components.collect {|component| component.clone}
        each_facet { |facet| agent.add_facet(facet.clone) }
        agent
      end
      
      def to_xml
        xml = "      <agent name='#{@name}' class='#{classname}'>\n"
        xml << get_facet_xml(8)
        @components.each {|comp| xml << comp.to_xml(8)}
        xml << "      </agent>\n"
        return xml
      end
      
      def to_ruby
        ruby =  "      node.add_agent('#{@name}') do |agent|\n"
        ruby << get_facet_ruby(8, 'agent')
        @components.each {|comp| ruby << comp.to_ruby(self, 8)}
        ruby << "      end\n"
        ruby
      end
      
      def move_to(nodename)
        newNode = @node.host.society.nodes[nodename]
        @node.agents.delete(@name)
        newNode.add_agent(self)
      end
      
    end
    
    ##
    # The component holds the data representing a component in the experiment
    #
    class Component
      PLUGIN = "Node.AgentManager.Agent.PluginManager.Plugin"
      BINDER = "Node.AgentManager.Agent.PluginManager.Binder"
      
      attr_accessor :name, :agent, :classname, :priority, :insertionpoint, :arguments
      attr_reader :order
      
      ##
      # Construct a component
      #
      # name:: [String=nil] the component name
      #
      def initialize(name=nil, &block)
        @name = name
        @arguments = []
        yield self if block_given?
        if @name.nil?
          @name = @classname + "(" + @arguments.join(",") + ")"
        end
        if @insertionpoint.nil?
          insertionpoint_plugin
        end
      end
      
      def insertionpoint_binder
        @insertionpoint = BINDER   
      end
      
      def insertionpoint_plugin
        @insertionpoint = PLUGIN   
      end
        
      
      ##
      # Add and argument to this component
      #
      # argument:: [String] the argument string
      #
      def add_argument(value, order=nil)
        unless order
          order = 0
          @arguments.each do |arg|
            order = arg.order if arg.order > order
          end
          order = (order + 1).to_f
        end
        @arguments << Argument.new(value, order)
      end
      
      def order=(value)
        begin
          @order = value.to_f if value
        rescue
        end
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
      
      def <=>(other)
        return @order <=> other.order
      end
      
      ##
      # Creates a new component with this component's data
      #
      # return:: [Cougaar::Component] The new component clone
      #
      def clone
        c = Component.new(@name)
        c.classname = @classname
        c.priority = @priority
        c.order = @order
        c.insertionpoint = @insertionpoint
        each_argument {|arg| c.add_argument(arg.value, arg.order)}
        return c
      end
      
      def to_xml(i)
        xml =  "#{' '*i}<component name='#{@name}'\n"
        xml << "#{' '*i}  class='#{@classname}'\n"
        xml << "#{' '*i}  priority='#{@priority}'\n"
        xml << "#{' '*i}  order='#{@order}'\n"
        xml << "#{' '*i}  insertionpoint='#{@insertionpoint}'>\n"
        each_argument do |arg|
          xml << "#{' '*i}  <argument order='#{arg.order}'>\n"
          xml << "#{' '*i}    #{arg.value}\n"
          xml << "#{' '*i}  </argument>\n"
        end
        xml << "#{' '*i}</component>\n"
        return xml
      end
      
      def to_ruby(parent, i)
        ruby =  "#{' '*i}#{parent.kind_of?(Node) ? 'node.agent' : 'agent'}.add_component('#{@name}') do |c|\n"
        ruby << "#{' '*i}  c.classname = '#{@classname}'\n"
        ruby << "#{' '*i}  c.priority = '#{@priority}'\n"
        ruby << "#{' '*i}  c.order = #{@order}\n"
        ruby << "#{' '*i}  c.insertionpoint = '#{@insertionpoint}'\n"
        each_argument do |arg|
          ruby << "#{' '*i}  c.add_argument('#{arg.value}', #{arg.order})\n"
        end
        ruby << "#{' '*i}end\n"
        ruby
      end
      
    end
    
    class Argument
      attr_accessor :value
      attr_reader :order
      
      def initialize(value, order)
        @value = value
        self.order = order
      end
      
      def order=(value)
        begin
          @order = value.to_f if value
        rescue
        end
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

