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

  module Model
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
      attr_accessor :cougaar_port
      
      ##
      # Constructs a Society with an optional name block
      #
      def initialize(name=nil, &block)
        @name = name
        @cougaar_port = DEFAULT_COUGAAR_PORT
        @hostList = {}
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
          @hostList[host.host_name] = host
          host.society = self
          return host
        else
          @hostList[host] = Host.new(host, &block)
          @hostList[host].society = self
          return @hostList[host]
        end
      end
      
      ##
      # Iterates over each host
      #
      # yield:: [Cougaar::Host] The host instance
      #
      def each_host
        @hostList.each_value {|host| yield host}
      end
      
      ##
      # Iterates over each (active) host, or host that has
      # nodes on it.
      #
      # yield:: [Cougaar::Host] The host instance
      #
      def each_active_host
        @hostList.each_value {|host| yield host if host.nodes.size > 0}
      end
      
      ##
      # Iterates over each agent (across all nodes and hosts)
      #
      # yield:: [Cougaar::Agent] Teh agent instance
      #
      def each_agent
        @hostList.each_value {|host| host.each_node {|node| node.each_agent {|agent| yield agent}}}
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
              "  xsi:noNamespaceSchemaLocation='society.xsd'>\n"
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
        @hostList.each_value do |host|
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
    # Mixin module for components that have attributes
    #
    module Attributed
    
      ##
      # Add an attribute(s) to the component
      # 
      # attribute:: [String|Array] The attribute(s) to add
      #
      def add_attribute(attribute)
        @attributes ||= []
        if attribute.kind_of? Array
          @attributes.concat attribute
        else
          @attributes << attribute
        end
      end
      
      ##
      # Iterates over each component
      #
      # yield:: [String] The attribute
      #
      def each_attribute
        return unless @attributes
        @attributes.each {|attribute| yield attribute}
      end
      
      ##
      # Returns the XML encoding of the components attributes
      #
      # indent:: [Integer] The number of spaces to indent
      # return:: [String] The XML encoding of the attributes
      #
      def get_attribute_xml(indent)
        xml = ""
        each_attribute do |attribute|
          xml << "#{' ' * indent}<attribute>#{attribute}</attribute>\n"
        end
        return xml
      end
      
      ##
      # Returns the Ruby encoding of the components attributes
      #
      # indent:: [Integer] The number of spaces to indent
      # context:: [String] The component context (name) e.g. host, node, agent
      # return:: [String] The Ruby encoding of the attributes
      #
      def get_attribute_ruby(indent, context)
        ruby = ""
        each_attribute do |attribute|
          ruby << "#{' ' * indent}#{context}.add_attribute('#{attribute}')\n"
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
      
      include Attributed
      
      ##
      # Constructs a host with the optional name
      #
      # name:: [String=nil] The name of this host
      #
      def initialize(name=nil)
        @name = name
        @nodes = {}
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
          @nodes[node.name] = node
          node.host = self
          return node
        else
          @nodes[node] = Node.new(node, &block)
          @nodes[node].host = self
          return @nodes[node]
        end
      end
      
      ##
      # Iterates over each node on this host
      #
      # yield:: [Cougaar::Node] The node instance
      #
      def each_node
        @nodes.each_value {|node| yield node}
      end
      
      ##
      # Clones this host/nodes/agents/plugins
      #
      # return:: [Cougaar::Host] The newly cloned host
      #
      def clone
        host = Host.new(@name)
        each_node { |node| host.add_node(node.clone) }
        each_attribute { |attribute| host.add_attribute(attribute) }
        host
      end
      
      def to_xml
        xml = "  <host name='#{@name}'>\n"
        xml << get_attribute_xml(4)
        each_node {|node| xml << node.to_xml}
        xml << "  </host>\n"
        return xml
      end
      
      def to_ruby
        ruby =  "  society.add_host('#{@name}') do |host|\n"
        ruby << get_attribute_ruby(4, 'host')
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
    # Parameters are stored in the #paramters attribute
    #
    class Node
      attr_reader :agents, :name, :parameters
      attr_accessor :host, :agent, :prog_parameters, :env_parameters, :classname
      
      include Attributed
      
      ##
      # Constructs a node with optional name
      # 
      # name:: [String=nil] The name of the node
      #
      def initialize(name=nil)
        @name = name
        @agent = Agent.new(@name)
        @agents = {}
        @env_parameters = []
        @prog_parameters = []
        @parameters = []
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
          @agents[agent.name] = agent
          agent.node = self
          agent
        else
          @agents[agent] = Agent.new(agent, &block)
          @agents[agent].node = self
          @agents[agent]
        end
      end
      
      ##
      # Iterates over each agent in this node
      #
      # yield:: [Cougaar::Agent] Agent instance
      #
      def each_agent
        @agents.each_value {|agent| yield agent}
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
        @parameters.each {|param| yield param}
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
      
      ##
      # Clones this node(parameters)/agents/plugins
      #
      # return:: [Cougaar::Node] The newly cloned node
      #
      def clone
        node = Node.new(@name)
        each_agent {|agent| node.add_agent agent.clone}
        each_attribute { |attribute| node.add_attribute(attribute) }
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
        xml << get_attribute_xml(6)
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
        ruby << get_attribute_ruby(6, 'node')
        each_host_parameter do |param|
          ruby << "      node.add_host_parameter('#{param}')\n"
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
      
      include Attributed
      
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
      def add_component(component, &block)
        if component.kind_of? Component
          @components << component
        else
          comp = Component.new(component, &block)
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
          @components.delete(comp) if classname == comp.classname
        end
      end

      def each_component
        @components.each {|comp| yield comp}
      end
      
      ##
      # The host that this agent is on
      #
      # return:: [Cougaar::Host] The host of this agent's node.
      #
      def host
        @node.host
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
        each_attribute { |attribute| agent.add_attribute(attribute) }
        agent
      end
      
      def to_xml
        xml = "      <agent name='#{@name}' class='#{classname}'>\n"
        xml << get_attribute_xml(8)
        @components.each {|comp| xml << comp.to_xml(8)}
        xml << "      </agent>\n"
        return xml
      end
      
      def to_ruby
        ruby =  "      node.add_agent('#{@name}') do |agent|\n"
        ruby << get_attribute_ruby(8, 'agent')
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
      attr_accessor :name, :classname, :priority, :insertionpoint, :arguments
      attr_reader :order
      
      ##
      # Construct a component
      #
      # name:: [String] the component name
      #
      def initialize(name, &block)
        @name = name
        @arguments = []
        yield self if block_given?
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
