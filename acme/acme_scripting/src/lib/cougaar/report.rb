##
#  <copyright>
#  Copyright 2002 BBN Technologies
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
  class ReportMonitor < Cougaar::ExperimentMonitor
    def initialize( report ) 
      @report = report
    end

    def on_run_end( run )
      @report.cleanup( run )
    end

    def on_run_begin( run )
      @report.startup( run )
    end
  end

  class Report < Cougaar::Action
    DOCUMENTATION = Cougaar.document {
      @description = "This is a generic report.  To create a real report,
                      override this class and optionally implement the
                      following methods:
                          init_society( society )
                          handle_cougaar_event( event )
                          startup( run )
                          cleanup( run )"
    }

    def initialize(run)
      super( run )
      Cougaar::ExperimentMonitor.add ReportMonitor.new( self )
    end

    def perform
      init_society( @run.society )
      @handler = @run.comms.on_cougaar_event do |event|
         handle_cougaar_event event
      end
    end

    def init_society( society )
    end
 
    def handle_cougaar_event( event )
    end

    def startup( run )
    end

    def cleanup( run )
      run.comms.remove_on_cougaar_event( @handle )
    end    
  end
end; end
