CIP = ENV['COUGAAR_INSTALL_PATH']

unless CIP
  puts "Error: The COUGAAR_INSTALL_PATH environment variable is not set"
  puts "       Make sure Cougaar is installed and the env var is set prior"
  puts "       to running this file"
end

require 'fileutils'
include FileUtils

mkdir_p File.join(CIP, 'workspace', 'nodelogs')
mkdir File.join(CIP, 'configs', 'nodes')
cp 'socketappender.jar', File.join(CIP, 'sys')
cp 'loggingConfig.conf', File.join(CIP, 'configs', 'common')
