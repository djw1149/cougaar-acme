##
#  <copyright>
#  Copyright 2002 S/TDC (System/Technology Devlopment Corporation)
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
#  TORTIOUS CONDUCT, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
#  PERFORMANCE OF THE COUGAAR SOFTWARE.
# </copyright>
#


module Cougaar
  module Actions
    class EditOPlan < Cougaar::Action
      PRIOR_STATES = ["SocietyRunning"]
      RESULTANT_STATE = 'SocietyPlanning'
      DOCUMENTATION = Cougaar.document {
        @description = "Edit and resend the OPlan."
        @block_yields = [
          {:oplan => "The OPlan edit control class (UltraLog::OPlan)."}
        ]
        @example = "
          do_action 'EditOPlan' do |oplan|
            org = oplan['109-MDM-TRKCO']
            org['DEPLOYMENT'].save(nil, nil, '=85')
            oplan.update
          end
        "
      }
      def initialize(run, &block)
        super(run)
        @action = block
      end
      def perform
        @action.call(::UltraLog::OPlan.from_society(@run.society))
      end
    end
  end
end

require 'uri'
require 'net/http'
require 'cougaar/communications'

module UltraLog

  #
  # Wraps the OPLAN EDIT  servlet
  #
    ##
    # Class to hold the oplan data provided by editOplan servlet.
    #
    class OPlan
        attr_reader :organizations, :host, :port, :uri_frag

        ##
        # Constructs an Oplan from host, port and url provided.
        # port (default=8800) and url ($NCA/editOplan) are optional.
        #
        # host:: [String] Host name
        # port:: [String] Port to connect to
        # url_frag:: [String] URL of editOplan servlet
        #
        def initialize(host, port=8800, uri_frag="$NCA/editOplan") 
            @host = host
            @port = port
            @uri_frag = uri_frag
            get_data
        end
        
        def self.from_society(society)
          OPlan.new(society.agents['NCA'].node.host.host_name)
        end
        
      private

        ##
        # Populates the oplan created by parsing the return page from oplan servlet.
        #
        def get_data 
            re0 = /\<td\>(.+)\<\/td\>/
            re1 = /.*href=\"(.+)\">(\S+).*/
            #puts "host=#{@host} port=#{@port}"
            result,uri = Cougaar::Communications::HTTP.get("http://#{@host}:#{@port}/#{@uri_frag}")
            @host = uri.host
            @port = uri.port
            #puts "new_host=#{@host} new_port=#{@port}"
            array = []
            result.each_line {|line| array << line.strip}
            result = array.join("\n")
            start = result.index("</tr>\n</tr>\n")
            stop = result.index("</table>")
            result = result[(start+12)...stop]
            result = result.split("</tr>\n")
            @organizations = {}
            
            result.each do |org_data|
                org_name = re0.match(org_data)[1]
                org = OrganizationData.new(self, org_name)
                org_activity_data = org_data.scan(re1)

                activity_list = []
                org_activity_data.each do |item|
                    activity_list << OrgActivity.new(org, *item) 
                end

                if activity_list.size==3
                    t = activity_list.pop
                    activity_list.push nil
                    activity_list.push t
                end

                org.org_activities = activity_list
                @organizations[org_name] = org
            end
 
