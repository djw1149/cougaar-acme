#
# httpservlet.rb -- HTTPServlet Module
#
# Author: IPR -- Internet Programming with Ruby -- writers
# Copyright (c) 2001 TAKAHASHI Masayoshi, GOTOU Yuuzou
# Copyright (c) 2002 Internet Programming with Ruby writers. All rights
# reserved.
#
# $IPR: filehandler.rb,v 1.33 2002/09/21 12:23:42 gotoyuzo Exp $

require 'thread'
require 'time'

require 'webrick/htmlutils'
require 'webrick/httputils'
require 'webrick/httpstatus'

module WEBrick
  module HTTPServlet

    class DefaultFileHandler < AbstractServlet
      def initialize(server, local_path)
        super
        @local_path = local_path
      end

      def do_GET(req, res)
        st = File::stat(@local_path)
        mtime = st.mtime
        mtype = HTTPUtils::mime_type(@local_path, @config[:MimeTypes])
        res['etag'] = sprintf("%x-%x-%x", st.ino, st.size, st.mtime.to_i)

        ifmod = req['if-modified-since']
        if ifmod && Time.parse(ifmod) >= mtime
          res.body = ''
          raise HTTPStatus::NotModified
        else
          res['content-type'] = mtype
          res['content-length'] = st.size
          res['last-modified'] = mtime.httpdate
          res.body = open(@local_path, "rb")
        end
      end
    end

    class FileHandler < AbstractServlet
      HandlerTable = Hash.new(DefaultFileHandler)

      def self.add_handler(suffix, handler)
        HandlerTable[suffix] = handler
      end

      def self.remove_handler(suffix)
        HandlerTable.delete(suffix)
      end

      def initialize(server, root, show_dir=false)
        super
        @root       = root
        @show_dir   = show_dir
      end

      def do_GET(req, res)
        raise HTTPStatus::NotFound, "`#{req.path}' not found" unless @root
        redirect_to_directory_uri(req, res) if req.path_info.empty?
        handler_info = search_handler(req, res)
        if handler_info
          exec_handler(req, res, handler_info)
        else
          set_dir_list(req, res)
        end
      end

      def do_POST(req, res)
        raise HTTPStatus::NotFound, "`#{req.path}' not found" unless @root
        handler_info = search_handler(req, res)
        if handler_info
          exec_handler(req, res, handler_info)
        else
          raise HTTPStatus::NotFound, "`#{req.path}' not found."
        end
      end

      def do_OPTIONS(req, res)
        raise HTTPStatus::NotFound, "`#{req.path}' not found" unless @root
        handler_info = search_handler(req, res)
        if handler_info
          exec_handler(req, res, handler_info)
        else
          super(req, res)
        end
      end

      private

      def search_handler(req, res)
        handler = nil
        filename = @root.dup
        script_name = ""
        path_info = req.path_info.scan(%r|/[^/]*|)

        while name = path_info.shift
          script_name << name
          filename << name
          begin
            st = File::stat(filename)
          rescue
            raise HTTPStatus::NotFound, "`#{req.path}' not found."
          end
          raise HTTPStatus::Forbidden,
            "no access permission to `#{req.path}'." unless st.readable?

          if st.directory?
            next unless path_info.empty?
            redirect_to_directory_uri(req, res) if req.path[-1] != ?/
            indices = @config[:DirectoryIndex]
            index = indices.find{|i| FileTest::file?(filename + i) }
            path_info.push(index) if index
            next
          end

          suffix = /\.(\w+)$/ =~ name && $1
          handler = HandlerTable[suffix]
          break
        end

        handler ? [ handler, filename, script_name, path_info.join ] : nil
      end

      def exec_handler(req, res, handler_info)
        handler, filename, script_name, path_info = handler_info
        req.script_name << script_name
        req.path_info = path_info
        res.filename = filename
        hi = handler.get_instance(@config, filename)
        hi.service(req, res)
      end

      def set_dir_list(req, res)
        raise HTTPStatus::Forbidden,
          "no access permission to `#{req.path}'" unless @show_dir

        local_path = @root + req.path_info
        list = Dir::entries(local_path).collect{|name|
          unless name[0] == ?.
            begin
              st = File::stat(local_path + name)
              if st.directory?
                [ name + "/", st.mtime, -1 ]
              else
                [ name, st.mtime, st.size ]
              end
            rescue
              [ name, nil, -1 ]
            end
          end
        }
        list.compact!

        if    d0 = req.query["N"]; idx = 0
        elsif d0 = req.query["M"]; idx = 1
        elsif d0 = req.query["S"]; idx = 2
        else  d0 = "A"           ; idx = 0
        end
        d1 = (d0 == "A") ? "D" : "A"

        if d0 == "A"
          list.sort!{|a,b| a[idx] <=> b[idx] }
        else
          list.sort!{|a,b| b[idx] <=> a[idx] }
        end

        res['content-type'] = "text/html"

        res.body = <<-_end_of_html_
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<HTML>
  <HEAD><TITLE>Index of #{HTMLUtils::escape(req.path)}</TITLE></HEAD>
  <BODY>
    <H1>Index of #{HTMLUtils::escape(req.path)}</H1>
        _end_of_html_

        res.body << "<PRE>\n"
        res.body << " <A HREF=\"?N=#{d1}\">Name</A>                          "
        res.body << "<A HREF=\"?M=#{d1}\">Last modified</A>         "
        res.body << "<A HREF=\"?S=#{d1}\">Size</A>\n"
        res.body << "<HR>\n"
       
        list.unshift [ "..", File::mtime(local_path+".."), -1 ]
        list.each{ |name, time, size|
          if name == ".."
            dname = "Parent Directory"
          elsif name.size > 25
            dname = name.sub(/^(.{23})(.*)/){ $1 + ".." }
          else
            dname = name
          end
          s =  " <A HREF=\"#{HTTPUtils::escape(name)}\">#{dname}</A>"
          s << " " * (30 - dname.size)
          s << (time ? time.strftime("%Y/%m/%d %H:%M      ") : " " * 22)
          s << (size >= 0 ? size.to_s : "-") << "\n"
          res.body << s
        }
        res.body << "</PRE><HR>"

        res.body << <<-_end_of_html_    
    <ADDRESS>
     #{HTMLUtils::escape(@config[:ServerSoftware])}<BR>
     at #{req.request_uri.host}:#{@config[:Port]}
    </ADDRESS>
  </BODY>
</HTML>
        _end_of_html_
      end

    end
  end
end
