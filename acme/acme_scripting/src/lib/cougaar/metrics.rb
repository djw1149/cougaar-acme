##
#  <copyright>
#  Copyright 2003 BBN Technologies
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

$:.unshift ".." if $0 == __FILE__

require 'cgi'

require 'cougaar/scripting'

module Cougaar
  module Actions

    class CollectMtsMetrics < Cougaar::Action
      DOCUMENTATION = Cougaar.document {
        @description = "Collects message transport service metrics and stores them in a file."
        @parameters = [
          {:filename => "default='mts.csv', File name used to hold metrics data."},
          {:type => "default='remote', The type of metrics ('remote' or 'local')"},
          {:debug => "default=false, Set 'true' to debug action"}
        ]
        @example = "do_action 'CollectMtsMetrics', 'mymts.csv'"
      }
		  @debug = true
      def initialize(run, filename="mts.csv", type="remote", debug=false)
        super(run)
        @debug = debug
        @filename = filename
        @type = type
      end
      
      def perform
        @run.society.each_active_host do |host|
          ms = Cougaar::MtsStats.new(@run.society)
          d = ms.getAllData()
          puts d if @debug
          File.open(@filename, File::CREAT|File::WRONLY) do |f|
            f.write(d)
          end
        end
      end

    end # class
  end  # module Actions
end # module Cougaar
    

  
module Cougaar
  class MtsStats
    @@fields = ["Status", "Queue Length", "Messages Received", "Bytes Received", "Last Received Bytes",
                "Messages Sent", "Messages Delivered", "Bytes Delivered", "Last Delivered Bytes", 
                "Last Delivered Latency", "Average Delivered Latency", "Unregistered Name Error Count",
                "Communication Failure Count", "Misdelivered Message Count", "Last Link Protocol Tried",
                "Last Link Protocol Success"]

    def initialize(society, type="remote")
      @society = society
      @regexes = {}
      @type = type
      @@fields.each do |field| 
        @regexes[field] = Regexp.new("<b>#{field}<\/b><\/td><td><b>(.*?)<\/b>")
      end
    end

    def getAllData()
      output = "Agent,"
      output << @@fields.join(",")
      @society.each_node do |node| 
        node.each_agent do |agent|
          myuri = "http://#{node.host.name}:8800/$#{node.name}/message/#{@type}/agent/status?agent=#{agent.name}"
          data, uri = Cougaar::Communications::HTTP.get(myuri)
          output << "\n#{agent.name},"
          @@fields.each do |field|
            regex = @regexes[field]
            match = regex.match(data)
            value = "??"
            value = match[1] if match
            output << "#{value},"
          end
        end
      end
      output
    end
  end
end



if $0==__FILE__

  file = ARGV[0]
  builder = Cougaar::SocietyBuilder.from_xml_file(file)
  soc = builder.society

  ms = Cougaar::MtsStats.new(soc)
  d = ms.getAllData()
  puts d

  ms = UltraLog::MtsStats.new(soc, "local")
  d = ms.getAllData()
  puts d
end
