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
