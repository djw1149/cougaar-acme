#
# cgi_runner.rb -- CGI launcher.
#
# Author: IPR -- Internet Programming with Ruby -- writers
# Copyright (c) 2000 TAKAHASHI Masayoshi, GOTOU YUUZOU
# Copyright (c) 2002 Internet Programming with Ruby writers. All rights
# reserved.
#
# $IPR: cgi_runner.rb,v 1.8 2002/09/21 12:23:41 gotoyuzo Exp $

STDIN.binmode

len = STDIN.sysread(8).to_i
out = STDIN.sysread(len)
STDOUT.reopen(open(out, "w"))

len = STDIN.sysread(8).to_i
err = STDIN.sysread(len)
STDERR.reopen(open(err, "w"))

len  = STDIN.sysread(8).to_i
dump = STDIN.sysread(len)
hash = Marshal.restore(dump)
ENV.keys.each{|name| ENV.delete(name) }
hash.each{|k, v| ENV[k] = v if v }

dir = File::dirname(ENV["SCRIPT_FILENAME"])
Dir::chdir dir

if interpreter = ARGV[0]
  exec(interpreter, ENV["SCRIPT_FILENAME"])
  # NOTREACHED
end
exec ENV["SCRIPT_FILENAME"]
