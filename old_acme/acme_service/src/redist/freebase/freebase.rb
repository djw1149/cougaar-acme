# Purpose: FreeBASE constant declarations and module inclusion
#    
# $Id: freebase.rb,v 1.1 2004-07-26 17:09:25 wwright Exp $
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

  #version information
  VERSION_MAJOR = 0
  VERSION_MINOR = 1
  VERSION_RELEASE = 0


  #state transitions for plugins
  UNLOADED = "UNLOADED"
  LOADING = "LOADING"
  LOADED = "LOADED"
  STARTING = "STARTING"
  RUNNING = "RUNNING"
  STOPPING = "STOPPING"
  UNLOADING = "UNLOADING"
  ERROR = "ERROR"
  
  #system state transition order
  STARTUP_STATES = [UNLOADED, LOADING, LOADED, STARTING, RUNNING]
  SHUTDOWN_STATES = [STOPPING, LOADED, UNLOADING, UNLOADED]
  
end

require 'freebase/core'
require 'freebase/plugin'
require 'freebase/databus'
require 'freebase/properties'
require 'freebase/readers'
require 'freebase/configuration'
