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

class DumpDB
  attr_reader :host, :username, :database, :experiment
  
  def initialize(host, username, password, database, experiment)
    @host = host
    @username = username
    @password = password
    @database = database
    experiment_name = experiment
    @mysql = Mysql.new(@host, @username, @password, @database)
    q = @mysql.query("select trial_id from expt_trial where NAME='#{experiment_name}'")
    q.each do |row|
      @experiment = row[0]
    end
    dump
  end
    
  ##
  # Closed the database.  This is required before exiting Ruby.
  # Release is an alias to this method
  #
  def close
    @mysql.close
    @mysql = nil
  end
  alias_method :release, :close
    
  def dump
    q = @mysql.query("select * from expt_trial_assembly where TRIAL_ID='#{@experiment}' and DESCRIPTION='CSHNA assembly'")
    assembly_id = nil
    q.each do |row|
      assembly_id = row[1]
    end

    society_id = nil
    q = @mysql.query("select COMPONENT_ALIB_ID, PARENT_COMPONENT_ALIB_ID from asb_component_hierarchy where ASSEMBLY_ID='#{assembly_id}' and PARENT_COMPONENT_ALIB_ID like 'society|%'")
    q.each do |row|
      society_id = row[1]
    end

    assemblies = []
    q = @mysql.query("SELECT ASSEMBLY_ID FROM expt_trial_assembly WHERE TRIAL_ID = '#{@experiment}'")
    q.each do |row|
      assemblies << "'"+row[0]+"'"
    end
    assembly_list = "("+assemblies.join(",") + ")"

    $outstr.printf("<?xml version=\"1.0\"?>\n\n")

    $outstr.printf("<society name='%s'\n", society_id.split("|")[1])
    $outstr.printf("  xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"\n")
    $outstr.printf("  xsi:noNamespaceSchemaLocation=\"http://www.cougaar.org/2003/society.xsd\">\n")
    node_q = @mysql.query("select COMPONENT_ALIB_ID, PARENT_COMPONENT_ALIB_ID from asb_component_hierarchy where ASSEMBLY_ID='#{assembly_id}' and PARENT_COMPONENT_ALIB_ID like 'host|%' ORDER BY PARENT_COMPONENT_ALIB_ID")
    last_host = nil
    node_q.each do |row|
      host = row[1].split('|')[1]
      if (host != last_host)
        if (last_host)
          $outstr.printf("  </host>\n")
        end
        $outstr.printf("  <host name='%s'>\n", host)
        last_host = host
      end
      node_name = row[0]
      $outstr.printf("    <node name='%s'>\n", node_name)
      print_parameters(assembly_id, society_id, node_name);
      print_agents(node_name, assembly_list);
      #catch the node agent
      print_agent(node_name, assembly_list)
      $outstr.printf("    </node>\n")
    end
    if last_host
      $outstr.printf("  </host>\n")
    end
    $outstr.printf("</society>\n")
  end
      
  def print_parameters (assembly_id, society_id, node_name)
    parameters = []
    q = @mysql.query("select * from asb_component_arg where ASSEMBLY_ID='#{assembly_id}' and COMPONENT_ALIB_ID in ('#{society_id}', '#{node_name}')")
    q.each do |row|
      parameters << row[2] if row[2][0..1]=="-D"
    end

    parameters.each do |param|
      if (param.include? "Command$Arguments")
        $outstr.printf("      <prog_parameter>\n");
        $outstr.printf("        %s\n", param.split("=")[1]);
        $outstr.printf("      </prog_parameter>\n");
      elsif (param[0..5]=="-Denv.")
        $outstr.printf("      <env_parameter>\n");
        $outstr.printf("        %s\n", param[6..param.length]);
        $outstr.printf("      </env_parameter>\n");
      elsif (param.split("=")[0]=="-Djava.class.name")
        $outstr.printf("      <class>\n");
        $outstr.printf("        %s\n", param.split("=")[1]);
        $outstr.printf("      </class>\n");
      else
        $outstr.printf("      <vm_parameter>\n");
        $outstr.printf("        %s\n", param);
        $outstr.printf("      </vm_parameter>\n");
      end
    end
  end
      
  def print_agents (node_name, assembly_list)
    query = "SELECT A.COMPONENT_NAME COMPONENT_NAME, C.COMPONENT_CLASS COMPONENT_CLASS, A.COMPONENT_ALIB_ID "+
    "COMPONENT_ID, C.INSERTION_POINT, H.PRIORITY, H.INSERTION_ORDER INSERTION_ORDER "+
    "FROM alib_component P, asb_component_hierarchy H, alib_component A, lib_component C "+
    "WHERE H.ASSEMBLY_ID in #{assembly_list} AND A.COMPONENT_ALIB_ID = H.COMPONENT_ALIB_ID "+
    "AND P.COMPONENT_ALIB_ID = H.PARENT_COMPONENT_ALIB_ID AND C.COMPONENT_LIB_ID = A.COMPONENT_LIB_ID "+
    "AND C.INSERTION_POINT = 'Node.AgentManager.Agent' "+
    "AND P.COMPONENT_NAME = '#{node_name}' ORDER BY INSERTION_ORDER"
    q = @mysql.query(query)
    agent_class = nil;
    q.each do |row|
      agent_name = row[0]
      agent_class = row[1]
      $outstr.printf("      <agent name='%s' class='%s'>\n", agent_name, agent_class)
      print_agent(agent_name, assembly_list)
      $outstr.printf("      </agent>\n")
    end
  end

  def print_agent (agent_name, assembly_list)
    superiors = "SELECT DISTINCT SUPPORTED_COMPONENT_ALIB_ID " +
                "FROM ASB_AGENT_RELATION " +
                "WHERE SUPPORTING_COMPONENT_ALIB_ID='#{agent_name}' AND ROLE='Subordinate' " +
                "AND ASSEMBLY_ID IN #{assembly_list}"
    @mysql.query( superiors ).each do |row| 
      $outstr.printf("         <facet superior_org_id='#{row[0]}' />\n")
    end

    subordinates = "SELECT DISTINCT SUPPORTING_COMPONENT_ALIB_ID " +
                   "FROM ASB_AGENT_RELATION " +
                   "WHERE SUPPORTED_COMPONENT_ALIB_ID='#{agent_name}' AND ROLE='Subordinate' " +
                   "AND ASSEMBLY_ID IN #{assembly_list}";
    @mysql.query( subordinates ).each do |row|
      $outstr.printf("         <facet subordinate_org_id='#{row[0]}' />\n")      
    end 

    query = "SELECT A.COMPONENT_NAME COMPONENT_NAME, C.COMPONENT_CLASS COMPONENT_CLASS, "+
    "A.COMPONENT_ALIB_ID COMPONENT_ID, C.INSERTION_POINT, H.PRIORITY, H.INSERTION_ORDER INSERTION_ORDER "+
    "FROM alib_component P, asb_component_hierarchy H, alib_component A, lib_component C "+
    "WHERE H.ASSEMBLY_ID in #{assembly_list} AND A.COMPONENT_ALIB_ID = H.COMPONENT_ALIB_ID "+
    "AND P.COMPONENT_ALIB_ID = H.PARENT_COMPONENT_ALIB_ID AND C.COMPONENT_LIB_ID = A.COMPONENT_LIB_ID "+
    "AND C.INSERTION_POINT <> 'Node.AgentManager.Agent' "+
    "AND P.COMPONENT_NAME = '#{agent_name}' ORDER BY INSERTION_ORDER"
     q2 = @mysql.query(query)
     q2.each do |row|
        name = row[0]
        class_name = row[1]
        insertion_point = row[3]
        priority = row[4]
        order = row[5]
        $outstr.printf("        <component name='%s' class='%s' priority='%s' insertionpoint='%s'>\n", name, class_name, priority, insertion_point)
        print_component(name, assembly_list)
        $outstr.printf("        </component>\n")
     end
  end
      
  def print_component (component_name, assembly_list)
    query = "SELECT ARGUMENT, ARGUMENT_ORDER FROM asb_component_arg WHERE ASSEMBLY_ID in #{assembly_list}"+
    "AND COMPONENT_ALIB_ID = '#{component_name}' ORDER BY ARGUMENT_ORDER, ARGUMENT"
    #printf("\n%s\n",query);
    q3 = @mysql.query(query)
    q3.each do |row|
      arg = row[0]
      order = row[1]
      $outstr.printf("          <argument>\n")
      $outstr.printf("            %s\n", arg)
      $outstr.printf("          </argument>\n")
    end
  end
end


if $0 == __FILE__
  host = "u051"
  username = "society_config"
  password = "s0c0nfig"
  database = "CSMART102"

	experiment = []
  #experiment << "RC102A-1AD-TRANS"
  experiment << "SA-1AD-TRANS"
  
	$outstr = $stdout
	experiment.each do |exp|
		$stderr.print "Dumping #{exp}\n"
	  $outstr = open("#{exp}.xml", "w")
		DumpDB.new(host, username, password, database, exp)
		$stderr.print "DONE Dumping #{exp}\n"
	end
end

