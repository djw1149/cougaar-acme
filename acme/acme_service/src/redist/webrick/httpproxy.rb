#
# httpproxy.rb -- HTTPProxy Class
#
# Author: IPR -- Internet Programming with Ruby -- writers
# Copyright (c) 2002 GOTO Kentaro
# Copyright (c) 2002 Internet Programming with Ruby writers. All rights
# reserved.
#
# $IPR: httpproxy.rb,v 1.10 2002/09/21 12:23:36 gotoyuzo Exp $
# $kNotwork: straw.rb,v 1.3 2002/02/12 15:13:07 gotoken Exp $

require "webrick/httpserver"
require "net/http"

Net::HTTP::version_1_2 if RUBY_VERSION < "1.7"

module WEBrick
  class HTTPProxyServer < HTTPServer
    def initialize(config)
      super
      c = @config
      @via = "#{c[:HTTPVersion]} #{c[:ServerName]}:#{c[:Port]}"
    end

    def service(req, res)
      if req.request_method == "CONNECT"
        proxy_connect(req, res)
      elsif req.unparsed_uri =~ %r!^http://!
        proxy_service(req, res)
      else
        super(req, res)
      end
    end

    def proxy_auth(req, res)
      if proc = @config[:ProxyAuthProc]
        realm = @config[:ProxyAuthRealm]
        HTTPAuth::proxy_basic_auth(req,res,realm,&proc)
      end
      req.header.delete("proxy-authorization")
    end

    # Some header fields shuold not be transfered.
    HopByHop = %w( connection keep-alive proxy-authenticate upgrade
                   proxy-authorization te trailers transfer-encoding )
    ShouldNotTransfer = %w( set-cookie proxy-connection transfer-encoding )
    def split_field(f) f ? f.split(/,\s+/).collect{|i| i.downcase } : [] end

    def choose_header(src, dst)
      connections = split_field(src['connection'])
      src.each{|key, value|
        key = key.downcase
        if HopByHop.member?(key)          || # RFC2616: 13.5.1
           connections.member?(key)       || # RFC2616: 14.10
           ShouldNotTransfer.member?(key)    # pragmatics
          @logger.debug("choose_header: `#{key}: #{value}'")
          next
        end
        dst[key] = value
      }
    end

    # Net::HTTP is stupid about the multiple header fields.
    # Here is workaround:
    def set_cookie(src, dst)
      if str = src['set-cookie']
        cookies = []
        str.split(/,\s*/).each{|token|
          if /^[^=]+;/o =~ token
            cookies[-1] << ", " << token
          elsif /=/o =~ token
            cookies << token
          else
            cookies[-1] << ", " << token
          end
        }
        dst.cookies.replace(cookies)
      end
    end

    def set_via(h)
      if @config[:ProxyVia]
        if  h['via']
          h['via'] << ", " << @via
        else
          h['via'] = @via
        end
      end
    end

    def proxy_service(req, res)
      # Proxy Authentication
      proxy_auth(req, res)      

      # Create Request-URI to send to the origin server
      uri  = req.request_uri
      path = uri.path.dup
      path << "?" << uri.query if uri.query

      # Choose header fields to transfer
      header = Hash.new
      choose_header(req, header)
      set_via(header)

      begin
        http = Net::HTTP.new(uri.host, uri.port)
        if @config[:ProxyTimeout]
          ##################################   these issues are 
          http.open_timeout = 30   # secs  #   necessary (maybe bacause
          http.read_timeout = 60   # secs  #   Ruby's bug, but why?)
          ##################################
        end
        case req.request_method
        when "GET";  response = http.get(path, header)
        when "POST"; response = http.post(path, req.body || "", header)
        when "HEAD"; response = http.head(path, header)
        else
          raise HTTPStatus::MethodNotAllowed,
            "unsupported method `#{req.request_method}'."
        end
      rescue => err
        logger.debug("#{err.type}: #{err.message}")
        raise HTTPStatus::ServiceUnavailable, err.message
      end
  
      # Convert Net::HTTP::HTTPResponse to WEBrick::HTTPProxy
      res.status = response.code.to_i
      choose_header(response, res)
      set_cookie(response, res)
      set_via(res)
      res.body = response.body

      # Persistent connction requirements are mysterious for me.
      # So I will close the connection in every response.
      res['proxy-connection'] = "close"

      # Process contents
      if handler = @config[:ProxyContentHandler]
        handler.call(req, res)
      end
    end

    def proxy_connect(req, res)
      # Proxy Authentication
      proxy_auth(req, res)

      ua = Thread.current[:WEBrickSocket]  # User-Agent
      raise HTTPStaus::InternalServerError,
        "[BUG] cannot get socket" unless ua

      host, port = req.unparsed_uri.split(":", 2)
      begin
        os = TCPSocket.new(host, port)     # origin server
        @logger.debug("CONNECT #{host}:#{port}: succeeded")
        res.status = HTTPStatus::RC_OK
      rescue => ex
        @logger.debug("CONNECT #{host}:#{port}: failed `#{ex.message}'")
        res.status = HTTPStatus::RC_INTERNAL_SERVER_ERROR
        res.reason_phrase = "Proxy Error"
        raise HTTPStatus::EOFError
      ensure
        res.send_response(ua)
        access_log(@config, req, res)
      end

      begin
        while fds = IO::select([ua, os])
          if fds[0].member?(ua)
            buf = ua.sysread(1024);
            @logger.debug("CONNECT: #{buf.size} byte from User-Agent")
            os.syswrite(buf)
          elsif fds[0].member?(os)
            buf = os.sysread(1024);
            @logger.debug("CONNECT: #{buf.size} byte from #{host}:#{port}")
            ua.syswrite(buf)
          end
        end
      rescue => ex
        os.close
        @logger.debug("CONNECT #{host}:#{port}: closed")
      end

      raise HTTPStatus::EOFError
    end

    def do_OPTIONS(req, res)
      res['allow'] = "GET,HEAD,POST,OPTIONS,CONNECT"
    end
  end
end
