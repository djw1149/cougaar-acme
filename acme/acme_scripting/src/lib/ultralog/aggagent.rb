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
require 'cougaar/communications'

module UltraLog
  module AggAgent
  
    class Client
      attr_reader :agg_url, :keepalive_url
      
      def initialize(cluster_url, agg_name="aggregator", keepalive_name="aggregatorkeepalive")
        @cluster_url = cluster_url
        @agg_name = agg_name
        @keepalive_name= keepalive_name
        @agg_url = @cluster_url+"/"+@agg_name+"?THICK_CLIENT=1"
        @keepalive_url = @cluster_url + "/" + keepalive_name+"?KEEP_ALIVE=1"
        response, uri = Cougaar::Communications::HTTP.get(@agg_url+"&CHECK_URL=1")
        raise "Could not connect to #{@agg_url}" unless response
      end
      
      def submit_query(query=nil)
        raise "Must supply a query parameter or a block" if query.nil? and !block_given?
        tagged_url = @agg_url+"&CREATE_QUERY=1"
        unless query
          query = Query.new
          yield query
        end
        
        if query.type==Query::TYPE_PERSISTENT
          response = Cougaar::Communications::HTTP.put(tagged_url, query.to_s)
        else
          response = Cougaar::Communications::HTTP.put(tagged_url, query.to_s) #AggregationResultSet.new(Cougaar::Communications::HTTP.put(tagged_url, query.to_s, :as_xml))
        end
        return response
      end
      
      
    end
    
    class Monitor
    end
    
    class AlertMonitor
    end
    
    class ResultSetMonitor
    end
=begin    
    class AggregationResultSet
      attr_reader :cluster_table, :exception_map, 
                  :responding_cluster, :id_names, :listeners
      
      def initialize(xml)
        @cluster_table = {}
        @exception_map = {}
        @responding_clusters = []
        @id_names = []
        @listeners = []
        xml.each("resultset_exception") do |element|
          cluster_id = element.attributes['clusterId']
          desc = element.get_text
          exception_map[cluster_id]=desc
        end
        
        xml.each("cluster") do |element|
          cluster_id = element.attributes['id']
          element.each("data_atom") do |atom_element|
            atom = ResultSetDataAtom.from_xml(atom_element)
            @id_names.concat(atom.id_set) if @id_names.size==0
            map = @cluster_table[cluster_id]
            unless map
              map = {}
              @cluster_table[cluster_id]=map
            end
          end
        end
      end
      
      class ResultSetDataAtom
        attr_reader :id_set, :identifiers, :values
        def initialize
          @id_set = []
          @identifiers = {}
          @values = {}
        end
        def ResultSetDataAtom.from_xml(element)
          atom = ResultSetDataAtom.new
          atom.each("id") do |element|
            name = element.attributes['name']
            value = element.attributes['value']
            atom.id_set << name
            atom.identifiers[name]=value
          end
          atom.each("value") do |element|
            name = element.attributes['name']
            value = element.attributes['value']
            atom.values[name]=value
          end
          return atom
        end
      end
    end
