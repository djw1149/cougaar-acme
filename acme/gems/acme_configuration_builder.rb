LICENSE = <<-END_LICENSE
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


END_LICENSE

ACME_VERSION = "1.6.0"

COUGAAR_FILE_LIST = [
  'setup.rb',
  'experiment.rb',
  'society_model.rb', 
  'society_builder.rb', 
  'society_utils.rb', 
  'society_rule_engine.rb', 
  'communities.rb'
]

ULTRALOG_FILE_LIST = [
  'enclaves.rb'
]

BIN_FILE_LIST = [
  'transform-society',
  'convert-society'
]

require 'fileutils'

FileUtils.rm_rf("lib") if File.exist?("lib")
FileUtils.rm_rf("bin") if File.exist?("bin")

FileUtils.mkdir_p("lib/cougaar")
FileUtils.mkdir_p("lib/ultralog")
FileUtils.mkdir_p("bin")

COUGAAR_FILE_LIST.each do |file|
  File.open(File.join("..","acme_scripting","src","lib","cougaar",file), "rb") do |input|
    File.open(File.join("lib", "cougaar", file), "wb") do |output|
      output.write(input.read)
    end
  end 
end

ULTRALOG_FILE_LIST.each do |file|
  File.open(File.join("..","acme_scripting","src","lib","ultralog",file), "rb") do |input|
    File.open(File.join("lib", "ultralog", file), "wb") do |output|
      output.write(input.read)
    end
  end 
end

BIN_FILE_LIST.each do |file|
  File.open(File.join("..","acme_scripting","bin",file), "rb") do |input|
    File.open(File.join("bin", file), "wb") do |output|
      output.write(input.read)
    end
  end 
  FileUtils.chmod(0755, File.join("bin", file))
end

File.open(File.join("lib", "cougaar", "configuration.rb"), "w") do |config|
  config.puts LICENSE
  COUGAAR_FILE_LIST.each {|file| config.puts "require 'cougaar/#{file}'"}
end

File.open(File.join("lib", "ultralog", "configuration.rb"), "w") do |config|
  config.puts LICENSE
  ULTRALOG_FILE_LIST.each {|file| config.puts "require 'ultralog/#{file}'"}
end

require 'rubygems'

spec = Gem::Specification.new do |s|
  s.name = 'acme-configuration'
  s.version = ACME_VERSION
  s.summary = "Uses the ACME framework to configure Cougaar societies."
  s.description = <<-EOF
    ACME is a framework to configure and control Cougaar multiagent societies. 
    This gem provides the configuration subset of that functionality.
  EOF

  s.has_rdoc = true

  s.files = Dir.glob("lib/**/*")
  s.require_path = 'lib'

  s.bindir = "bin"
  s.executables = BIN_FILE_LIST

  s.author = "Richard Kilmer"
  s.email = "rich@infoether.com"
  s.homepage = "http://acme.cougaar.org"
end

Gem::manage_gems
Gem::Builder.new(spec).build

FileUtils.rm_rf("lib") if File.exist?("lib")
FileUtils.rm_rf("bin") if File.exist?("bin")