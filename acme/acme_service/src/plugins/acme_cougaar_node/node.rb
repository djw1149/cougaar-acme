require 'cougaar/event_server'

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
    @plugin["/plugins/acme_host_jabber_service/commands/start_node/description"].data = 
      "Starts Cougaar node and returns PID. Params: -D elements separated by CR"
    @plugin["/plugins/acme_host_jabber_service/commands/start_node"].set_proc do |message, command| 
      node = NodeConfig.new(@plugin, @plugin.properties['props_path'], command)
      pid = node.start
      @running_nodes[pid]=node
      message.reply.set_body(pid).send
    end
    
    #STOP NODE
    @plugin["/plugins/acme_host_jabber_service/commands/stop_node/description"].data = 
      "Stops Cougaar node. Params: PID"
    @plugin["/plugins/acme_host_jabber_service/commands/stop_node"].set_proc do |message, command| 
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
    
    # MONITOR NODE
    @plugin["/plugins/acme_host_jabber_service/commands/monitor_node/description"].data = 
      "Sends back CougaarEvent messages of the proc (PID) every (interval) seconds. Params: PID,interval"
    @plugin["/plugins/acme_host_jabber_service/commands/monitor_node"].set_proc do |message, command| 
      pid, interval = command.split(",")
      unless pid and interval
        message.reply.set_body("FAILURE: Invalid params: PID,interval")
      end
      node = @running_nodes[pid.strip]
      if node
        begin
          interval = interval.strip.to_i
        rescue
          message.reply.set_body("FAILURE: Interval not a number")
        end
        jid = message.from.to_s
        experiment = jid[(jid.index("expt-")+5)..-1]
        node.monitor(experiment, interval)
        message.reply.set_body("SUCCESS: Monitoring node: #{pid}").send
      else
        message.reply.set_body("FAILURE: Unknown node: #{pid}").send
      end
    end
  end
  
  class NodeConfig
  
    attr_accessor :pid, :jvm, :arguments, :env, :options, :java_class

    def initialize(plugin, props_file, initial_props)
      @props_file = props_file
      @jvm = @plugin.properties['jvm_path']
      @java_class = nil
      @arguments = nil
      @env = []
      @options = []
      configure read_props(initial_props)
      @monitors = []
      @event_queue = plugin["/plugins/acme_cougaar_events/event"]
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
    
    def monitor(experiment, interval)
      @monitors << Thread.new do
        while true
          begin
            @event_queue << Cougaar::CougaarEvent.new do |event|
              event.experiment = experiment
              event.event_type = "MONITOR_NODE"
              event.data = get_cpu
            end
          rescue
          end
          sleep interval
        end
      end
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
      result = 'su -l -c "'
      @env.each {|var| result << "set #{var};"}
      result << %Q[#{@jvm} #{@options.join(" ")} #{@java_class} #{@arguments}]
      result << '" asmt'
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

#a = ACME::Plugins::CougaarNode::NodeConfig.new("Linux.props", "-DCommand$Arguments=test\n-DDISPLAY=foo")
#a.to_s
