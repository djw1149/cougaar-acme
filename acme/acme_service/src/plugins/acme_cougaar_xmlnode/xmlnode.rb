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

  def jabber
    return @plugin["/plugins/acme_host_jabber_service/session"].data
  end

  def makeFileName(basename)
    tmpdir = @config_mgr.tmp_dir
    if (File.exist?(tmpdir) && File.ftype(tmpdir) == "directory")
      filename = File.join(tmpdir, basename)
    else
      filename = File.join(".", basename)
    end
    filename
  end

  def initialize(plugin)
    @plugin = plugin
    @nodes_hash = {}
    @config_mgr = plugin['/cougaar/config'].manager
    
    #START NODE
    @plugin["/plugins/acme_host_jabber_service/commands/start_xml_node/description"].data = 
      "Starts Cougaar node and returns PID. Params: filename (previously posted to /xmlnode) "
    @plugin["/plugins/acme_host_jabber_service/commands/start_xml_node"].set_proc do |message, command| 
      node = NodeConfig.new(self, @plugin, command)
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

    # SHOW NODE
    @plugin["/plugins/acme_host_jabber_service/commands/show_xml_node/description"].data = 
      "Show details about a running Cougaar node. Params: PID"
    @plugin["/plugins/acme_host_jabber_service/commands/show_xml_node"].set_proc do |message, command| 
      pid = command
      node = running_nodes[pid]
      if node
        txt = "#{node.get_description}\n"
        txt << "#{node.to_s}\n"
        message.reply.set_body(txt).send
      else
        message.reply.set_body("FAILURE: Unknown node: #{pid}").send
      end
    end

    #LIST NODES
    @plugin["/plugins/acme_host_jabber_service/commands/list_xml_nodes/description"].data = 
      "List Running Cougaar nodes."
    @plugin["/plugins/acme_host_jabber_service/commands/list_xml_nodes"].set_proc do |message, command| 
      txt = "Current Nodes:\n"
      running_nodes.each do |pid, node| 
        txt << "#{node.get_description}\n"
      end
      message.reply.set_body(txt).send
    end

    #Show Params
    @plugin["/plugins/acme_host_jabber_service/commands/show_xml_params/description"].data = 
      "Show parameters for starting Cougaar nodes."
    @plugin["/plugins/acme_host_jabber_service/commands/show_xml_params"].set_proc do |message, command| 
			txt = "\n"
      conference=@plugin.properties['conference']
      txt << "conference=#{conference}\n"
      message.reply.set_body(txt).send
    end
    
    # Mount handler for receiving xml node file via HTTP
    @plugin['/protocols/http/xmlnode'].set_proc do |request, response|
      if request.request_method=="POST"
        filename = makeFileName(request.path[9..-1])
        #search and replace $COUGAAR_INSTALL_PATH
        data = request.body
        data.gsub!(/\$COUGAAR_INSTALL_PATH/, @plugin['/cougaar/config'].manager.cougaar_install_path)

        File.open(filename, "w") do |file|
          file.write(data)
          response.body = "File #{request.path[9..-1]} written."
          response['Content-Type'] = "text/plain"
        end
        File.chmod(0644, filename)
      else
        response.body = "<html>XMLNode File upload only responds to HTTP POST.</html>"
        response['Content-Type'] = "text/html"
      end
    end
    
    # Mount handler for receiving communities xml file via HTTP
    @plugin['/protocols/http/communities'].set_proc do |request, response|
      if request.request_method=="POST"
        filename = File.join(@plugin['/cougaar/config'].manager.cougaar_install_path, "configs", "common", "communities.xml")
        #search and replace $COUGAAR_INSTALL_PATH
        data = request.body
        data.gsub!(/\$COUGAAR_INSTALL_PATH/, @plugin['/cougaar/config'].manager.cougaar_install_path)
        `#{@plugin['/cougaar/config'].manager.cmd_wrap('chmod 777 $CIP/configs/common/communities.xml')}`
        File.open(filename, "w") do |file|
          file.write(data)
          response.body = "Communities.xml file written."
          response['Content-Type'] = "text/plain"
        end
        `#{@plugin['/cougaar/config'].manager.cmd_wrap('chmod 644 $CIP/configs/common/communities.xml')}`
        XMLCougaarNode.jarAndSign(@plugin, "configs/common/communities.xml")
      else
        response.body = "<html>Communities.xml File upload only responds to HTTP POST.</html>"
        response['Content-Type'] = "text/html"
      end
    end
  end
  
  def XMLCougaarNode.jarAndSign(plugin, filepath)
    cmd_jar = plugin['/cougaar/config'].manager.cmd_wrap("cd $CIP; jar cf #{filepath}.jar #{filepath}")
    cmd_jarsign = plugin['/cougaar/config'].manager.cmd_wrap("cd $CIP; jarsigner -keystore /usr/local/acme/keystore_localconfig -storepass keystore #{filepath}.jar xmlconfigkey")
    `#{cmd_jar}`
    `#{cmd_jarsign}`
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

  class NodeConfig
  
    attr_accessor :pid, :arguments, :env, :jvm_props, :java_class, :society_doc
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

    def get_description()
      exp = "unknown"
		  props = get_jvm_props(@society) 
      props.each do |p|
        if (p.index("-Dorg.cougaar.event.experiment=") == 0)
          exp = p.split("=")[1]
        end
      end
      return "PID: #{@pid} Node: #{@name} Experiment: #{exp}"
    end

		def edit_society
			@society.each_host do |host|
				host.each_node do |node|
					#node.override_parameter("-Dorg.cougaar.class.path","/debug/classes")
          #node.override_parameter("-Dorg.cougaar.workspace","#{@config_mgr.cougaar_install_path}/workspace")
					#node.override_parameter("-Dorg.cougaar.core.node.InitializationComponent","XML")
					#node.override_parameter("-Dorg.cougaar.install.path","#{@config_mgr.cougaar_install_path}")
					#node.override_parameter("-Dorg.cougaar.system.path","#{@config_mgr.cougaar_install_path}/sys")
					#node.override_parameter("-Djava.class.path","#{@config_mgr.cougaar_install_path}/lib/bootstrap.jar")
					#node.override_parameter("-Dorg.cougaar.core.node.XML","true")
					node.override_parameter("-Dorg.cougaar.society.file", @xml_filename)
					#node.add_parameter("-Xbootclasspath/p:#{@config_mgr.cougaar_install_path}/lib/javaiopatch.jar")
				end
			end
		end

    def initialize(xml_cougaar_node, plugin, node_config)
      begin
        @plugin = plugin
        @xml_cougaar_node = xml_cougaar_node

        @listeners = []
        @config_mgr = plugin['/cougaar/config'].manager

        @filename = @xml_cougaar_node.makeFileName(node_config)
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
        
        @conference = plugin.properties['conference']
        if @conference and @conference!=""
          join_conference
        end
  
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
        XMLCougaarNode.jarAndSign(@plugin, @xml_filename)
        unless @filename == @xml_filename
          File.unlink(@filename)
        end
        @plugin.log_info << "NODE Starting. parsed society.."
      rescue
        puts $!
        puts $!.backtrace
      end
    end
    
    def join_conference
      @old_session = @xml_cougaar_node.jabber
      presence = Jabber::Protocol::Presence.gen_group_probe(@conference)
      @xml_cougaar_node.jabber.connection.send(presence)
      iq = Jabber::Protocol::Iq.gen_group_join(@xml_cougaar_node.jabber, @conference)
      @xml_cougaar_node.jabber.connection.send(iq)
    end

    def start
			cmd = @config_mgr.cmd_wrap("#{@config_mgr.jvm_path} #{@jvm_props.join(' ')} #{@java_class} #{@arguments.join(' ')}")
      
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
      begin
        @listeners.each do |msg|
          @xml_cougaar_node.jabber.connection.send(msg.reply.set_body(s))
        end

        if (@conference)
          # session might have changed.  May need to re-login
          join_conference unless @xml_cougaar_node.jabber == @old_session
          chatmsg = Jabber::Protocol::Message.new(@conference, "groupchat")
          chatmsg.set_body(s)
          @xml_cougaar_node.jabber.connection.send(chatmsg)
        end
      rescue
			  @plugin['log/info'] << "Error sending to jabber: #{$!} Msg: #{s}"
      end

    end

    def stdoutCB(s)
      if s.include?("\n")
        msg = "<#{@name}:OUT>\n#{s}"
      else
        msg = "<#{@name}:OUT> #{s}"
      end
      #puts msg
      sendMsg(msg)
    end
    def stderrCB(s)
      if s.include?("\n")
        msg = "<#{@name}:ERR>\n#{s}"
      else
        msg = "<#{@name}:ERR> #{s}"
      end
  
      #puts msg
      sendMsg(msg)
    end
    def exitCB()
			@plugin['log/info'] << "DONE WITH NODE read thread. Process exited"
      sendMsg("#{@name} Process Exited")
      if @conference
        presence = Jabber::Protocol::Presence.gen_group_probe(@conference)
        presence.type = "unavailable"
        @xml_cougaar_node.jabber.connection.send(presence)
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
    
    def to_s
      %Q[JVM: #{@config_mgr.jvm_path}\n#{@jvm_props.join("\n")}\nCLASS: #{@java_class}\nARGS: #{@arguments}\nENV:\n#{@env.join("\n")}]
    end
	end
end
    
end ; end

