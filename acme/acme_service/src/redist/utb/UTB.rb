require "dl/import"
require "dl/struct"

module UTB
  extend DL::Importable

  begin
    dlload "libutb.so.2.1"
  end

  extern "int cpu_sucker_ruby(int, int)"
  extern "void stop_cpu_sucker(int)"
  extern "int nic_open(char*)"
  extern "int nic_close(char*)"
  extern "int power_off()"
end







