##
#  <copyright>
#  Copyright 2003 BBN Technologies
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
#

module Cougaar; module Actions
  class OptimizeIt < Cougaar::Action
    DOCUMENTATION = Cougaar.document {
        @description = "Starts optimizeIt on the node."
        @parameters = [
          {:optNode=> "Node to start optimizeIt on" }
        ]
        @example = "do_action 'OptimizeIt', 'FWD-A'"
    }

    def initialize(run, optNode)
      super(run)
      @optNode = optNode
    end

    def perform
      node = society.node[optNode] 
      node.add_parameter("-Xnoclassgc")
      node.add_parameter("-Djava.compiler=NONE")
      node.add_parameter("-Xrunpri")
      node.add_env_parameter("LD_LIBRARY_PATH=$COUGAAR_INSTALL_PATH/sys/native")
      node.add_parameter("-Xboundthreads")
      node.add_parameter("-Xbootclasspath/a:$COUGAAR_INSTALL_PATH/sys/oibcp.jar")
      node.parameters.each do |param|
         if /-Djava.class.path\=/ =~ param then
           node.parameters.delete( param )
           node.parameters << "#{param}:$COUGAAR_INSTALL_PATH/sys/optit.jar" 
         end
      end
      cn = node.classname
      node.classname = "intuitive.audit.Audit -startCPUprofiler #{cn}"
    end
  end
    
end

 



