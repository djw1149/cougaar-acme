# Purpose: Sample logger plugin
#    
# $Id: logger.rb,v 1.1 2003-02-19 03:17:05 rich Exp $
#
# Authors:  Rich Kilmer <rich@infoether.com>
# Contributors:
#
# This file is part of the FreeRIDE project
#
# This application is free software; you can redistribute it and/or
# modify it under the terms of the Ruby license defined in the
# COPYING file.
# 
# Copyright (c) 2001 Rich Kilmer. All rights reserved.
#

module FreeBASE
  module Plugins
    class Logger
    
      extend FreeBASE::StandardPlugin
    
      def self.load(plugin)
        begin
          require 'log4r'
          require 'log4r/formatter/patternformatter'
          plugin.transition(FreeBASE::LOADED)
        rescue
          plugin.transition_failure
        end
      end
      
      def self.start(plugin)
        begin
          system_properties = plugin["/system/properties"].manager
          logName = system_properties["config/log_name"]
          logFile = system_properties["config/log_file"]
          # Create log file in user directory if it exists
          user_logFile = DefaultPropertiesReader.user_filename(logFile)
          if !user_logFile.nil?
            logFile = user_logFile
          end
          logLevel = system_properties["config/log_level"]
          logger = Log4r::Logger.new(logName)
          logger.level = logLevel
          outputter = Log4r::FileOutputter.new(logName, :filename => logFile, :trunc => false)
          outputter.formatter = Log4r::PatternFormatter.new(:pattern => "[%l] %d :: %m")
          logger.outputters = outputter
          
          ["info", "error", "debug"].each do |logType| #clear the existing log entries
            while msg = plugin["/log/#{logType}"].queue.leave
              logger.send(logType, msg)
            end
          end
          
          plugin["set_level"].set_proc{ |level| logger.level=level }
          plugin["/log"].set_proc { |logType, message| logger.send(logType, message) }
          plugin["/log"].manager = logger
          plugin.transition(FreeBASE::RUNNING)
        rescue
          puts $!
          puts $!.backtrace.join("\n")
          plugin.transition_failure
        end
      end
    end
  end
end
