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
#  TORTIOUS CONDUCT, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
#  PERFORMANCE OF THE COUGAAR SOFTWARE.
# </copyright>
#

require 'mysql'

module Cougaar
  module CSmart

    ##
    # The CSmart::Database class wraps access to the CSmart MySQL database
    # and allows building a model for a defined experiment.
    # 
    # Usage:
    #   csmart = CSmart::Database.connect("localhost", "ultralog", "password", "csmart")
    #   csmart.each_experiment do |experiment|
    #      society = csmart.build_society(experiment) if experiment.name=="TINY-1AD-EXP-1"
    #   end
    #   csmart.close
    #
    class Database
      SOCIETY = 0
      HOST = 1
      NODE = 2
      AGENT = 3  
      attr_reader :host, :username, :database, :experiments
      
      ##
      # Constructs a CSmart::Database by connecting and loading the
      # available experiments.
      #
      # host:: [String] The host name of the computer running MySQL
      # username:: [String] The username for the experiment database
      # password:: [String] The password for the experiment database
      # database:: [String] The name of the experiment database
      #
      def initialize(host, username, password, database)
        @host = host
        @username = username
        @password = password
        @database = database
        @mysql = Mysql.new(@host, @username, @password, @database)
        load_experiments
        load_component_index
      end
      
      ##
      # Alias to CSmart::Database.new(host, username, password, database)
      #
      def self.connect(host, username, password, database)
        return Database.new(host, username, password, database)
      end
      
      ##
      # Closed the database.  This is required before exiting Ruby.
      # Release is an alias to this method
      #
      def close
        @mysql.close
        @mysql = nil
        @experiments = nil
      end
      alias_method :release, :close
      
      ##
      # Iterates over definded experiments
      #
      # yield:: [Cougaar::CSmart::Experiment] Experiment instance
      #
      def each_experiment
        @experiments.each {|exp| yield exp}
      end
      
      ##
      # Builds an society model for the supplied experiment
      #
      # experiment:: [Cougaar::CSmart::Database::Experiment | String] The name or experiment instance to build the society from
      # return:: [Cougaar::Model::Society] The society instance
      #
      def build_society(experiment)
        if experiment.kind_of? String
          @experiments.each {|exp| experiment = exp if exp.name==experiment}
          raise "Invalid Experiment Name: #{experiment}" if experiment.kind_of? String
        end
        
        q = @mysql.query("select * from expt_trial_assembly where TRIAL_ID='#{experiment.trial_id}' and DESCRIPTION='CSHNA assembly'")
        assembly_id = nil
        q.each do |row|
          assembly_id = row[1]
        end
        list = [ [], [], [], [] ]
        q = @mysql.query("select COMPONENT_ALIB_ID, PARENT_COMPONENT_ALIB_ID from asb_component_hierarchy where ASSEMBLY_ID='#{assembly_id}'")
        q.each do |row|
          list[@component_index[row[0]]] << row
        end
        
        society_id = list[HOST][0][1]
        
        global_parameters = []
        q = @mysql.query("select * from asb_component_arg where ASSEMBLY_ID='#{assembly_id}' and COMPONENT_ALIB_ID='#{society_id}'")
        q.each do |row|
          global_parameters << row[2] if row[2][0..1]=="-D"
        end
        
        society = Cougaar::Model::Society.new
        
        list[HOST].each do |set|
          society.add_host(set[0])
        end
        list[NODE].each do |set|
          host = society.hosts[set[1]]
          next unless host
          node = host.add_node(set[0])
          node.add_parameter(global_parameters)
          q = @mysql.query("select * from asb_component_arg where ASSEMBLY_ID='#{assembly_id}' and COMPONENT_ALIB_ID='#{node.name}'")
          q.each do |row|
            node.add_parameter(row[2]) if row[2][0..1]=="-D"
          end
        end
        list[AGENT].each do |set|
          society.nodes[set[1]].add_agent(set[0])
        end
        return society
      end
      
      private
      
      def load_component_index
        @component_index = {}
        q = @mysql.query("select COMPONENT_ALIB_ID from alib_component where COMPONENT_TYPE='society'")
        q.each {|row| @component_index[row[0]]=SOCIETY}
        q = @mysql.query("select COMPONENT_ALIB_ID from alib_component where COMPONENT_TYPE='host'")
        q.each {|row| @component_index[row[0]]=HOST}
        q = @mysql.query("select COMPONENT_ALIB_ID from alib_component where COMPONENT_TYPE='node'")
        q.each {|row| @component_index[row[0]]=NODE}
        q = @mysql.query("select COMPONENT_ALIB_ID from alib_component where COMPONENT_TYPE='agent'")
        q.each {|row| @component_index[row[0]]=AGENT}  
      end
      
      def load_experiments
        @experiments = []
        q = @mysql.query <<-QUERY 
          select expt_trial.TRIAL_ID, expt_trial.EXPT_ID, 
                 expt_experiment.DESCRIPTION, expt_experiment.NAME 
          from expt_trial 
          inner join expt_experiment
          on (expt_trial.EXPT_ID=expt_experiment.EXPT_ID)
        QUERY
        q.each do |row|
          @experiments << Experiment.new(*row) if row[1][0..4]=="EXPT-"
        end
      end
    end # Database

    ##
    # The experiment class holds metadata about each csmart experiment
    #
    class Experiment
      attr_accessor :trial_id, :expt_id, :description, :name
      
      ##
      # Constructs the experiment instance
      #
      # trial_id:: [String] The experiment trial id
      # expt_id:: [String] The experiment id
      # description:: [String] The textual description of the experiment
      # name:: [String] The name of the experiment
      #
      def initialize(trial_id, expt_id, description, name)
        @trial_id = trial_id
        @expt_id = expt_id
        @description = description
        @name = name
      end
      
      ##
      # Override Object#to_s
      #
      def to_s
        "Experiment: #{@name} (#{@description}) EXPT_ID: #{@expt_id} TRIAL_ID: #{trial_id}"
      end
    end # Experiment
    
  end # CSmart
end # Cougaar

module Cougaar
  module Actions
    class LoadSocietyFromCSmart < Cougaar::Action
      RESULTANT_STATE = "SocietyLoaded"
      def to_s
        return super.to_s + "('#{@csmart_experiment}', '#{@csmart_host}', '#{@csmart_username}', '#{@csmart_pwd}', '#{@csmart_db}')"
      end
      def initialize(run, experiment_name, host, username, pwd, db)
        super(run)
        @csmart_experiment = experiment_name
        @csmart_host = host
        @csmart_username = username
        @csmart_pwd = pwd
        @csmart_db = db
      end
      def perform
        begin
          csmart = CSmart::Database.connect(@csmart_host, @csmart_username, @csmart_pwd, @csmart_db)
        rescue
          raise_failure "Could not connect to CSmart: #{@csmart_username}:#{@csmart_pwd}@#{@csmart_host}/#{@csmart_db}", $!
        end
        society = nil
        csmart.each_experiment do |expt|
          society = csmart.build_society(@csmart_experiment) if expt.name==@csmart_experiment
        end
        unless society
          raise_failure "Could not locate CSmart experiment: #{@csmart_experiment}"
        end
        @run.society = society
				@run["loader"] = "DB"
      end
    end
  end
end

