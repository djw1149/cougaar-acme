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
        begin
          hosts = []
          @run.society.each_active_host { |host| hosts << host }
          hosts.each_parallel do |host|
            begin
              ms = Cougaar::MtsStats.new(@run.society)
              d = ms.getAllData()
              @run.info_message d if @debug
              File.open(@filename, File::CREAT|File::WRONLY) do |f|
                f.write(d)
              end
            rescue
              @run.error_message "Exception in CollectMtsMetrics action: #{$!}"
            end
          end
        end
      end

    end # class

    class CollectMemoryData < Cougaar::Action
      DOCUMENTATION = Cougaar.document {
        @description = "Does a ps on each node to collect the memory used by each node"
        @parameters = [
          {:directory => "default='.', Directory used to store the ps output"},
          {:debug => "default=false, Set 'true' to debug action"}
        ]
        @example = "do_action 'CollectMemoryData', 'memusage'"
      }
		  @debug = true
      def initialize(run, directory = ".", debug=false)
        super(run)
        @debug = debug
        @directory = directory
      end
      
      def perform
        begin
          `mkdir -p #{@directory}` unless File.exist?(@directory)
          hosts = []
	  @run.society.each_active_host { |host| hosts << host }
          hosts.each_parallel do |host|
            begin
              results = @run.comms.new_message(host).set_body("command[list_java_pids]").request(60)
              next if (results.nil? || results.body.nil?)
              results = results.body.split(",")
              results.each do|result|
                result = result.split('=')
                node = result[0]
                pid = result[1]
                next if pid.nil?
                out_file = File.open("#{@directory}/#{node}-procinfo", "w") 
                #output = @run.comms.new_message(host).set_body("command[rexec_user]ps -o size -o pid -C java | grep #{pid}").request(60)
                output = @run.comms.new_message(host).set_body("command[rexec_user]cat /proc/#{pid}/status | grep Vm").request(60)
                next if output.nil?
                output = output.body
                out_file.print("#{node}\n#{output}\n")
                out_file.close
                @run.archive_and_remove_file("#{@directory}/#{node}-procinfo", "Memory usage file")
              end          
            rescue
              @run.error_message "Exception in CollectMemoryData action: #{$!}"
            end
          end
        end
      end

    end #class
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
          myuri = "http://#{node.host.uri_name}:#{@society.cougaar_port}/$#{node.name}/message/#{@type}/agent/status?agent=#{agent.name}"
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
