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

require 'socket'
require 'rexml/document'

module Ultralog

  module OperatorUtils
    Overlay = Struct.new(:thread, :desc, :uri)
    
    class OverlayParser
      DEFAULT = "27, 25, 31, 39, 32"
      def initialize
        @xml = `wget https://cvs.ultralog.net/dist/overlay_descriptor.xml -q --http-user=TICCVS --http-passwd=T1CCVS --output-document=-`
        @threads = {}
        parse
      end
      
      def parse
        doc = REXML::Document.new(@xml)
        doc.root.each_element do |element|
          list = @threads[element.attributes['thread']]
          unless list
            list = []
            @threads[element.attributes['thread']]=list
          end
          list << Overlay.new(element.attributes['thread'], element.attributes['desc'], element.attributes['uri'])
        end
      end
      
      def each_thread
        @threads.each_key { |key| yield key }
      end
      
      def each_overlay(thread=nil, &block)
        unless thread
          each_thread { |thread| each_overlay(thread, &block) }
        end
        @threads[thread].each { |overlay| yield overlay }
      end
      
      def stdin_query_list
        list = []
        acme = nil
        each_thread do |thread|
          puts "#{thread.upcase}"
          each_overlay(thread) do |overlay|
            puts "  #{list.size}: #{overlay.desc}"
            acme = overlay if overlay.uri == "https://ultraforge.ultralog.net/dist/isat_acme.zip"
            list << overlay
          end
        end
        puts "--------------------"
        print "Enter overlays (default: #{DEFAULT}): "
        result = gets 
        result = DEFAULT if result.strip == ""
        result = result.split.collect { |i| list[i.strip.to_i] }
        result << acme unless result.include?(acme)
        result
      end
      
    end
    
    class HostManager
      def initialize(dir = nil)
        dir = File.join(ENV['CIP'], 'operator') unless dir
        @dir = dir
        @hostname = Socket.gethostname
        @hostaddress = IPSocket.getaddress(@hostname) 
      end
      
      def get_hosts_file(host=nil)
        host = @hostname unless host
        Dir.glob(File.join(@dir, "*hosts.xml")).each do |file|
          ts = Cougaar::SocietyBuilder.from_xml_file(file).society
          return file if  ts.get_service_host("operator") && ts.get_service_host("operator").host_name==@hostname
        end
        return nil
      end
      
      def load_society(host=nil)
        host = @hostname unless host
        society = nil
        Dir.glob(File.join(@dir, "*hosts.xml")).each do |file|
          ts = Cougaar::SocietyBuilder.from_xml_file(file).society
          society = ts if  ts.get_service_host("operator") && ts.get_service_host("operator").host_name==@hostname
        end
        unless society
          raise "Could not find society for #{@hostname}...you may not be logged into the society operator host"
        end
        return society
      end
      
    end
  end
end

if __FILE__ == $0
  $:.unshift '..'
  op = Ultralog::OperatorUtils::OverlayParser.new
  overlays = op.stdin_query_list
  overlays.each do |overlay|
    puts overlay.uri
  end
end