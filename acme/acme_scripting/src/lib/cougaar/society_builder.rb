require 'rexml/document'
require 'cougaar/experiment'
require 'cougaar/society_model'

module Cougaar
  
  class SocietyBuilder
    attr_reader :doc
    attr_accessor :filename
    def initialize(doc)
      @doc = doc
    end
    
    def self.from_xml_file(filename)
      file = File.new(filename)
      builder = SocietyBuilder.new(REXML::Document.new(file))
      builder.filename = filename
      file.close()
      builder
    end
    
    def self.from_ruby_file(filename)
      builder = SocietyBuilder.new(filename)
      builder.filename = filename
      builder
    end
    
    def self.from_string(str)
      SocietyBuilder.new(REXML::Document.new(str))
    end
    
    def to_xml_file(filename=nil)
      filename = @filename if filename.nil?
      File.open(filename, "wb") {|file| file.puts(self.society.to_xml)}
    end
    
    def to_ruby_file(filename=nil)
      filename = @filename if filename.nil?
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
      f = File.new(@doc)
      @society = eval f.read
      f.close()
    end
    
    def parse_xml
      @society = Model::Society.new(doc.root.attributes['name']) do |society|
        @doc.elements.each("society/host") do |host_element|
          society.add_host(host_element.attributes['name']) do |host|
            #add attributes to host
            host_element.elements.each("facet") do |element|
              host.add_facet do |facet|
                element.attributes.each { |a, v| facet[a] = v }
                facet.cdata = element.text.strip if element.text
              end
            end
            host_element.elements.each("node") do |node_element|
              host.add_node(node_element.attributes['name']) do |node|
                element = node_element.elements["class"]
                node.classname = element.text.strip if element
                #add attributes to node
                node_element.elements.each("facet") do |element|
                  node.add_facet do |facet|
                    element.attributes.each { |a, v| facet[a] = v }
                    facet.cdata = element.text.strip if element.text
                  end
                end
                #add parameters to node
                node_element.elements.each("vm_parameter") do |element|
                  node.add_parameter(element.text.strip)
                end
                node_element.elements.each("env_parameter") do |element|
                  node.add_env_parameter(element.text.strip)
                end
                node_element.elements.each("prog_parameter") do |element|
                  node.add_prog_parameter(element.text.strip)
                end
                
                #add componenets to node
                node_element.elements.each("component") do |comp_element|
                  node.agent.add_component(comp_element.attributes['name']) do |comp|
                    comp.classname = comp_element.attributes['class']
                    comp.priority = comp_element.attributes['priority']
                    comp.insertionpoint = comp_element.attributes['insertionpoint']
                    
                    #add arguments to component
                    comp_element.elements.each("argument") do |arg_element|
                      comp.add_argument(arg_element.text.strip)
                    end #arg_element
                  end #comp
                end #comp_element
                
                #add agents to node
                node_element.elements.each("agent") do |agent_element|
                  node.add_agent(agent_element.attributes['name']) do |agent|
                    agent.classname = agent_element.attributes['class']
                    #add attributes to agent
                    agent_element.elements.each("facet") do |element|
                      agent.add_facet do |facet|
                        element.attributes.each { |a, v| facet[a] = v }
                        facet.cdata = element.text.strip if element.text
                      end
                    end
                    
                    #add components to agent
                    agent_element.elements.each("component") do |comp_element|
                      agent.add_component(comp_element.attributes['name']) do |comp|
                        comp.classname = comp_element.attributes['class']
                        comp.priority = comp_element.attributes['priority']
                        comp.insertionpoint = comp_element.attributes['insertionpoint']
                        
                        #add arguments to component
                        comp_element.elements.each("argument") do |arg_element|
                          comp.add_argument(arg_element.text.strip)
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
				@run["loader"] = "XML"
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
				@run["loader"] = "XML"
      end
      def to_s
        return super.to_s + "('#{@filename}')"
      end
    end
  end
end

