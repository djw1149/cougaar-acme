require 'net/http'

module ACME; module Plugins
  
  class Operator
    extend FreeBASE::StandardPlugin
    
    def Operator.start(plugin)
      Operator.new(plugin)
      plugin.transition(FreeBASE::RUNNING)
    end
    
    attr_reader :plugin
    def initialize(plugin)
      @plugin = plugin
      register_commands
      @config = plugin['/cougaar/config']
    end
    
    def register_commands
      register_command("test_cip", "return the $CIP") do |message, command|
        result = ""
        result += call_cmd('echo $CIP').strip
        #result += `su -l -c 'echo $CIP' asmt`
        message.reply.set_body("CIP=[#{result}]").send
      end
      register_command("reset_crypto", "Reset the crypto service") do |message, command|
        result = "\n"
        result += call_cmd('cd $CIP/ldap; ./resetCrypto')
        #result += `su -l -c 'cd $CIP/ldap; ./resetCrypto' asmt`
        message.reply.set_body("Done").send
      end
      register_command("clear_pnlogs", "Clear persistence and log data") do |message, command|
        result = "\n"
        result += call_cmd('cd $CIP/operator; ./clrPnLogs.csh')
        #result += `su -l -c 'cd $CIP/operator; ./clrPnLogs.csh' asmt`
        message.reply.set_body("Done").send
      end
      register_command("clear_persistence", "Clear persistence data") do |message, command|
        result = "\n"
        result += call_cmd('cd $CIP/operator; ./clrP.csh')
        #result += `su -l -c 'cd $CIP/operator; ./clrP.csh' asmt`
        message.reply.set_body("Done").send
      end
      register_command("clear_logs", "Clear log data") do |message, command|
        result = "\n"
        result += call_cmd('cd $CIP/operator; ./clrLogs.csh')
        #result += `su -l -c 'cd $CIP/operator; ./clrLogs.csh' asmt`
        message.reply.set_body("Done").send
      end
      register_command("archive_logs", "Archive the log data. param: archiveDir") do |message, command|
        result = "\n"
        resul += call_cmd("cd $CIP/operator; ./archiveLogs.csh #{command}")
        #result += `su -l -c 'cd $CIP/operator; ./archiveLogs.csh #{command}' asmt`
        message.reply.set_body("Done").send
      end
      register_command("archive_db", "Archive the database data. param: archiveDir") do |message, command|
        result = "\n"
        result += call_cmd("cd $CIP/operator; ./archiveDB.csh #{command}")
        #result += `su -l -c 'cd $CIP/operator; ./archiveDB.csh #{command}' asmt`
        message.reply.set_body("Done").send
      end
    end
    
    def call_cmd(cmd)
      `#{@config.manager.cmd_wrap(cmd)}`
    end
    
    def register_command(name, desc, &block)
      @plugin["/plugins/acme_host_jabber_service/commands/#{name}/description"].data = desc
      @plugin["/plugins/acme_host_jabber_service/commands/#{name}"].set_proc do |message, command|
        begin
          block.call(message, command)
        rescue Exception => e
          message.reply.set_body("Error executing command\n#{e.to_s}\n#{e.backtrace.join("\n")}").send
        end
      end
    end
  end
      
end ; end
