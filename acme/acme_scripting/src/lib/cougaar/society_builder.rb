require 'rexml/document'

module Cougaar
  
  class TransformationEngine
    MAXLOOP = 300
    attr_accessor :max_loop
    
    def initialize(max_loop = MAXLOOP)
      @max_loop = max_loop
      @rules = []
    end
  
    def add_rule(name, proc = nil, &block)
      @rules << TransformationRule.new(name, proc, &block)
    end
    
    def transform(builder)
      loop = true
      count = 0
      while(loop && count < @max_loop)
        loop = false
        @rules.each do |rule|
          rule.execute(builder.society)
          if rule.fired?
            rule.reset
            loop = true
          end
        end
        count += 1
        puts "loop #{count}"
      end
      @rules.each {|rule| puts "Rule '#{rule.name}' fired #{rule.fire_count} times."}
    end
  end
  
  class TransformationRule
    attr_accessor :name, :fire_count
    def initialize(name, proc=nil, &block)
      @name = name
      proc = block unless proc
      @rule = proc
      @fire_count = 0
      reset
    end
    def execute(society)
      @rule.call(self, society)
    end
    def fire
      @fire_count += 1
      @fired = true
    end
    def fired?
      @fired
    end
    def reset
      @fired = false
    end
  end
  
  class SocietyBuilder
    attr_reader :doc
    def initialize(doc)
      @doc = doc
    end
    
    def self.from_xml_file(file)
      file = File.new(file)
      SocietyBuilder.new(REXML::Document.new(file))
    end
    
    def self.from_ruby_file(file)
      SocietyBuilder.new(file)
    end
    
    def self.from_string(str)
      SocietyBuilder.new(REXML::Document.new(str))
    end
    
    def to_xml_file(filename)
      File.open(filename, "wb") {|file| file.puts(self.society.to_xml)}
    end
    
    def to_ruby_file(filename)
      File.open(filename, "wb") {|file| file.puts(self.society.to_ruby)}
    end
    
    def to_s
      self.society.to_xml
    end
    
    def to_xml
      self.society.to_xml
    end
    
    def society
      return @society if @society
      if doc.kind_of? String
        load_ruby
      else
        parse_xml
      end
      @society
    end
    
    def load_ruby
      name = "M_#{Time.now.to_i}"
      t_mod = eval <<-EOS
        module #{name}
          load '#{@doc}'
        end
        #{name}
      EOS
      @society = t_mod::SOCIETY
    end
    
    def parse_xml
      @society = Model::Society.new(doc.root.attributes['name']) do |society|
        @doc.elements.each("society/host") do |host_element|
          society.add_host(host_element.attributes['name']) do |host|
            host_element.elements.each("node") do |node_element|
              host.add_node(node_element.attributes['name']) do |node|
              
                #add parameters to node
                element = node_element.elements["prog_parameter"]
                node.prog_parameter = element.text.strip if element
                element = node_element.elements["env_parameter"]
                node.env_parameter = element.text.strip if element
                element = node_element.elements["class"]
                node.classname = element.text.strip if element
                node_element.elements.each("vm_parameter") do |element|
                  node.add_parameter(element.text.strip)
                end
                
                #add componenets to node
                node_element.elements.each("component") do |comp_element|
                  node.agent.add_component(comp_element.attributes['name']) do |comp|
                    comp.classname = comp_element.attributes['class']
                    comp.priority = comp_element.attributes['priority']
                    comp.order = comp_element.attributes['order']
                    comp.insertionpoint = comp_element.attributes['insertionpoint']
                    
                    #add arguments to component
                    comp_element.elements.each("argument") do |arg_element|
                      comp.add_argument(arg_element.text.strip, arg_element.attributes['order'].to_f)
                    end #arg_element
                  end #comp
                end #comp_element
                
                #add agents to node
                node_element.elements.each("agent") do |agent_element|
                  node.add_agent(agent_element.attributes['name']) do |agent|
                    agent.classname = agent_element.attributes['class']
                    
                    #add components to agent
                    agent_element.elements.each("component") do |comp_element|
                      agent.add_component(comp_element.attributes['name']) do |comp|
                        comp.classname = comp_element.attributes['class']
                        comp.priority = comp_element.attributes['priority']
                        comp.order = comp_element.attributes['order']
                        comp.insertionpoint = comp_element.attributes['insertionpoint']
                        
                        #add arguments to component
                        comp_element.elements.each("argument") do |arg_element|
                          comp.add_argument(arg_element.text.strip, arg_element.attributes['order'].to_f)
                        end
                      end #comp
                    end #comp_element
                  end #agent
                end #agent_element
              end #node
            end #node_element
          end #host
        end #host_element
      end #society
    end #method parse
    
  end #class SocietyBuilder
  
end #module Cougaar

module Cougaar
  module Actions
    class LoadSocietyFromScript < Cougaar::Action
      RESULTANT_STATE = "SocietyLoaded"
      def initialize(run, filename)
        super(run)
        @filename = filename
      end
      def perform
       raise_failure "Unknown Ruby file: #{@filename}" unless File.exist?(@filename)
        begin
          builder = Cougaar::SocietyBuilder.from_ruby_file(@filename)
        rescue
         raise_failure "Could not build society from Ruby file: #{@filename}", $!
        end
        @run.society = builder.society
      end
      def to_s
        return super.to_s + "('#{@filename}')"
      end
    end
    class LoadSocietyFromXML < Cougaar::Action
      RESULTANT_STATE = "SocietyLoaded"
      def initialize(run, filename)
        super(run)
        @filename = filename
      end
      def perform
       raise_failure "Unknown XML file: #{@filename}" unless File.exist?(@filename)
        begin
          builder = Cougaar::SocietyBuilder.from_xml_file(@filename)
        rescue
         raise_failure "Could not build society from XML file: #{@filename}", $!
        end
        @run.society = builder.society
      end
      def to_s
        return super.to_s + "('#{@filename}')"
      end
    end
  end
end

