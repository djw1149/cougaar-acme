#
# httpauth.rb -- HTTP access authentication
#
# Author: IPR -- Internet Programming with Ruby -- writers
# Copyright (c) 2000, 2001 TAKAHASHI Masayoshi, GOTOU Yuuzou
# Copyright (c) 2002 Internet Programming with Ruby writers. All rights
# reserved.
#
# $IPR: httpauth.rb,v 1.9 2002/09/21 12:23:35 gotoyuzo Exp $

require 'base64'

module WEBrick
  module HTTPAuth

    def _basic_auth(req, res, realm, req_field, res_field, err_type, block)
      user = pass = nil
      if /Basic\s+(.*)/o =~ req[req_field]
        userpass = $1
        user, pass = decode64(userpass).split(":", 2)
      end
      return if block.call(user, pass)
      res[res_field] = "Basic realm=\"#{realm}\""
      raise err_type
    end

    def basic_auth(req, res, realm, &block)
      _basic_auth(req, res, realm,
                  "Authorization", "WWW-Authenticate",
                  HTTPStatus::Unauthorized, block)
    end

    def proxy_basic_auth(req, res, realm, &block)
      _basic_auth(req, res, realm,
                  "Proxy-Authorization", "Proxy-Authenticate",
                  HTTPStatus::ProxyAuthenticationRequired, block)
    end

    module_function :_basic_auth, :basic_auth, :proxy_basic_auth
    private_class_method :_basic_auth

  end
end
