#!/usr/bin/ruby

=begin
 * <copyright>  
 *  Copyright 2001-2004 BBN Technologies
 *
 *  under sponsorship of the Defense Advanced Research Projects  
 *  Agency (DARPA).  
 *   
 *  You can redistribute this software and/or modify it under the 
 *  terms of the Cougaar Open Source License as published on the 
 *  Cougaar Open Source Website (www.cougaar.org <www.cougaar.org> ).   
 *   
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
 *  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
 *  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR 
 *  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT 
 *  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
 *  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT 
 *  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
 *  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY 
 *  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
 *  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
 *  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 * </copyright>  
=end

module ACME; module Plugins

class DNS
  extend FreeBASE::StandardPlugin

  def self.start(plugin)
=begin
    plugin['log/info'] << "ACME::Plugin::DNS[start]"
    plugin['instance'] = DNS.new( plugin )
=end
    self.new( plugin )
    plugin.transition(FreeBASE::RUNNING)
  end

=begin
  def self.stop(plugin)
    plugin['log/info'] << "ACME::Plugin::DNS[stop]"
    plugin.do_reset

    plugin.transition(FreeBASE::LOADED)
  end
=end

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

    `sed -e '/#{hostname}[ 	]/d' -e 's/.*; serial/#{make_serial}; serial/g' < #{@db} > #{@db}.work`
    `echo "#{hostname}	A	#{ipaddress}" >> #{@db}.work`
    `/sbin/service named stop`
    `mv #{@db}.work #{@db}`
    sleep(1)
    `/sbin/service named start`

    do_lookup( hostname )
  end

  def do_reset
    @plugin['log/info'] << "Resetting DNS to known state."
    `/sbin/service named stop`
    sleep(1)
    `/sbin/service named start`
    "OK"
  end

  def do_lookup( hostname )
    `nslookup #{hostname} -silent | grep Address | grep -v \\# | cut -d: -f2`.strip!
  end 

  def make_serial
    Time.now.to_i.to_s
  end
end

end; end
