require 'parsedate'

class AggAgentParser
  # States
  BEFORE_AGGS = 0
  START_AGGS = 1
  IN_AGGS = 2

  LINE_RE = /\[.*\](.*)::(.*)/
  SEND_RE = /Sending (\S*) Query to (\S*)/

  def initialize( log ) 
    @log = log
    @queries = []
    @sources = []
    @times = {}

    parse
  end

  # get_queries returns an array of queries which were parsed.
  def get_queries
    @queries
  end

  # get_sources returns an array of sources available for each query.
  def get_sources
    @sources
  end

  # get_time returns the time taken for a query from a specific host.
  def get_time( query, source )
    @times[ query ][ source ]
  end

  # Actually parse the run logs.
  def parse
    state = BEFORE_AGGS
    stopTime = nil
    startTime = nil
    query = nil
    source = nil


    @log.each_line do |line|
      lineMatch = LINE_RE.match( line )

      unless lineMatch.nil?
        timestamp = lineMatch[1]
        message = lineMatch[2]
        case state
          when BEFORE_AGGS
            if /Starting: AggQuery/.match( message ) then
              startTime = Time.mktime(*ParseDate.parsedate(timestamp))
              state = START_AGGS
            end
          when START_AGGS
            if SEND_RE.match( message ) then
              query = SEND_RE.match( message )[1]
              source = SEND_RE.match( message )[2]
              state = IN_AGGS
            end
          when IN_AGGS
            if /Finished/.match( message ) then
              stopTime = Time.mktime(*ParseDate.parsedate(timestamp))
              @times[ query ] = {} if @times[query].nil?
              @times[ query ][ source ] = stopTime - startTime

              @queries << query unless @queries.include?( query )
              @sources << source unless @sources.include?( source )
  
              state = BEFORE_AGGS
            end
        end
      end
    end
  end
end
