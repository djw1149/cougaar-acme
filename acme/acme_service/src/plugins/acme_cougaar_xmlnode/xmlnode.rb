
require 'cougaar/scripting'
require 'cougaar/society_builder'

module ACME ; module Plugins

class XMLCougaarNode
  extend FreeBASE::StandardPlugin

  def XMLCougaarNode.start(plugin)
    XMLCougaarNode.new(plugin)
    system("rm -f society*.?") # clean up temp files
    plugin.transition(FreeBASE::RUNNING)
  end
  
  attr_reader :plugin
  def initialize(plugin)
    @plugin = plugin
    @running_nodes = {}
    
    #START NODE
    @plugin["/plugins/acme_host_jabber_service/commands/start_xml_node/description"].data = 
      "Starts Cougaar node and returns PID. Params: host:port (of XML document server)"
    @plugin["/plugins/acme_host_jabber_service/commands/start_xml_node"].set_proc do |message, command| 
      node = NodeConfig.new(@plugin, command)
      pid = node.start
      @running_nodes[pid] = node
      message.reply.set_body(pid).send
    end
    
    #STOP NODE
    @plugin["/plugins/acme_host_jabber_service/commands/stop_xml_node/description"].data = 
      "Stops Cougaar node. Params: PID"
    @plugin["/plugins/acme_host_jabber_service/commands/stop_xml_node"].set_proc do |message, command| 
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
    
