#!/usr/bin/ruby

#
#

module ACME; module Plugins

class DNS
  extend FreeBASE::StandardPlugin

  def self.start(plugin)
    plugin['log/info'] << "ACME::Plugin::DNS[start]"
    plugin['instance'] = DNS.new( plugin )

    plugin.transition(FreeBASE::RUNNING)
  end

  def self.stop(plugin)
    plugin['log/info'] << "ACME::Plugin::DNS[stop]"
    plugin.do_reset

    plugin.transition(FreeBASE::LOADED)
  end

  attr_reader :plugin

  def initialize( plugin )
    super( )
    @plugin = plugin
    @plugin['log/info'] << "Initializing acme_net_dns"

    cmd = @plugin.properties["command"]
    desc = @plugin.properties["description"]
    
    @db = @plugin.properties["db"]
    @backup = @plugin.properties["db.bk"]

    @plugin["/plugins/acme_host_communications/commands/#{cmd}/description"].data = desc
    @plugin["/plugins/acme_host_communications/commands/#{cmd}"].set_proc do |msg, cmd|
       case cmd
         # move( hostname, ipaddress ) - This method change the IP Address
         # associated with the given hostname.

         when /move\((.*),(.*)\)/
           plugin['log/info'] << "Moving host #{$1} to address #{$2}"
           reply = do_move( $1, $2 )

         # lookup - Returns the IP Address the DNS is handing out.
         when /lookup\((.*)\)/
           plugin['log/info'] << "Looking up host #{$1}"
           reply = do_lookup( $1 )
        
         # reset - This method restores DNS to a pristine state
         when /reset/
           plugin['log/info'] << "Resetting DNS to a known state."
           reply = do_reset
         else 
           reply = "#{cmd} unknown-#{command}"
       end
       msg.reply.set_body( reply ).send
    end           
  end

  def do_move( hostname, ipaddress )
    @plugin['log/info'] << "Changing #{hostname} to #{ipaddress}"
    ip = do_lookup( hostname )
    tab = '\t'

    `sed '/#{hostname}[ 	]/d' < #{@db} > #{@db}.work`
    `echo \"#{hostname}	A	#{ipaddress}\" >> #{@db}.work`
    `/sbin/service named stop`
    `mv #{@db}.work #{@db}`
    `/sbin/service named start`

    do_lookup( hostname )
  end

  def do_reset
    @plugin['log/info'] << "Resetting DNS to known state."
    @plugin['log/info'] << "cp #{@backup} to #{@db}"
    `/sbin/service named stop`
    @plugin['log/info'] << `cp #{@backup} #{@db}`
    `/sbin/service named start`
    "OK"
  end

  def do_lookup( hostname )
    `nslookup #{hostname} -silent | grep Address | grep -v \\# | cut -d: -f2`.strip!
  end 


end

end; end
