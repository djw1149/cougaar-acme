require "win32/process"

p Process::VERSION

5.times() do |i|
  Thread.new(i) do |idx|
    myproc = Process.create_piped(
     "app_name" => "python -u output.py"
    )
    p "proc(#{idx}) = #{myproc}\n"


    while Process.is_active(myproc) do
      p "waiting..."
      sleep 1
      out = Process.get_stdout(myproc);
      err = Process.get_stderr(myproc);
      print "(#{idx}) -- OUT: [#{out}] ERR: [#{err}]\n"
    end
  end
end

while true do
  sleep(1)
end