=end    
    
    
    class Query
      attr_reader :source_clusters, :type, :update_method
      attr_accessor :name, :pull_rate, :timeout
      attr_accessor :predicate_spec, :format_spec, :agg_spec
      
      TYPE_TRANSIENT = "Transient"
      TYPE_PERSISTENT = "Persistent"
      TYPE_LIST = [TYPE_TRANSIENT, TYPE_PERSISTENT]
      
      UPDATE_PUSH = "Push"
      UPDATE_PULL = "Pull"
      UPDATE_LIST = [UPDATE_PUSH, UPDATE_PULL]
      
      def initialize(type=TYPE_TRANSIENT)
        @type = type
        @source_clusters = []
        yield self if block_given?
        @update_method ||= UPDATE_PUSH
        @pull_rate ||= -1
        @timeout ||= 0
      end
      
      def type=(type)
        unless TYPE_LIST.include? type
          raise "Unknown type, must be: #{TYPE_LIST.join(' or ')}" 
        else
          @type = type
        end
      end
      
      def update_method=(update_method)
        unless UPDATE_LIST.include? update_method
          raise "Unknown update_method, must be: #{UPDATE_LIST.join(' or ')}" 
        else
          @update_method = update_method
        end
      end
      
      def to_xml
        xml = %Q[<query type="#{@type}" update_method="#{@update_method}" pull_rate="#{@pull_rate}" name="#{@name}">]
        source_clusters.each {|cluster| xml = xml + "<source_cluster>#{cluster}</source_cluster>"}
        xml << "<timeout>#{@timeout}</timeout>" unless @timeout==0
        xml << @predicate_spec.to_xml
        xml << @format_spec.to_xml
        xml << @agg_spec.to_xml if @agg_spec
        xml << "</query>"
        return xml
      end
      
      def to_s
        to_xml
      end
    end
    
    class ScriptSpec
      attr_reader :language, :script_type, :format, :parameters, :agg_ids, :agg_type
      attr_accessor :text
      
      LANG_JAVA = "Java"
      LANG_SILK = "SILK"
      LANG_JYTHON = "JPython"
      LANG_LIST = [LANG_JAVA, LANG_SILK, LANG_JYTHON]
      
      TYPE_UNARY_PREDICATE = "unary_predicate"
      TYPE_INCREMENT_FORMAT = "xml_encoder"
      TYPE_AGGREGATOR = "aggregator"
      TYPE_ALERT = "alert_script"
      TYPE_LIST = [TYPE_UNARY_PREDICATE, TYPE_INCREMENT_FORMAT, TYPE_AGGREGATOR, TYPE_ALERT]
      
      FORMAT_INCREMENT = "Increment"
      FORMAT_XMLENCODER = "XMLEncoder"
      FORMAT_LIST = [FORMAT_INCREMENT, FORMAT_XMLENCODER]
      
      AGGTYPE_AGGREGATOR = "Aggregator"
      AGGTYPE_MELDER = "Melder"
      AGGTYPE_LIST = [AGGTYPE_AGGREGATOR, AGGTYPE_MELDER]
      
      # Format Factory
      def ScriptSpec.new_format_spec
        spec = ScriptSpec.new do |spec| 
          spec.format = ScriptSpec::FORMAT_XMLENCODER
          spec.script_type = ScriptSpec::TYPE_INCREMENT_FORMAT
        end
        yield spec if block_given?
        spec
      end
      
      # Predicate Factory
      def ScriptSpec.new_predicate_spec
        spec = ScriptSpec.new do |spec| 
          spec.script_type = ScriptSpec::TYPE_UNARY_PREDICATE
        end
        yield spec if block_given?
        spec
      end
      
      # Agg Spec Factory
      def ScriptSpec.new_agg_spec
        spec = ScriptSpec.new do |spec| 
          spec.script_type = ScriptSpec::TYPE_AGGREGATOR
        end
        yield spec if block_given?
        spec
      end
      
      def initialize
        @parameters = {}
        @agg_ids = []
        yield self if block_given?
        @language ||= LANG_JAVA
        if @format
          @script_type ||= TYPE_INCREMENT_FORMAT
        end
        if @aggtype
          @script_type ||= TYPE_AGGREGATOR
        end
      end
      
      def language=(language)
        unless LANG_LIST.include? language
          raise "Unknown language, must be: #{LANG_LIST.join(' or ')}" 
        else
          @language = language
        end
      end
      
      def script_type=(script_type)
        unless TYPE_LIST.include? script_type
          raise "Unknown script_type, must be: #{TYPE_LIST.join(' or ')}"
        else
          @script_type = script_type
        end
      end
      
      def format=(format)
        unless FORMAT_LIST.include? format
          raise "Unknown format, must be: #{FORMAT_LIST.join(' or ')}"
        else
          @format = format
        end
      end
      
      def agg_type=(agg_type)
        unless AGGTYPE_LIST.include? agg_type
          raise "Unknown agg_type, must be: #{AGGTYPE_LIST.join(' or ')}"
        else
          @agg_type = agg_type
        end
      end
      
      def classname=(classname)
        @text = classname
      end
      
      def encode(string)
        return "" unless string
        string = string.gsub(/\&/, "&amp;")
        string = string.gsub(/\</, "&lt;")
        string = string.gsub(/\>/, "&gt;")
        string = string.gsub(/\'/, "&apos;")
        string = string.gsub(/\"/, "&quot;")
        return string
      end
      
      def to_xml
        type = (@format ? (' type="'+@format+'"') : nil)
        type ||= (@agg_type ? (' type="'+@agg_type+'"') : "")
        ids = (@agg_ids.size > 0 ? (' aggIds="'+@agg_ids.join(" ")+'"') : "")
        xml = %Q[<#{@script_type} language="#{@language}"#{type}#{ids}>]
        if @language == LANG_JAVA
          xml << "<class>#{@text}</class>"
          parameters.each { |key, value| xml = xml + '<param name="'+key+'">'+encode(value.to_s)+"</param>"}
        else
          xml = xml + encode(@text)
        end
        xml = xml + "</#{@script_type}>"
      end
      
    end
  end
end

