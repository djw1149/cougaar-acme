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

require 'net/http'

class CURL
  def self.gen_auth(username, password)
    auth = nil
    auth = "-u #{username}:#{password}" if username!=nil && password!=nil
    auth = "-u #{username}" if auth==nil && username!=nil
    auth
  end
  
  def self.gen_cert(certfile, certpassword)
    cert = nil
    cert = "-E #{certfile}:#{certpassword}" if certfile!=nil && certpassword!=nil
    cert = "-E #{certfile}" if cert!=nil && certfile!=nil
    cert
  end
  
  ##
  # Performs an HTTP get request and follows redirects.  This is
  # useful for Cougaar because all agent requests are redirected
  # to the host that the agent is on before returning data.
  #
  # uri:: [String] The uri (http://...)
  # return:: [String, URI] Returns the body of the http response and the URI of the final page returned
  #
  def self.get(uri, username=nil, password=nil, certfile=nil, certpassword=nil, timeout=1800)
    return nil if uri.nil?
      puts "CURL HTTP GET: [#{uri}]" if $COUGAAR_DEBUG       
    begin
      header = `curl -s -I --max-time #{timeout} #{gen_auth(username, password)} #{gen_cert(certfile, certpassword)} '#{uri}'`
      header.each_line do |line|
        if line=~/Location:/
          return get(line[10..-1].strip, username, password, certfile, certpassword, timeout)
        end
      end
      result = `curl -L -s --max-time #{timeout} #{gen_auth(username, password)} #{gen_cert(certfile, certpassword)} '#{uri}'`
      return result, uri
    rescue
      puts "CURL.get exception #{$!}"
      puts $!.backtrace.join("\n")
      return nil
    end    
  end
  
  ##
  # Performs an HTTP post request and returns the body of response.  Optionally
  # creates a REXML document is the URI returns XML data.
  #
  # uri:: [String] The URI to put to (http://...)
  # request:: [String] The data to post
  # format:: [Symbol=:as_string] Return format (:as_string or :as_xml)
  # return:: [String | REXML::Document] The body test returned as a String or XML document
  #
  def self.post(uri, data, username=nil, password=nil, certfile=nil, certpassword=nil, content_type="application/x-www-form-urlencoded")
    return nil if uri.nil?
    puts "CURL HTTP POST: [#{uri}]" if $COUGAAR_DEBUG
    begin
      pipe = IO.popen("curl -s -L --header 'Content-Type: #{content_type}' #{gen_auth(username, password)} #{gen_cert(certfile, certpassword)} '#{uri}' --data-binary @-", "r+")
      pipe.write(data)
      pipe.close_write
      result = pipe.read
      return result
    rescue
      puts "CURL.post exception #{$!}"
      puts $!.backtrace.join("\n")
      return nil
    end    
  end
  
  ##
  # Performs an HTTP post request and returns the body of response.  Optionally
  # creates a REXML document is the URI returns XML data.
  #
  # uri:: [String] The URI to put to (http://...)
  # request:: [String] The data to post
  # format:: [Symbol=:as_string] Return format (:as_string or :as_xml)
  # return:: [String | REXML::Document] The body test returned as a String or XML document
  #
  def self.put(uri, data, username=nil, password=nil, certfile=nil, certpassword=nil, content_type="application/x-www-form-urlencoded")
    return nil if uri.nil?
    puts "CURL HTTP POST: [#{uri}]" if $COUGAAR_DEBUG
    begin
      filename = "/tmp/#{Time.now.to_i}.dat"
      puts filename
      File.open(filename, "w") {|file| file.syswrite(data) }
      result = `curl -s -L --header 'Content-Type: #{content_type}' #{gen_auth(username, password)} #{gen_cert(certfile, certpassword)} '#{uri}' -T #{filename}`
      File.delete(filename)
      return result
    rescue
      puts "CURL.put exception #{$!}"
      puts $!.backtrace.join("\n")
      return nil
    end    
  end
end

