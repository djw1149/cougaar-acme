#! /usr/bin/ruby --

class TaskReport
  attr_reader :data
  def initialize(filename)
    file = IO.readlines(filename)
    agent = nil
    @data = {}
    agent = nil
    file.each do |line|
      if line =~ /agent=/ then
        line.chomp!
        agent = line.split(/=/)[1]
        agent.delete!("\'>")
        @data[agent] = {}
      elsif (line =~ /<(.+)>(.+)<\/\1>/) then
        if !agent.nil? then
          if ($1 == "Ratio") then
            @data[agent][$1] = $2.to_f
          else
           @data[agent][$1] = $2.to_i
          end
        else
          @data[$1] = $2.to_i
        end
      elsif line =~ /\/SimpleCompletion/ then
        agent = nil
      end
    end
  end
end

def collect(data, tag)
  elems = []
  if data.class.to_s == "Hash"
    data.each_value do |val|
      elems << val[tag]
    end
  elsif data.class.to_s == "Array"
    data.each do |val|
      elems << val[tag]
    end
  end
  return elems
end

def mean(data)
  return 0 if data.size == 0
  n = 0
  data.each do |x|
    n += x.to_i
  end
  n = n.to_f
  n /= data.size
  return n
end

def stddev(data, m = nil)
  return variance(data, m) ** (0.5)
end

def variance(data, m = nil)
  return 0 if data.size < 2
  m = mean(data) if m.nil?
  n = 0
  data.each do |x|
    n += (x.to_i - m)**2
  end
  n /= (data.size - 1)
  return n
end



def output(compdata)
  printf("%-9s %-9s %-9s %-9s %-9s %-9s %-9s %-9s\n", "", "Total", "Root", "Root", "Root", "Ammo", "Conus", "Euro")
  printf("%-9s %-9s %-9s %-9s %-9s %-9s %-9s %-9s\n", "Run", "Supply", "PS", "Supply", "Trans", "ShipPack", "ShipPack", "ShipPack")

  compdata.keys.sort.each do |run|
    run =~ /([0-9]+of[0-9]+)/
    name = $1
    total_supply = compdata[run]["TotalSocietyTasks"]
    root_ps = compdata[run]["TotalRootPSTasks"]
    root_supply = compdata[run]["TotalRootSupplyTasks"]
    root_trans = compdata[run]["TotalRootTransportTasks"]
    ammo = compdata[run]["AmmoShipPacker.TRANSCOM.MIL"]["NumTasks"]
    conus = compdata[run]["ConusShipPacker.TRANSCOM.MIL"]["NumTasks"]
    euro = compdata[run]["EuroShipPacker.TRANSCOM.MIL"]["NumTasks"]
    printf("%-9s %-9d %-9d %-9d %-9d %-9d %-9d %-9d\n", name, total_supply, root_ps, root_supply, root_trans, ammo, conus, euro)
  end

  total_supply = mean(collect(compdata, "TotalSocietyTasks"))
  root_ps = mean(collect(compdata, "TotalRootPSTasks"))
  root_supply = mean(collect(compdata, "TotalRootSupplyTasks"))
  root_trans = mean(collect(compdata, "TotalRootTransportTasks"))
  ammo = mean(collect(collect(compdata, "AmmoShipPacker.TRANSCOM.MIL"), "NumTasks"))
  conus = mean(collect(collect(compdata, "ConusShipPacker.TRANSCOM.MIL"), "NumTasks"))
  euro = mean(collect(collect(compdata, "EuroShipPacker.TRANSCOM.MIL"), "NumTasks"))
  printf("%-9s %-9g %-9g %-9g %-9g %-9g %-9g %-9g\n", "MEAN", total_supply, root_ps, root_supply, root_trans, ammo, conus, euro)
    
  total_supply = stddev(collect(compdata, "TotalSocietyTasks"))
  root_ps = stddev(collect(compdata, "TotalRootPSTasks"))
  root_supply = stddev(collect(compdata, "TotalRootSupplyTasks"))
  root_trans = stddev(collect(compdata, "TotalRootTransportTasks"))
  ammo = stddev(collect(collect(compdata, "AmmoShipPacker.TRANSCOM.MIL"), "NumTasks"))
  conus = stddev(collect(collect(compdata, "ConusShipPacker.TRANSCOM.MIL"), "NumTasks"))
  euro = stddev(collect(collect(compdata, "EuroShipPacker.TRANSCOM.MIL"), "NumTasks"))
  printf("%-9s %-9g %-9g %-9g %-9g %-9g %-9g %-9g\n", "STDDEV", total_supply, root_ps, root_supply, root_trans, ammo, conus, euro)

end

dirs = $*
dirs.delete_if {|x| !File.stat(x).directory?}
    
if dirs.size == 0 then
  puts "Usage:  TaskReport [log directory1] [log directory2] ..."
  exit 1
end

old = Dir.pwd
Dir.chdir(dirs[0])
compfiles = Dir["comp*.xml"]
Dir.chdir(old)


compdata = {}
compfiles.each do |file|
  rundata = {}  
  dirs.each do |logdir|
    if File.exists?("#{logdir}/#{file}") then
      rundata[logdir] = (TaskReport.new("#{logdir}/#{file}").data)
    end
  end
  compdata[file] = rundata
end

compdata.each_key do |file|
  puts file
  output(compdata[file])
  puts ""
end