=begin # This is untested
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
=end

    #LIST NODES
    @plugin["/plugins/acme_host_jabber_service/commands/list_xml_nodes/description"].data = 
      "List Running Cougaar nodes."
    @plugin["/plugins/acme_host_jabber_service/commands/list_xml_nodes"].set_proc do |message, command| 
      txt = "Current Nodes:\n"
      @running_nodes.each do |pid, node| 
        txt << "PID:#{pid}\n#{node.to_s}\n"
      end
      message.reply.set_body(txt).send
    end

    #Show Params
    @plugin["/plugins/acme_host_jabber_service/commands/show_xml_params/description"].data = 
      "Show parameters for starting Cougaar nodes."
    @plugin["/plugins/acme_host_jabber_service/commands/show_xml_params"].set_proc do |message, command| 
			txt = "\n"
      cip = @plugin.properties['cip']
      txt << "cip = #{cip} \n"
      jvm_path=@plugin.properties['jvm_path']
      txt << "jvm_path=#{jvm_path}\n"
      cmd_prefix=@plugin.properties['cmd_prefix']
      txt << "cmd_prefix=#{cmd_prefix}\n"
      cmd_suffix=@plugin.properties['cmd_suffix']
      txt << "cmd_suffix=#{cmd_suffix}\n"
      message.reply.set_body(txt).send
    end
    
    # Mount handler for receiving file via HTTP
    @plugin['/protocols/http/xmlnode'].set_proc do |request, response|
      if request.request_method=="POST"
        filename = File.join(@plugin.plugin_configuration.user_filename("foo.bar", true), request.path[9..-1])
        File.open(filename, "w") do |file|
          file.write(request.body)
          response.body = "File #{request.path[9..-1]} written."
          response['Content-Type'] = "text/plain"
        end
        File.chmod(0644, filename)
      else
        response.body = "<html>XMLNode File upload only responds to HTTP POST.</html>"
        response['Content-Type'] = "text/html"
      end
    end
  end
  
  class NodeConfig
  
    attr_accessor :pid, :jvm, :arguments, :env, :jvm_props, :java_class, :society_doc
    attr_reader :name

		def get_node_name(society) 
			society.each_host do |host|
				host.each_node do |node|
					return node.name
				end
			end
		end

		def get_java_class(society) 
			society.each_host do |host|
				host.each_node do |node|
					return node.classname
				end
			end
		end

		def get_arguments(society) 
			society.each_host do |host|
				host.each_node do |node|
					return node.prog_parameters
				end
			end
		end

		def get_env(society) 
			society.each_host do |host|
				host.each_node do |node|
					return node.env_parameters
				end
			end
		end

		def get_jvm_props(society) 
			society.each_host do |host|
				host.each_node do |node|
					return node.parameters
				end
			end
		end

		def edit_society
			@society.each_host do |host|
				host.each_node do |node|
					#node.override_parameter("-Dorg.cougaar.class.path","/debug/classes")
          node.override_parameter("-Dorg.cougaar.workspace","#{@cip}/workspace")
					node.override_parameter("-Dorg.cougaar.core.node.InitializationComponent","XML")
					node.override_parameter("-Dorg.cougaar.install.path","#{@cip}")
					node.override_parameter("-Dorg.cougaar.system.path","#{@cip}/sys")
					node.override_parameter("-Djava.class.path","#{@cip}/lib/bootstrap.jar")
					node.override_parameter("-Dorg.cougaar.core.node.XML","true")
					node.override_parameter("-Dorg.cougaar.society.file", @xml_filename)
					node.add_parameter("-Xbootclasspath/p:#{@cip}/lib/javaiopatch.jar")
				end
			end
		end

    def initialize(plugin, node_config)
      begin
        @plugin = plugin
        
        @filename = File.join(@plugin.plugin_configuration.user_filename("foo.bar", true), node_config)
        if @filename=~/.xml/
          @xml_filename = @filename
        else
          @xml_filename = @filename[0..(@filename=~/.rb/)]+'xml'
        end
        
        @plugin['log/info']  << "NEW NODE Starting. Config file = #{@xml_filename}"
        
        if @filename=~/.xml/
          @builder = Cougaar::SocietyBuilder.from_xml_file(@filename)
        else
          @builder = Cougaar::SocietyBuilder.from_ruby_file(@filename)
        end
        
        @society = @builder.society
  
        @jvm = plugin.properties['jvm_path']
  
        @cmd_prefix = plugin.properties['cmd_prefix']
        if (!@cmd_prefix) 
          @cmd_prefix = ""
        end
        @cmd_suffix = plugin.properties['cmd_suffix']
        if (!@cmd_suffix) 
          @cmd_suffix = ""
        end
  
        @cip = plugin.properties['cip']
        @java_class = get_java_class(@society)
        @arguments = get_arguments(@society)
        @env = get_env(@society)
        @jvm_props = get_jvm_props(@society)
        @name = get_node_name(@society)
        @monitors = []
        @event_queue = plugin["/plugins/Events/event"]
        
        # Edit the society per the current configuration
        edit_society
        @builder.to_xml_file(@xml_filename)
        unless @filename == @xml_filename
          File.unlink(@filename)
        end
        @plugin.log_info << "NODE Starting. parsed society.."
      rescue
        puts $!
        puts $!.backtrace
      end
    end
    
    def start
			cmd = build_command
      @plugin.log_info << "Starting command:\n#{cmd}"

      @pipe = IO.popen(cmd)
      if @cip.index(":") == nil
			  Thread.new(@pipe) {|pipe|stdio(pipe)}
      end
			@pid = @pipe.pid.to_s
      if @pid == ''
        @society.each_host do |host|
					host.each_node do |node|
					  @pid = node.name
					  break
					end
					break
				end
      end
			@plugin.log_info << "DONE starting NODE: #{@pid}\n"
			return @pid
    end

		def stdio(pipe)
      require "timeout"
			begin
				while (true) do
          begin
            timeout(5) do
					    s = pipe.getc
						  if s == nil 
							  break
			  		  end
						  putc s
            end
            rescue TimeoutError
              puts "T"
          end
				end
			rescue
			  @plugin['log/info'] << "DONE WITH NODE exception: #{$!}"
			end
			@plugin['log/info'] << "DONE WITH NODE read thread"
    end
    
    def stop
      @monitors.each {|thread| thread.kill}
      @plugin['log/info'] << "Stopping process: #{@pipe.id}"
      if @pipe
				if (@pipe.pid)
          a = `ps -falx`.split("\n")
          pidlist = [@pid]
          a.each do |line|
            pidlist << line[10,5].strip if pidlist.include? line[16,5].strip
          end
          `kill -9 #{pidlist[2]}`
          sleep 2
          `kill -9 #{@pid}` 
				end
				@pipe.close
      end
      @plugin['log/info'] << "Stopped process."
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
      result = ""
      result << @cmd_prefix
			#@env.each {|var| result << "set #{var};"}
      result << %Q[#{@jvm} #{@jvm_props.join(" ")} #{@java_class} #{@arguments}]
			result << @cmd_suffix
      return result
    end
    
    def to_s
      %Q[JVM: #{@jvm}\n#{@jvm_props.join("\n")}\nCLASS: #{@java_class}\nARGS: #{@arguments}\nENV:\n#{@env.join("\n")}]
    end
	end
end
    
end ; end

