# 
# erbhandler.rb -- ERbHandler Class
#       
# Author: IPR -- Internet Programming with Ruby -- writers
# Copyright (c) 2001 TAKAHASHI Masayoshi, GOTOU Yuuzou
# Copyright (c) 2002 Internet Programming with Ruby writers. All rights
# reserved.
#   
# $IPR: erbhandler.rb,v 1.16 2002/09/21 12:23:41 gotoyuzo Exp $

require 'webrick/httpservlet/abstract.rb'
begin
  require 'erb/erbl'
rescue LoadError
end

module WEBrick
  module HTTPServlet

    class ERbHandler < AbstractServlet
      def initialize(server, name)
        super
        @script_filename = name
      end

      def do_GET(request, response)
        unless defined?(ERbLight)
          @logger.warn "#{type}: ERbLight not defined."
          raise HTTPStatus::Forbidden, "ERbHandler cannt work."
        end

        data = open(@script_filename){|io| io.read }
        env = request.meta_vars
        begin
          response.body = ERbLight.new(data).result(binding)
        rescue Exception => ex
          @logger.error(ex)
          raise HTTPStatus::InternalServerError, ex.message
        end
        response['content-type'] = "text/html"
      end

      alias do_POST do_GET
    end

  end
end
