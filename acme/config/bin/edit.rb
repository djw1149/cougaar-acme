# <copyright>
#  Copyright 2001-2003 BBNT Solutions, LLC
#  under sponsorship of the Defense Advanced Research Projects Agency (DARPA).
# 
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the Cougaar Open Source License as published by
#  DARPA on the Cougaar Open Source Website (www.cougaar.org).
# 
#  THE COUGAAR SOFTWARE AND ANY DERIVATIVE SUPPLIED BY LICENSOR IS
#  PROVIDED 'AS IS' WITHOUT WARRANTIES OF ANY KIND, WHETHER EXPRESS OR
#  IMPLIED, INCLUDING (BUT NOT LIMITED TO) ALL IMPLIED WARRANTIES OF
#  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, AND WITHOUT
#  ANY WARRANTIES AS TO NON-INFRINGEMENT.  IN NO EVENT SHALL COPYRIGHT
#  HOLDER BE LIABLE FOR ANY DIRECT, SPECIAL, INDIRECT OR CONSEQUENTIAL
#  DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE OF DATA OR PROFITS,
#  TORTIOUS CONDUCT, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
#  PERFORMANCE OF THE COUGAAR SOFTWARE.
# </copyright>


# Set this if you require remote X display.
# If you don't know what this is, you don't need it.
display = nil # eg "localhost"

require 'cougaar/scripting'

file = ARGV[0]
print "EDITING: #{file}\n"
builder = Cougaar::SocietyBuilder.from_xml_file(file)
society = builder.society
society.each_host do |host|
	host.each_node do |node|
		if (display)
		  node.add_env_parameter("DISPLAY=#{display}:0.0")
		end
		node.remove_parameter("-Dorg.cougaar.configuration.database")
		node.remove_parameter("-Dorg.cougaar.configuration.password")
		node.remove_parameter("-Dorg.cougaar.configuration.user")
		node.remove_parameter("-Dorg.cougaar.experiment.id")
		node.remove_parameter("-Dorg.cougaar.control.port")
		node.remove_parameter("-Dorg.cougaar.tools.server.swallowOutputConnectionException")
		node.remove_parameter("-Dorg.cougaar.node.InitializationComponent")
		node.override_parameter("-Dorg.cougaar.core.node.InitializationComponent","XML")
		node.override_parameter("-Dorg.cougaar.core.persistence.clear","true")
		node.override_parameter("-Dorg.cougaar.society.file","#{file}")
		# Put in your own ACME log4j config file name here
		node.override_parameter("-Dorg.cougaar.core.logging.config.filename","loggingConfig.conf")

		# Put in your own preferred log file name here
		node.override_parameter("-Dorg.cougaar.core.logging.log4j.appender.SECURITY.File","$COUGAAR_INSTALL_PATH/workspace/log4jlogs/$HOSTNAME.log")

		# To run most societies, you need configs/common and configs/glmtrans
		# on the path. Edit in your own cougaar_install_path
		node.override_parameter("-Dorg.cougaar.config.path","$COUGAAR_INSTALL_PATH/configs/common\\\;$COUGAAR_INSTALL_PATH/configs/glmtrans\\\;")


    # the acme service will substitute for $COUGAAR_INSTALL_PATH in these
		node.override_parameter("-Dorg.cougaar.install.path","$COUGAAR_INSTALL_PATH")
		node.override_parameter("-Dorg.cougaar.workspace","$COUGAAR_INSTALL_PATH/workspace")
		node.override_parameter("-Dorg.cougaar.system.path","$COUGAAR_INSTALL_PATH/sys")
		node.override_parameter("-Djava.class.path","$COUGAAR_INSTALL_PATH/lib/bootstrap.jar")
		node.remove_parameter("-Xbootclasspath/p:$COUGAAR_INSTALL_PATH/lib/javaiopatch.jar")
		node.add_parameter("-Xbootclasspath/p:$COUGAAR_INSTALL_PATH/lib/javaiopatch.jar")


	# Edit in your own preferred Java memory sizes here
    node.replace_parameter("/-Xms/","-Xms64m")
    node.replace_parameter("/-Xmx/","-Xmx764m")

		node.each_agent do |agent|
			agent.remove_component("org.cougaar.core.topology.TopologyReaderServlet")
			agent.each_component do |comp|
				if comp.classname == "org.cougaar.mlm.plugin.ldm.LDMSQLPlugin"
					comp.arguments[0].value = "fdm_equip_ref.q"
				end
				if comp.classname == "org.cougaar.mlm.plugin.organization.GLSInitServlet"
					comp.arguments[0].value = "093FF.oplan.noncsmart.q"
				end
			end
		end
	end
end

print "WRITING: #{file}.rb\n"
builder.to_ruby_file(file+".rb")
print "WRITING: #{file}\n"
builder.to_xml_file(file)
print "DONE: #{file}\n"

exit
