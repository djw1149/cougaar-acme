if $0 == __FILE__
  $:.unshift ".."
  require 'cougaar/society_model'
end

require 'uri'
require 'net/http'
require 'ultralog/aggagent'
require 'cougaar/communications'

module Cougaar

class AllocationResults

    def initialize(host, agent, port=8800)
      if host.kind_of? Cougaar::Society
        society=host
        host = society.agents['AGG-Agent'].node.host.uri_name
        @uri = "#{society.agents['AGG-Agent'].uri}/AllocationResults"
      else
        host  = host
        port  = port
        agent = agent
        @uri = "http://#{host}:#{port}/$#{agent}/AllocationResults"
      end
    end

    def query
      response, url = Cougaar::Util.do_http_request(@uri);
      return response;
      rescue
        result = "<AllocationResultsException>\n"
        result += $!
        result += "\n"
        result += $!.backtrace.join("\n")
        result += "\n</AllocationResultsException>"
        return result
    end

end # class AllocationResults

end # module

if __FILE__ == $0
  puts Cougaar::AllocationResults.new('192.168.120.214', '1-501-AVNBN').query
end
