=begin
/* 
 * <copyright>
 *  Copyright 2002-2003 BBNT Solutions, LLC
 *  under sponsorship of the Defense Advanced Research Projects Agency (DARPA).
 * 
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the Cougaar Open Source License as published by
 *  DARPA on the Cougaar Open Source Website (www.cougaar.org).
 * 
 *  THE COUGAAR SOFTWARE AND ANY DERIVATIVE SUPPLIED BY LICENSOR IS
 *  PROVIDED 'AS IS' WITHOUT WARRANTIES OF ANY KIND, WHETHER EXPRESS OR
 *  IMPLIED, INCLUDING (BUT NOT LIMITED TO) ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, AND WITHOUT
 *  ANY WARRANTIES AS TO NON-INFRINGEMENT.  IN NO EVENT SHALL COPYRIGHT
 *  HOLDER BE LIABLE FOR ANY DIRECT, SPECIAL, INDIRECT OR CONSEQUENTIAL
 *  DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE OF DATA OR PROFITS,
 *  TORTIOUS CONDUCT, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 *  PERFORMANCE OF THE COUGAAR SOFTWARE.
 * </copyright>
 */
=end


require 'cougaar/scripting'
require 'cougaar/society_builder'
require 'acme_cougaar_xmlnode/monitoredproc.rb'
require 'acme_cougaar_xmlnode/groupchat.rb'

module ACME ; module Plugins

class XMLCougaarNode
  extend FreeBASE::StandardPlugin

  def XMLCougaarNode.start(plugin)
    XMLCougaarNode.new(plugin)
    plugin.transition(FreeBASE::RUNNING)
  end
  
  attr_reader :plugin
  def running_nodes() 
    nodes = @nodes_hash.clone()
    nodes.each do |pid, node| 
      if (! node.alive())
        @nodes_hash.delete(pid)
      end
    end
    return @nodes_hash
  end

  def initialize(plugin)
    @plugin = plugin
    @nodes_hash = {}
    
    #START NODE
    @plugin["/plugins/acme_host_jabber_service/commands/start_xml_node/description"].data = 
      "Starts Cougaar node and returns PID. Params: host:port (of XML document server)"
    @plugin["/plugins/acme_host_jabber_service/commands/start_xml_node"].set_proc do |message, command| 
      node = NodeConfig.new(@plugin, command, message.session)
      pid = node.start
      puts "STARTED: #{pid}"
      running_nodes[pid] = node
      message.reply.set_body(pid).send
    end
    
    #STOP NODE
    @plugin["/plugins/acme_host_jabber_service/commands/stop_xml_node/description"].data = 
      "Stops Cougaar node. Params: PID"
    @plugin["/plugins/acme_host_jabber_service/commands/stop_xml_node"].set_proc do |message, command| 
      pid = command
      node = running_nodes[pid]
      if node
        node.stop
        running_nodes.delete(pid)
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
      node = running_nodes[pid.strip]
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

    # Stack dump node
    @plugin["/plugins/acme_host_jabber_service/commands/stack/description"].data =
      "Dump the Java stack of Cougaar a node. Params: PID"
    @plugin["/plugins/acme_host_jabber_service/commands/stack"].set_proc do |message, command|
      found = false
      running_nodes.each do |pid, node|
        if pid == command
          found = true
          node.dumpStack()
        end
      end
      message.reply.set_body("FAILURE: Unknown node: #{command}").send unless found
    end

    # Monitor Node stdio
    @plugin["/plugins/acme_host_jabber_service/commands/stdio/description"].data =
      "Monitor stdout/stderr of Cougaar nodes. Params: PID"
    @plugin["/plugins/acme_host_jabber_service/commands/stdio"].set_proc do |message, command|
      found = false
      running_nodes.each do |pid, node|
        if pid == command
          found = true
          XMLCougaarNode.monitorStdio(message, node)
        end
      end
      message.reply.set_body("FAILURE: Unknown node: #{command}").send unless found
    end



    #LIST NODES
    @plugin["/plugins/acme_host_jabber_service/commands/list_xml_nodes/description"].data = 
      "List Running Cougaar nodes."
    @plugin["/plugins/acme_host_jabber_service/commands/list_xml_nodes"].set_proc do |message, command| 
      txt = "Current Nodes:\n"
      running_nodes.each do |pid, node| 
        txt << "PID:#{pid} Name:#{node.name}\n"
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
      conference=@plugin.properties['conference']
      txt << "conference=#{conference}\n"
      message.reply.set_body(txt).send
    end
    
    # Mount handler for receiving file via HTTP
    @plugin['/protocols/http/xmlnode'].set_proc do |request, response|
      if request.request_method=="POST"
        filename = XMLCougaarNode.makeFileName(request.path[9..-1])
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

  def XMLCougaarNode.makeFileName(basename)
    tmpdir = File.join("", "tmp")
    if (File.exist?(tmpdir) && File.ftype(tmpdir) == "directory")
      filename = File.join(tmpdir, basename)
    else
      filename = File.join(".", basename)
    end
  end

  def XMLCougaarNode.monitorStdio(message, node)
    remove = false
    node.listeners.each do |msg|
      if msg.thread == message.thread # unregister for stdio
        node.listeners.delete(msg)
        message.reply.set_body("Un-Registered for Stdio").send
        remove = true
      end
    end
    if (! remove)
      node.listeners << message
      message.reply.set_body("Registered for Stdio").send
    end
  end

  end
  
  class NodeConfig
  
    attr_accessor :pid, :jvm, :arguments, :env, :jvm_props, :java_class, :society_doc
    attr_reader :name, :mproc, :listeners

    def alive()
      return @mproc && @mproc.alive()
    end

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

    def initialize(plugin, node_config, session)
      begin
        @plugin = plugin
        @listeners = []
        @session = session

        @filename = XMLCougaarNode.makeFileName(node_config)
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
  
        @conference = plugin.properties['conference']
        if @conference
          presence = Jabber::Protocol::Presence.gen_group_probe(@conference)
          @session.connection.send(presence)
          iq = Jabber::Protocol::Iq.gen_group_join(@session, @conference, "#{get_node_name(@society)}")
          @session.connection.send(iq)
        end
        

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

      @mproc = MonitoredProcess.new(cmd)
      @mproc.addStdioListener(self)
      @mproc.start

			@pid = @mproc.pid.to_s
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

    def sendMsg(s) 
      @listeners.each do |msg|
        msg.reply.set_body(s).send
      end

      if (@conference)
        chatmsg = Jabber::Protocol::Message.new(@conference, "groupchat")
        chatmsg.set_body(s)
        @session.connection.send(chatmsg)
      end

    end

    def stdoutCB(s)
      if s.include?("\n")
        msg = "OUT: \n#{s}"
      else
        msg = "OUT: #{s}"
      end
      #puts msg
      sendMsg(msg)
    end
    def stderrCB(s)
      if s.include?("\n")
        msg = "ERR: \n#{s}"
      else
        msg = "ERR: #{s}"
      end
  
      #puts msg
      sendMsg(msg)
    end
    def exitCB()
			@plugin['log/info'] << "DONE WITH NODE read thread. Process exited"
      sendMsg("Process Exited")
      if @conference
        presence = Jabber::Protocol::Presence.gen_group_probe(@conference)
        presence.type = "unavailable"
        @session.connection.send(presence)
      end
    end

    def stop
      @monitors.each {|thread| thread.kill}
      @plugin['log/info'] << "Stopping process: #{@mproc.pid}"
      @mproc.kill
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

    def dumpStack()
      @mproc.signal(3) #SIGQUIT
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

