=begin
 * <copyright>  
 *  Copyright 2001-2004 InfoEther LLC  
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

require 'jabber4r/jabber4r'

module Jabber
  module Protocol
    class Presence
      attr_writer :type
      def Presence.gen_group_probe(jid)
        ret = Presence.new(nil)
        ret.to = jid
        return ret
      end
    end # class Presence

    class Message
      attr_reader :session
    end

    class Iq
      def Iq.gen_group_join(session, jid, nick=session.username)
        iq = Iq.new(session, Jabber.gen_random_id)
        iq.type = "set"
        iq.to = jid
        iq.xmlns = "jabber:iq:conference"
        iq.data = XMLElement.new("nick").add_data(nick).to_s
        return iq
      end
    end # class Iq
  end # module Protocol
end # module Jabber

if $0 == __FILE__


  session = Jabber::Session.bind_digest("acme_console@az/rb", "c0ns0le")
  session.announce_initial_presence
  session.add_message_listener{ |msg|
    puts msg
  }
  
  presence = Jabber::Protocol::Presence.gen_group_probe("society@conference.az")
  session.connection.send(presence)

  iq = Jabber::Protocol::Iq.gen_group_join(session, "society@conference.az")
  session.connection.send(iq)

  sleep 200

end

