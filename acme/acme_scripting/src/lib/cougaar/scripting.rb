##
#  <copyright>
#  Copyright 2002 InfoEther, LLC
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
#  TORTIOUS CONDUCT, ARISING OUT OF OR IN CONNECTIO½N WITH THE USE OR
#  PERFORMANCE OF THE COUGAAR SOFTWARE.
# </copyright>
#

class Integer
  def seconds(value=0)
    return to_i+value
  end
  alias_method :second, :seconds
  
  def minutes(value=0)
    return to_i*60+value
  end
  alias_method :minute, :minutes
  
  def hours(value=0)
    return to_i*60*60+value
  end
  alias_method :hour, :hours
end

require 'log4r'

module Cougaar
  def self.logger
    unless @logger
      @logger = Log4r::Logger.new("run")
      outputter = Log4r::FileOutputter.new(name, {:filename=>"run.log"})
      outputter.formatter = Log4r::PatternFormatter.new(:pattern => "[%l] %d :: %m")
      @logger.outputters = outputter
    end
    @logger
  end
end

require 'cougaar/society_utils'
require 'cougaar/society_model'
require 'cougaar/experiment'
require 'cougaar/society_builder'
require 'cougaar/communications'
require 'cougaar/society_control'
begin
  require 'cougaar/csmart_database'
rescue
  puts "Could not load cougaar/csmart"
end