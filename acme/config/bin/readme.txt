Instructions for generating the service discovery provider
profile.daml and grounding files using Ruby instead of Perl.

1) Make sure your COUGAAR_INSTALL_PATH is set.

2) ruby generateDAML.rb -i <society file> -t <template file>
The society file should be a rb or xml society file that has
the agents and facets. org_agent_builder/1ad.orig-org-id has a 
number of these xml file. The template file should be COUGAAR_INSTALL_PATH/servicediscovery/data/serviceprofiles/profile-template.txt
(You want a file with the short agent names, such as 125-FSB,
not 125-FSB.DISCOM.1-AD.ARMY.MIL)

3) You should see a number of profile.daml files written into
COUGAAR_INSTALL_PATH/servicediscovery/data/serviceprofiles and
a number of wsdl files written into
COUGAAR_INSTALL_PATH/servicediscovery/data/servicegroundings

4) These instructions can be used to replace the profile.daml generation 
instructions in the service discovery module.