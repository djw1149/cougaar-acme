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

$FREEBASE_APPLICATION = "acme"

require 'rbconfig'

at_exit {
  puts "WARNING: Exit called within ACME Service"
  puts caller
  puts "-------"
}

module ACME
  class Service
    #version information
    VERSION_MAJOR = 1
    VERSION_MINOR = 1
    VERSION_RELEASE = 0
    
    ##
    # Start up the ACME Service and block until shut down event is received
    #
    # dir:: [String] The directory which holds the properties.xml and/or default.xml
    #
    def self.startup(dir)
    
      #make sure architecture specific directory is in the include path and before
      #all system standard path
      $:.unshift(File.join(dir, 'redist', Config::CONFIG['arch']))
      $:.unshift(File.join(dir, 'redist'))
    
      require 'freebase/freebase'
      
      #verify the existence of the supplied directory
      begin
        files = Dir.entries(".")
      rescue
        raise "Could not locate directory '.'"
      end
      
      #make sure that either acme.yaml exists or default.yaml
      unless files.include?("acme.yaml")
        raise "Could not locate default.yaml in #{dir}" unless files.include?("default.yaml")
      end
      
      #This method will not return until ACME is closed (shut down)
      FreeBASE::Core.startup("acme.yaml", "default.yaml")
    end
  end
end

if $0==__FILE__
  baseDir = '.'
  baseDir = ARGV[0] if ARGV.size > 0
  ACME::Service.startup(baseDir)
end