#            print_detail_all

        end

      public

        ##
        # Returns OrganizationData for given organization.
        #
        # org:: [String] Name of organization
        #
        def [](org)
            return @organizations[org]
        end

        ##
        # Publish the modified oplan.
        #
        def publish
            result,uri = Cougaar::Communications::HTTP.get("http://#{@host}:#{@port}/#{@uri_frag}?action=Publish")
        end

        ##
        # Print OrganizationData for all the organizations.
        #
        def print_detail_all
            @organizations.each do |key, value| 
                print "Agent : ", key, "\n"
                activities = value.org_activities
                activities.each do |activity|
                    if activity != nil
                        print "    ", "Activity : ", activity.name, "\n"
                        print "        URL: ", activity.url_fragment, "\n"
                    end
                end
            end
        end

        ##
        # Print OrganizationData for given organizations.
        #
        # org_name:: [String] Name of organization
        #
        def print_detail(org_name)
            org = @organizations[org_name]
            print "Agent : ", org.org_name, "\n"
            activities = org.org_activities
            activities.each do |activity|
                if activity != nil
                    print "    Activity : ", activity.name, "\n"
                    print "        URL: ", activity.url_fragment, "\n"
                    print "        OP_TEMPO: ", activity.op_tempo, "  "
                    print "        START_OFFSET: ", activity.start_offset, "  "
                    print "        END_OFFSET: ", activity.end_offset, "\n"
                end
            end
        end
    end

    ##
    # Class to hold the organization data required by editOplan servlet.
    #
    class OrganizationData
        attr_reader :oplan
        attr_accessor :org_name, :org_activities

        ##
        # Constructs a OrganizationData from org name and oplan provided.
        #
        # oplan:: [Cougaar::Oplan] Reference to oplan object
        # org:: [String] Name of the organization
        #
        def initialize(oplan, org)
            @oplan = oplan
            @org_name = org
        end

      public

        ##
        # Return the OrganizationData for requested key.
        #
        # key:: [Integer | String] Key can be interger index or a name of activity
        #
        def [](key)
            if key.kind_of?(Integer)
                result = @org_activities[key]
            else
                result =  @org_activities[0] if key == "Deployment"
                result =  @org_activities[1] if key == "Employment-Defensive"
                result =  @org_activities[2] if key == "Employment-Offensive"
                result =  @org_activities[3] if key == "Stand-Down"
            end
            return result
        end

    end

    ##
    # Class to hold the org activity data required by editOplan servlet.
    #
    class OrgActivity
        attr_reader :organization, :name, :url_fragment
        attr_accessor :start_offset, :end_offset, :op_tempo
        @@valid_optempo = { "Low" => nil, "Medium" => nil, "High" => nil }

        ##
        # Constructs a OrgActivity from OrganizationData, name of activity and url provided.
        #
        # org:: [Cougaar::OrganizationData] Reference to OrganizationData object
        # url_frag:: [String] URL to modify this org activity
        # org:: [String] Name of the org activity
        #
        def initialize(org, url_frag, name)
            @organization = org
            @url_fragment = url_frag
            @name = name
        end
        
      public

        ##
        # Checks whether the optempo is valid?
        #
        # op_tempo:: [String] optempo value to be checked
        #
        def OrgActivity.is_optempo_valid? (op_tempo)
            return @@valid_optempo.has_key?(op_tempo)
        end

        ##
        # Modify optempo, start_offset, end_offset for a org activity.
        # Any of these values can be nil, in which case that input is not changed
        # For start_offset and end_offset one can specify increment or decrement
        # by specifying positive or negative value.
        # If one wants to set it to a value passed then you will have to prepend it by "="
        # e.g. "=20" will set value to +20, while "20" will increment the value by +20.
        #
        # op_tempo:: [String] new optempo
        # start_offset:: [Integer] | String] new start_offset
        # end_offset:: [Integer | String] new end_offset
        #
        def save (op_tempo, start_offset, end_offset)
            host = @organization.oplan.host
            port = @organization.oplan.port

            unless op_tempo == nil
                unless OrgActivity.is_optempo_valid?(op_tempo)
                    puts "#{op_tempo} not a valid op_tempo, will not be set"
                    op_tempo = nil
                end
            end

            result,uri = Cougaar::Communications::HTTP.get("http://#{host}:#{port}#{@url_fragment}")
            array = []
            result.each_line {|line| array << line.strip}
            result = array.join("\n")
            
            re0 = /<form method=\"(\w+)\" action=\"(.*)\">/
            re0_result = re0.match(result)
            form_method = re0_result[1]
            form_action = re0_result[2]
#            puts "Form params method=#{form_method} action=#{form_action}"
            
            re1 = /<input type=\"hidden\" name=\"(.*)\" value=\"(.*)\">/
            re1_result = re1.match(result)
            hidden_args= {}
            result.each do |line|
                arg = line.scan(re1)
                arg.each do |item|
                    hidden_args[item[0]] = item[1]
                end
             end
            #puts "Hidden Arguments"
            #hidden_args.each {|key, value| print key, "=", value, "\n" }
            
            re2 = /<option .* selected>(.*)<\/option>/
            @op_tempo = re2.match(result)[1]

            re3 = /<input.*name=\"start_offset\" value=\"(\d*)\".*>/
            @start_offset = re3.match(result)[1].to_i

            re4 = /<input.*name=\"end_offset\" value=\"(\d*)\".*>/
            @end_offset = re4.match(result)[1].to_i
#            puts "ORG OP_TEMPO = #{@op_tempo} START = #{@start_offset} END = #{@end_offset}"

            if ( op_tempo != nil )
               @op_tempo = op_tempo
            end
            if ( start_offset != nil )
                unless start_offset.kind_of?(Integer)
                    start_value = start_offset.scan(/[+,-]?\d+/)
                    #puts "StartOffset val #{start_value}"
                    if start_offset =~ /^=.*/ then @start_offset = start_value[0].to_i 
                    else @start_offset += start_value[0].to_i
                    end
                else
                    @start_offset += start_offset
                end
            end
            if ( end_offset != nil )
                unless end_offset.kind_of?(Integer)
                    end_value = end_offset.scan(/[+,-]?\d+/)
                    #puts "EndOffset op #{end_offset[0]} val #{end_value}"
                    if end_offset =~ /^=.*/ then @end_offset = end_value[0].to_i 
                    else @end_offset += end_value[0].to_i
                    end
                else
                    @end_offset += end_offset
                end
            end
#            puts "NEW OP_TEMPO = #{@op_tempo} START = #{@start_offset} END = #{@end_offset}"

            form_action_uri =  "http://#{host}:#{port}#{form_action}?"
            hidden_args.each do |key, value| 
                form_action_uri += "#{key}=#{value}&"
            end
            form_action_uri += "optempo=#{@op_tempo}&start_offset=#{@start_offset}&end_offset=#{@end_offset}"
#            puts "FORM URI #{form_action_uri}"
            form_result, uri = Cougaar::Communications::HTTP.get(form_action_uri)
#            puts form_result
        end	  
    end
     
end


if __FILE__ == $0
    oplan = UltraLog::OPlan.new('u192')
    #org = oplan["1-35-ARBN"]
    #org["Employment-Defensive"].save("High", nil , nil )
    org = oplan["109-MDM-TRKCO"]
    org["Deployment"].save(nil, nil , "=85" )
    oplan.publish
end
