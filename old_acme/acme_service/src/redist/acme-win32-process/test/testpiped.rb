require "win32/process"

p Process::VERSION

myproc = Process.create_piped(
   "app_name" => "python -u output.py"
)

p "proc = #{myproc}\n"

while Process.is_active(myproc) do
  p "waiting..."
  sleep 1
  out = Process.get_stdout(myproc);
  err = Process.get_stderr(myproc);
  print "OUT: [#{out}] ERR: [#{err}]\n"
end

