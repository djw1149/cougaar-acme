=begin
/* 
 * <copyright>
 *  Copyright 2002-2003 BBNT Solutions, LLC
 *  under sponsorship of the Defense Advanced Research Projects Agency (DARPA).
 * 
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the Cougaar Open Source License as published by
 *  DARPA on the Cougaar Open Source Website (www.cougaar.org).
 * 
 *  THE COUGAAR SOFTWARE AND ANY DERIVATIVE SUPPLIED BY LICENSOR IS
 *  PROVIDED 'AS IS' WITHOUT WARRANTIES OF ANY KIND, WHETHER EXPRESS OR
 *  IMPLIED, INCLUDING (BUT NOT LIMITED TO) ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, AND WITHOUT
 *  ANY WARRANTIES AS TO NON-INFRINGEMENT.  IN NO EVENT SHALL COPYRIGHT
 *  HOLDER BE LIABLE FOR ANY DIRECT, SPECIAL, INDIRECT OR CONSEQUENTIAL
 *  DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE OF DATA OR PROFITS,
 *  TORTIOUS CONDUCT, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 *  PERFORMANCE OF THE COUGAAR SOFTWARE.
 * </copyright>
 */
=end


require 'cougaar/scripting'
require 'cougaar/society_builder'

class Facet
  def initialize(for_object, *methods)
    @facet_methods = methods
    @facet_object = for_object
  end
  def method_missing(method, *params, &block)
    if @facet_methods.include?(method)
      @facet_object.send(method, *params, &block)
    else
      super
    end
  end
end

module ACME ; module Plugins

class CougaarConfig
  extend FreeBASE::StandardPlugin

  def self.start(plugin)
    CougaarConfig.new(plugin)
    plugin.transition(FreeBASE::RUNNING)
  end
  
  attr_reader :plugin, :cougaar_install_path, :jvm_path, :cmd_prefix, :cmd_suffix, :cmd_user, :tmp_dir
  
  def initialize(plugin)
    @plugin = plugin
    load_properties
    @plugin['/cougaar/config'].manager = Facet.new(self, :cougaar_install_path, :jvm_path, :cmd_wrap, :tmp_dir)
    #Show Params
    @plugin["/plugins/acme_host_jabber_service/commands/show_cougaar_config/description"].data = 
      "Show parameters for starting Cougaar nodes."
    @plugin["/plugins/acme_host_jabber_service/commands/show_cougaar_config"].set_proc do |message, command| 
			txt = "\n"
      txt << "cougaar_install_path = #{@cougaar_install_path} \n"
      txt << "jvm_path=#{@jvm_path}\n"
      txt << "cmd_prefix=#{@cmd_prefix}\n"
      txt << "cmd_suffix=#{@cmd_suffix}\n"
      txt << "cmd_user=#{@cmd_user}\n"
      txt << "tmp_dir=#{@tmp_dir}\n"
      message.reply.set_body(txt).send
    end
    
    # Mount handler for receiving file via HTTP
    @plugin['/protocols/http/cougaar_config'].set_proc do |request, response|
      if request.request_method=="POST"
        if @cougaar_install_path != request.query['cougaar_install_path']
          @plugin.properties['cougaar_install_path'] = request.query['cougaar_install_path']
        end
        if @jvm_path != request.query['jvm_path']
          @plugin.properties['jvm_path'] = request.query['jvm_path']
        end
        if @cmd_prefix != request.query['cmd_prefix']
          @plugin.properties['cmd_prefix'] = request.query['cmd_prefix']
        end
        if @cmd_suffix != request.query['cmd_suffix']
          @plugin.properties['cmd_suffix'] = request.query['cmd_suffix']
        end
        if @cmd_user != request.query['cmd_user']
          @plugin.properties['cmd_user'] = request.query['cmd_user']
        end
        if @tmp_dir != request.query['tmp_dir']
          @plugin.properties['tmp_dir'] = request.query['tmp_dir']
        end
        load_properties
        response['Content-Type'] = "text/html"
        response.body="<html><body><h2>Configuration Data Updated <A href='/cougaar_config'>(cont)</A></html>"
      else
        data = nil
        File.open(File.join(@plugin.plugin_configuration.base_path, "edit_config.html"), 'r') {|f| data = f.read}
        if data
          data.gsub!('@cougaar_install_path', @cougaar_install_path)
          data.gsub!('@jvm_path', @jvm_path)
          data.gsub!('@cmd_prefix', @cmd_prefix)
          data.gsub!('@cmd_suffix', @cmd_suffix)
          data.gsub!('@cmd_user', @cmd_user)
          data.gsub!('@tmp_dir', @tmp_dir)
          response.body = data
        end
        response['Content-Type'] = "text/html"
      end
    end
  end
  
  def load_properties
    @jvm_path = @plugin.properties['jvm_path']
    @cougaar_install_path = @plugin.properties['cougaar_install_path']
    @cmd_prefix = @plugin.properties['cmd_prefix']
    @cmd_suffix = @plugin.properties['cmd_suffix']
    @cmd_user = @plugin.properties['cmd_user']
    @tmp_dir = @plugin.properties['tmp_dir']
    if @cougaar_install_path.nil? || @cougaar_install_path==""
      if @cmd_user!=nil && @cmd_user!=""
        @cougaar_install_path = `su -l -c 'echo $COUGAAR_INSTALL_PATH' #{@cmd_user}`.strip
        @plugin.log_info << "Using COUGAAR_INSTALL_PATH from user #{@cmd_user}"
      else
        @cougaar_install_path = ENV['COUGAAR_INSTALL_PATH']
        @plugin.log_info << "Using COUGAAR_INSTALL_PATH from environment"
      end
      unless @cougaar_install_path
        @cougaar_install_path = ""
        @plugin.log_error << "Unknown COUGAAR_INSTALL_PATH, set it in the environment or properties.yaml file"
      end
    else
      @plugin.log_info << "Using COUGAAR_INSTALL_PATH from properties.yaml file"
    end
    @plugin.log_info << "COUGAAR_INSTALL_PATH=#{@cougaar_install_path}"
    if @jvm_path.nil? || @jvm_path==""
      @jvm_path = "java"
    end
    @cmd_user = "" unless @cmd_user
    @cmd_prefix = "" unless @cmd_prefix
    @cmd_suffix = "" unless @cmd_suffix
    @tmp_dir = File.join("", "tmp") unless @tmp_dir
  end
  
  def cmd_wrap(cmd)
    if @cmd_user!=nil && @cmd_user!=""
      result = %Q[su -l -c '#{@cmd_prefix}#{cmd}#{@cmd_suffix}' #{cmd_user}] 
    else
      result = "#{@cmd_prefix}#{cmd}#{@cmd_suffix}"
    end
    return result
  end
end
  

end ; end

