
module ACME ; module Plugins

class CougaarNode
  extend FreeBASE::StandardPlugin

  def CougaarNode.start(plugin)
    CougaarNode.new(plugin)
    plugin.transition(FreeBASE::RUNNING)
  end
  
  attr_reader :plugin
  def initialize(plugin)
    @plugin = plugin
    @running_nodes = {}
    
    #START NODE
    start_desc = "Starts Cougaar node and returns PID. Params: -D elements separated by CR"
    start_proc = Proc.new do |message, command| 
      node = NodeConfig.new(@plugin, @plugin.properties['props_path'], command)
      pid = node.start
      @running_nodes[pid]=node
      message.reply.set_body(pid).send
    end
    
    @plugin["/plugins/acme_host_jabber_service/commands/start_db_node/description"].data = start_desc
    @plugin["/plugins/acme_host_jabber_service/commands/start_db_node"].set_proc(start_proc)
    
    # The following two are for backward compatability
    @plugin["/plugins/acme_host_jabber_service/commands/start_node/description"].data = start_desc
    @plugin["/plugins/acme_host_jabber_service/commands/start_node"].set_proc(start_proc)
    
    #STOP NODE
    stop_desc = "Stops Cougaar node. Params: PID"
    stop_proc = Proc.new do |message, command| 
      pid = command
      node = @running_nodes[pid]
      if node
        node.stop
        @running_nodes.delete(pid)
        message.reply.set_body("SUCCESS: Node stopped").send
      else
        message.reply.set_body("FAILURE: Unknown node: #{pid}").send
      end
    end

    @plugin["/plugins/acme_host_jabber_service/commands/stop_db_node/description"].data = stop_desc
    @plugin["/plugins/acme_host_jabber_service/commands/stop_db_node"].set_proc(stop_proc)
    
    # The following two are for backward compatability
    @plugin["/plugins/acme_host_jabber_service/commands/stop_node/description"].data = stop_desc
    @plugin["/plugins/acme_host_jabber_service/commands/stop_node"].set_proc(stop_proc)
  end
  
  class NodeConfig
  
    attr_accessor :pid, :jvm, :arguments, :env, :options, :java_class

    def initialize(plugin, props_file, initial_props)
      @props_file = props_file
      @plugin = plugin
      @jvm = @plugin.properties['jvm_path']
      @java_class = nil
      @arguments = nil
      @env = []
      @options = []
      configure read_props(initial_props)
      @monitors = []
    end
    
    def start
      @pipe = IO.popen(build_command)
      puts "Starting...\n#{build_command}"
      @pid = @pipe.pid.to_s
      return @pid
    end
    
    def stop
      @monitors.each {|thread| thread.kill}
      if @pipe
        a = `ps -falx`.split("\n")
        pidlist = [@pid]
        a.each do |line|
          pidlist << line[10,5].strip if pidlist.include? line[16,5].strip
        end
        #pidlist.each_index {|i| puts "#{i} #{pidlist[i]}"}
        `kill -9 #{pidlist[2]}`
        sleep 2
        `kill -9 #{@pid}` 
        @pipe.close
      end
      puts "Stopping process"
    end
    
    def get_cpu
      begin
        a = `ps -falx`.split("\n")
        pidlist = [@pid]
        a.each do |line|
          pidlist << line[10,5].strip if pidlist.include? line[16,5].strip
        end
      rescue
        return "falx #{$!}"
      end
      cpu = 0.0
      begin
        pidlist.each do |pid|
          line = `ps -uhp #{pid}`
          cpu = cpu + line[15,4].to_f if line.size > 0
        end
      rescue
        return "list #{$!}"
      end
      return cpu.to_s    
    end
    
    def build_command
      prefix = @plugin.properties['node_start_prefix']
      prefix = '' unless prefix
      suffix = @plugin.properties['node_start_suffix']
      suffix = '' unless suffix
      result = prefix
      @env.each {|var| result << "set #{var};"}
      result << %Q[#{@jvm} #{@options.join(" ")} #{@java_class} #{@arguments}]
      result << suffix
      return result
    end
    
    def configure(props)
      props.each do |property|
        case property
        when /^Command\$Arguments/
          @arguments = property[(property.index("=")+1)..-1].gsub(/"/, "'")
        when /^env./
          puts property
          @env << property[4..-1]
        when /^java.class.path/
          @options << "-classpath "+property[(property.index("=")+1)..-1].gsub(/"/, "'")
        when /^java.class.name/
          @java_class = property[(property.index("=")+1)..-1]
        when /^java.Xbootclasspath\/p/
          @options << "-Xbootclasspath/p:"+property[(property.index("=")+1)..-1]
        when /^java.Xbootclasspath\/a/
          @options << "-Xbootclasspath/a:"+property[(property.index("=")+1)..-1]
        when /^java.X/
          @options << "-"+property[5..-1]
        when /^java.D/
          @options << "-D"+property[6..-1].gsub(/"/, "'")
        else
          @options << %Q[-D#{property.gsub(/\\/, '').gsub(/"/, "'")}]
        end
      end
    end
    
    def to_s
      %Q[JVM: #{@jvm}\n#{@options.join("\n")}\nCLASS: #{@java_class}\nARGS: #{@arguments}\nENV:\n#{@env.join("\n")}]
    end
    
    def read_props(intial_props)
      props = []
      overrides = []
      intial_props.each_line do |line|
        line = line[2..-1].strip
        overrides << line[0...line.index("=")]
        props << line
      end
      begin
        File.open(@props_file) do |io|
          io.each_line do |line|
            line.strip!
            if line[0]!="#"[0] and line.size > 3
              props << line unless line.include? "=" and overrides.include? line[0...line.index("=")]
            end
          end
        end
      rescue
        puts $!
      end
      return props
    end
  end
end
      
end ; end
