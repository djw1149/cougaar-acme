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

