#
# config.rb -- Default configurations.
#
# Author: IPR -- Internet Programming with Ruby -- writers
# Copyright (c) 2000, 2001 TAKAHASHI Masayoshi, GOTOU Yuuzou
# Copyright (c) 2002 Internet Programming with Ruby writers. All rights
# reserved.
#
# $IPR: config.rb,v 1.40 2002/09/21 12:23:35 gotoyuzo Exp $

require 'webrick/version'
require 'webrick/httpversion'
require 'webrick/httputils'
require 'webrick/utils'
require 'webrick/log'

module WEBrick
  module Config
    LIBDIR = File::dirname(__FILE__)

    # for GenericServer
    General = {
      :ServerName     => Utils::getservername,
      :Port           => nil,   # users MUST specifiy this!!
      :BindAddress    => nil,   # "0.0.0.0" or "::" or nil
      :MaxClients     => 100,   # maximum number of the concurrent connections
      :ServerType     => nil,   # default: WEBrick::SimpleServer
      :Logger         => nil,   # default: WEBrick::Log.new
      :ServerSoftware =>
        "WEBrick/#{WEBrick::VERSION} (#{WEBrick::RELEASE_DATE}) " +
        "(Ruby/#{RUBY_VERSION}/#{RUBY_RELEASE_DATE})",
      :TempDir        => ENV['TMPDIR']||ENV['TMP']||ENV['TEMP']||'/tmp',
      :DoNotListen    => false,
    }

    # for HTTPServer, HTTPRequest, HTTPResponse ...

    HTTP = General.dup.update({
      :Port           => 80,
      :RequestTimeout => 30,
      :DocumentRoot   => nil,
      :HTTPVersion    => HTTPVersion.new("1.1"),
      :AccessLog      => nil,
      :MimeTypes      => HTTPUtils::load_mime_types(LIBDIR + "/mime.types"),

      :RequestHandler => nil,
      :ProxyAuthProc  => nil,
      :ProxyAuthRealm => nil,
      :ProxyContentHandler => nil,
      :ProxyVia       => true,
      :ProxyTimeout   => true,

      :DirectoryIndex => ["index.html","index.htm","index.cgi","index.rhtml"],
      :DirectoryListEnable => true,

      :CGIInterpreter => nil,
      :CGIPathEnv     => nil,
    })

  end
end
