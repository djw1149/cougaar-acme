#
# httputils.rb -- HTTPUtils Module
#
# Author: IPR -- Internet Programming with Ruby -- writers
# Copyright (c) 2000, 2001 TAKAHASHI Masayoshi, GOTOU Yuuzou
# Copyright (c) 2002 Internet Programming with Ruby writers. All rights
# reserved.
#
# $IPR: httputils.rb,v 1.22 2002/09/21 12:23:37 gotoyuzo Exp $

require 'socket'

module WEBrick
  CR   = "\x0d"
  LF   = "\x0a"
  CRLF = "\x0d\x0a"

  module HTTPUtils

    def normalize_path(path)
      raise "abnormal path `#{path}'" if path[0] != ?/
      ret = path.dup

      ret.gsub!(%r{/+}o, '/')                    # //      => /
      while ret.sub!(%r{/\.(/|\Z)}o, '/'); end   # /.      => /
      begin                                      # /foo/.. => /foo
        match = ret.sub!(%r{/([^/]+)/\.\.(/|\Z)}o){
          if $1 == ".."
            raise "abnormal path `#{path}'"
          else
            "/"
          end
        }
      end while match

      raise "abnormal path `#{path}'" if %r{/\.\.(/|\Z)} =~ ret
      ret
    end
    module_function :normalize_path

    def load_mime_types(file)
      open(file){ |io|
        hash = Hash.new
        io.each{ |line|
          next if /^#/ =~ line
          line.chomp!
          mimetype, ext0 = line.split(/\s+/, 2)
          next unless ext0   
          next if ext0.empty?
          ext0.split(/\s+/).each{ |ext| hash[ext] = mimetype }
        }
        hash
      }
    end
    module_function :load_mime_types

    def mime_type(filename, mime_tab)
      suffix = /\.(\w+)$/ =~ filename && $1
      mtype = mime_tab[suffix]
      mtype || "application/octet-stream"
    end
    module_function :mime_type

    def parse_query(str)
      query = {}
      if str
        str.split(/[&;]/).each do |x|
          key, val = x.split(/=/,2).collect{|x|
            unescape_form(x)
          }
          if query.has_key?(key)
            query[key] += "\0" + (val or "")
          else
            query[key] = (val or "")
          end
        end
      end
      query
    end
    module_function :parse_query

    def dequote(str)
      ret = str.dup
      if /\A"(.*)"\Z/ =~ ret
        ret = $1
      end
      ret.gsub!(/\\(.)/, "\\1")
      ret
    end
    module_function :dequote

    #####

    reserved = ';/?:@&=+$,'
    num      = '0123456789'
    lowalpha = 'abcdefghijklmnopqrstuvwxyz'
    upalpha  = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    mark     = '-_.!~*\'()'
    unreserved = num + lowalpha + upalpha + mark
    control  = (0x0..0x1f).collect{|c| c.chr }.join + "\x7f"
    space    = " "
    delims   = '<>#%"'
    unwise   = '{}|\\^[]`'
    nonascii = (0x80..0xff).collect{|c| c.chr }.join

    def _make_regex(str) /([#{Regexp.escape(str)}])/n end
    def _escape(str, regex) str.gsub(regex){ "%%%02X" % $1[0] } end
    def _unescape(str, regex) str.gsub(regex){ $1.hex.chr } end
    module_function :_make_regex, :_escape, :_unescape

    UNESCAPED = _make_regex(control + delims + unwise + nonascii)
    UNESCAPED_FORM =
      _make_regex(reserved + control + delims + unwise + nonascii)
    ESCAPED   = /%([0-9a-fA-F]{2})/

    def escape(str)
      _escape(str, UNESCAPED)
    end

    def unescape(str)
      _unescape(str, ESCAPED)
    end

    def escape_form(str)
      ret = _escape(str, UNESCAPED_FORM)
      ret.gsub!(/ /, "+")
      ret
    end

    def unescape_form(str)
      _unescape(str.gsub(/\+/, " "), ESCAPED)
    end

    module_function :escape, :unescape, :escape_form, :unescape_form

  end
end
