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

require 'jdwp'

module Cougaar
  module Actions
    class EnableDebugging < Cougaar::Action
      DOCUMENTATION = Cougaar.document {
        @description = "Enable debugging of society JVMs."
        @example = "do_action 'EnableDebugging'"
      }
      
      def perform
        @run.society.each_host do |host|
          port = 7744
          host.each_node do |node|
            node.replace_parameter(/runjdwp/, "-Xdebug -Xnoagent -Djava.compiler=NONE -Xrunjdwp:transport=dt_socket,address=#{port},server=y,suspend=n")
            node.add_facet { |facet| facet[:debug_port] = port.to_s }
            port += 1
          end
        end
      end
    end

    class StartDebugging < Cougaar::Action
      DOCUMENTATION = Cougaar.document {
        @description = "Start debugging of society by connecting to JVMs."
        @example = "do_action 'StartDebugging'"
      }
      
      def perform
        sessions = {}
        @run[:debug_sessions] = sessions
        @run.society.each_node do |node|
          begin
            session = JDWP::Session.new
            session.transport = JDWP::SocketTransport.new(node.host.uri_name, node.get_facet(:debug_port).to_i)
            session.start
            sessions[node.name] = session
          rescue Exception => e
            @run.info_message "Error debugging..."
            @run.info_message node.name
            @run.info_message node.host.uri_name
            @run.info_message node.get_facet(:debug_port).to_i
          end
        end
      end
    end
    
    class SuspendSociety < Cougaar::Action
      DOCUMENTATION = Cougaar.document {
        @description = "Suspend all threads in all society JVMs."
        @example = "do_action 'SuspendSociety'"
      }
      
      def perform
        sessions = @run[:debug_sessions]
        sessions.each do |node_name, session|
          session.send(JDWP::Packets::VirtualMachine::Suspend.new)
        end
      end
    end

    class ResumeSociety < Cougaar::Action
      DOCUMENTATION = Cougaar.document {
        @description = "Resume all threads in all society JVMs."
        @example = "do_action 'ResumeSociety'"
      }
      
      def perform
        sessions = @run[:debug_sessions]
        sessions.each do |node_name, session|
          session.send(JDWP::Packets::VirtualMachine::Resume.new)
        end
      end
    end

    class StopDebugging < Cougaar::Action
      DOCUMENTATION = Cougaar.document {
        @description = "Stop all debugging sessions."
        @example = "do_action 'StopDebugging'"
      }
      
      def perform
        sessions = @run[:debug_sessions]
        sessions.each do |node_name, session|
          session.stop
        end
        @run[:debug_sessions] = {}
      end
    end
    
  end
end


