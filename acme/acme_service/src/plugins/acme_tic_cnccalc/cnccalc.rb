module ACME; module Plugins

  class CnCCalc
    extend FreeBASE::StandardPlugin
    
    def CnCCalc.start(plugin)
      CnCCalc.new(plugin)
      plugin.transition(FreeBASE::RUNNING)
    end
    
    attr_reader :plugin
    def initialize(plugin)
    
      @plugin = plugin
      database = @plugin.properties['database']
      username = @plugin.properties['username']
      password = @plugin.properties['password']
      hostname = @plugin.properties['hostname']
      
      @plugin["/plugins/acme_host_jabber_service/commands/cnccalc_reset/description"].data = 
        "Resets the CnCCalc database. params: none"
      @plugin["/plugins/acme_host_jabber_service/commands/cnccalc_reset"].set_proc do |message, command|
        `service postgres restart`
        `echo drop database cnccalc; | psql -U #{username} -h #{hostname} template1`
        `echo create database cnccalc; | psql -U #{username} -h #{hostname} template1`
        message.reply.set_body("Complete").send
      end
      
      @plugin["/plugins/acme_host_jabber_service/commands/cnccalc_newrun/description"].data = 
        "Creates a new entry in the CnCCalc database. params: type,name,desc"
      @plugin["/plugins/acme_host_jabber_service/commands/cnccalc_newrun"].set_proc do |message, command|
        type, name, desc = (command.split(",").collect {|param| param.strip})
        desc = name unless desc
        command =  "/usr/local/cnccalc/bin/CnCcalc --batch --user #{username} --hostname #{hostname} --database #{database} --type #{type} --experiment '#{name}' --description '#{desc}'"
        status = "\n"
        status += `#{command}`
        message.reply.set_body(status).send
      end
      
      @plugin["/plugins/acme_host_jabber_service/commands/cnccalc_dump/description"].data = 
        "Dump the CnCCalc database. params: filepath"
      @plugin["/plugins/acme_host_jabber_service/commands/cnccalc_dump"].set_proc do |message, command|
        status = "Not yet implemented"
        message.reply.set_body(status).send
      end
      
    end
  end
      
end ; end 
