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

COUGAAR_FILE_LIST = Dir.glob(File.join("..","acme_scripting","src","lib","cougaar","*.rb")).collect {|file| File.basename(file)}
ULTRALOG_FILE_LIST = Dir.glob(File.join("..","acme_scripting","src","lib","ultralog","*.rb")).collect {|file| File.basename(file)}

CONFIGURATION_COUGAAR_FILE_LIST = [
  'setup.rb',
  'experiment.rb',
  'society_model.rb', 
  'society_builder.rb', 
  'society_utils.rb', 
  'society_rule_engine.rb', 
  'communities.rb'
]

CONFIGURATION_ULTRALOG_FILE_LIST = [
  'enclaves.rb'
]

CONFIGURATION_BIN_FILE_LIST = [
  'transform-society',
  'convert-society'
]

CONTROL_BIN_FILE_LIST = [
]

require 'fileutils'

# BUILD acme-configuration gem

FileUtils.rm_rf("lib") if File.exist?("lib")
FileUtils.rm_rf("bin") if File.exist?("bin")

FileUtils.mkdir_p("lib/cougaar")
FileUtils.mkdir_p("lib/ultralog")
FileUtils.mkdir_p("bin")

CONFIGURATION_COUGAAR_FILE_LIST.each do |file|
  File.open(File.join("..","acme_scripting","src","lib","cougaar",file), "rb") do |input|
    File.open(File.join("lib", "cougaar", file), "wb") do |output|
      output.write(input.read)
    end
  end 
end

CONFIGURATION_ULTRALOG_FILE_LIST.each do |file|
  File.open(File.join("..","acme_scripting","src","lib","ultralog",file), "rb") do |input|
    File.open(File.join("lib", "ultralog", file), "wb") do |output|
      output.write(input.read)
    end
  end 
end

CONFIGURATION_BIN_FILE_LIST.each do |file|
  File.open(File.join("..","acme_scripting","bin",file), "rb") do |input|
    File.open(File.join("bin", file), "wb") do |output|
      output.write(input.read)
    end
  end 
  FileUtils.chmod(0755, File.join("bin", file))
end

File.open(File.join("lib", "cougaar", "configuration.rb"), "w") do |config|
  config.puts LICENSE
  CONFIGURATION_COUGAAR_FILE_LIST.each {|file| config.puts "require 'cougaar/#{file}'"}
end

File.open(File.join("lib", "ultralog", "configuration.rb"), "w") do |config|
  config.puts LICENSE
  CONFIGURATION_ULTRALOG_FILE_LIST.each {|file| config.puts "require 'ultralog/#{file}'"}
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
  s.executables = CONFIGURATION_BIN_FILE_LIST

  s.author = "Richard Kilmer"
  s.email = "rich@infoether.com"
  s.homepage = "http://acme.cougaar.org"
end

Gem::manage_gems
Gem::Builder.new(spec).build

FileUtils.rm_rf("lib") if File.exist?("lib")
FileUtils.rm_rf("bin") if File.exist?("bin")

# BUILD acme-control gem

FileUtils.mkdir_p("lib/cougaar")
FileUtils.mkdir_p("lib/ultralog")
FileUtils.mkdir_p("bin")

(COUGAAR_FILE_LIST - CONFIGURATION_COUGAAR_FILE_LIST).each do |file|
  File.open(File.join("..","acme_scripting","src","lib","cougaar",file), "rb") do |input|
    File.open(File.join("lib", "cougaar", file), "wb") do |output|
      output.write(input.read)
    end
  end 
end

(ULTRALOG_FILE_LIST - CONFIGURATION_ULTRALOG_FILE_LIST).each do |file|
  File.open(File.join("..","acme_scripting","src","lib","ultralog",file), "rb") do |input|
    File.open(File.join("lib", "ultralog", file), "wb") do |output|
      output.write(input.read)
    end
  end 
end

spec = Gem::Specification.new do |s|
  s.name = 'acme-control'
  s.version = ACME_VERSION
  s.summary = "Uses the ACME framework to control Cougaar societies."
  s.description = <<-EOF
    ACME is a framework to configure and control Cougaar multiagent societies. 
    This gem provides the control subset of that functionality and depends on 
    the configuration gem.
  EOF

  s.has_rdoc = true

  s.files = Dir.glob("lib/**/*")
  s.require_path = 'lib'

  s.bindir = "bin"
  s.executables = CONTROL_BIN_FILE_LIST
  
  s.add_dependency(%q<acme-configuration>, [">= 1.6.0"])

  s.author = "Richard Kilmer"
  s.email = "rich@infoether.com"
  s.homepage = "http://acme.cougaar.org"
end

Gem::Builder.new(spec).build

FileUtils.rm_rf("lib") if File.exist?("lib")
FileUtils.rm_rf("bin") if File.exist?("bin")

# BUILD ACME SERVICE GEM

FileUtils.rm_rf("plugins")
FileUtils.rm_rf("redist")
FileUtils.mkdir_p("bin")

SERVICE_PLUGINS_FILE_LIST = Dir.glob(File.join("../acme_service/src/plugins/**/*")).delete_if {|file| file.include?("CVS") || File.directory?(file)}
SERVICE_REDIST_FILE_LIST = Dir.glob(File.join("../acme_service/src/redist/**/*")).delete_if {|file| file.include?("CVS") || File.directory?(file)}

SERVICE_PLUGINS_FILE_LIST.each do |file|
  dest_file = file[20..-1]
  FileUtils.mkdir_p(File.dirname(dest_file))
  FileUtils.cp(file, dest_file)
end

SERVICE_REDIST_FILE_LIST.each do |file|
  dest_file = file[20..-1]
  FileUtils.mkdir_p(File.dirname(dest_file))
  FileUtils.cp(file, dest_file)
end

FileUtils.cp("../acme_service/src/acme-service", "bin/acme-service")
FileUtils.cp("../acme_service/src/acme.rb", "redist/acme.rb")
FileUtils.cp("../acme_service/src/default.yaml", "default.yaml")

spec = Gem::Specification.new do |s|
  s.name = 'acme-service'
  s.version = ACME_VERSION
  s.summary = "Service that manages Cougaar agent nodes"
  s.description = <<-EOF
    ACME is a framework to configure and control Cougaar multiagent societies. 
    This gem provides the control subset of that functionality and depends on 
    the configuration gem.
  EOF

  s.has_rdoc = false

  s.files = Dir.glob("plugins/**/*") + Dir.glob("redist/**/*") + ["default.yaml"]
  s.require_path = 'redist'
  s.autorequire = 'acme'

  s.bindir = "bin"
  s.executables = ["acme-service"]
  
  s.add_dependency(%q<acme-configuration>, [">= 1.6.0"])

  s.author = "Richard Kilmer"
  s.email = "rich@infoether.com"
  s.homepage = "http://acme.cougaar.org"
end

Gem::Builder.new(spec).build

FileUtils.rm_rf("plugins")
FileUtils.rm_rf("redist")
FileUtils.rm_rf("bin")
FileUtils.rm_f("default.yaml")
