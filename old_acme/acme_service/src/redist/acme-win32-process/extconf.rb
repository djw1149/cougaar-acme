require "mkmf"
require "ftools"

File.copy("lib/win32/process.c", Dir.pwd)
File.copy("lib/win32/pipedprocess.cpp", Dir.pwd)

# Require C++ exception unwind semantics
$CFLAGS += " /EHsc"

create_makefile("win32/process")
