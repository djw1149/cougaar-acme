=begin
 * <copyright>  
 *  Copyright 2001-2004 InfoEther LLC  
 *  Copyright 2001-2004 BBN Technologies
 *
 *  under sponsorship of the Defense Advanced Research Projects  
 *  Agency (DARPA).  
 *   
 *  You can redistribute this software and/or modify it under the 
 *  terms of the Cougaar Open Source License as published on the 
 *  Cougaar Open Source Website (www.cougaar.org <www.cougaar.org> ).   
 *   
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
 *  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
 *  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR 
 *  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT 
 *  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
 *  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT 
 *  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
 *  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY 
 *  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
 *  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
 *  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 * </copyright>  
=end

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
        #add facets to host
        @doc.root.elements.each("facet") do |element|
          society.add_facet do |facet|
            element.attributes.each { |a, v| facet[a] = v }
            facet.cdata = element.text.strip if element.text
          end
        end
        @doc.elements.each("society/host") do |host_element|
          society.add_host(host_element.attributes['name']) do |host|
            #add facets to host
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
                    
                    comp_element.elements.each("order") do |arg_element|
                      comp.order = arg_element.text.strip.to_i
                    end #order_element
                    
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
                        
                        comp_element.elements.each("order") do |arg_element|
                          comp.order = arg_element.text.strip.to_i
                        end #order_element
                        
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
      DOCUMENTATION = Cougaar.document {
        @description = "Load a society definition from a Ruby society file."
        @parameters = [
          :filename => "required, The Ruby file name"
        ]
        @example = "do_action 'LoadSocietyFromScript', 'full-1ad.rb'"
      }
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
        @run.archive_file(@filename, "Initial society file")
				@run["loader"] = "XML"
      end
      def to_s
        return super.to_s + "('#{@filename}')"
      end
    end
    
    class SaveCurrentSociety < Cougaar::Action
      PRIOR_STATES = ["SocietyLoaded"]
      DOCUMENTATION = Cougaar.document {
        @description = "Save the current (in memory) society to XML/Ruby."
        @parameters = [
          :filename => "required, The XML/Ruby file name."
        ]
        @example = "do_action 'SaveCurrentSociety', 'full-1ad.xml'"
      }
      def initialize(run, filename)
        super(run)
        @filename = filename
      end

      def to_s
        return super.to_s+"('#{@filename}')"
      end
      
      def perform
        begin
          File.open(@filename, "w") do |file|
            if (File.basename(@filename)!=File.basename(@filename, ".xml"))
              file.puts @run.society.to_xml
            else
              file.puts @run.society.to_ruby
            end
          end
          @run.archive_and_remove_file(@filename, "Saved instance of society in memory")
        rescue
          @run.error_message "Could not write society to #{@filename}"
        end
      end
    end
    
    class LoadSocietyFromXML < Cougaar::Action
      RESULTANT_STATE = "SocietyLoaded"
      DOCUMENTATION = Cougaar.document {
        @description = "Load a society definition from an XML."
        @parameters = [
          :filename => "required, The XML file name"
        ]
        @example = "do_action 'LoadSocietyFromXML', 'full-1ad.xml'"
      }
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
        @run.archive_file(@filename, "Initial society file")
				@run["loader"] = "XML"
      end
      def to_s
        return super.to_s + "('#{@filename}')"
      end
    end
    
    class LoadSocietyFromMemory < Cougaar::Action
      RESULTANT_STATE = "SocietyLoaded"
      DOCUMENTATION = Cougaar.document {
        @description = "Load a society stored in Cougaar.in_memory_society."
        @example = "do_action 'LoadSocietyFromMember'"
      }
      
      def initialize(run)
        super(run)
      end
      
      def perform
        raise_failure "In memory society not set" unless Cougaar.in_memory_society
        @run.society = Cougaar.in_memory_society
        @run["loader"] = "XML"
      end
    end
  end
end

