#!/bin/sh
# This script creates a UL distro package of new 1AD societies.

# This script re-generates the basic 1AD and UA configurations from scratch.
# Note the dependency on a SocietyDesigner install -- which
# requires some Cougaar jars and a COUGAAR_INSTALL_PATH and Java
# It also depends on a working transform_society.rb -- so Ruby and minimal
# ACME scripting
# It also needs a zip executable

# Note that some configuration combinations may be commented out
# Also note that some configurations are generated as .rb files

ADDIR=../societies/ad

if [ ! -d $ADDIR ]; then
    mkdir $ADDIR
fi

echo "Making All the 1AD facet files for 1AD configurations"
ruby org_agent_builder.rb -d 1ad.org_data -m tiny-1ad-tc1.member.csv -s $ADDIR/tiny-1ad-tc1.facets.xml
ruby org_agent_builder.rb -d 1ad.org_data -m tiny-1ad-tc7.member.csv -s $ADDIR/tiny-1ad-tc7.facets.xml
ruby org_agent_builder.rb -d 1ad.org_data -m small-1ad-tc20.member.csv -s $ADDIR/small-1ad-tc20.facets.xml
ruby org_agent_builder.rb -d 1ad.org_data -m full-1ad-tc20.member.csv -s $ADDIR/full-1ad-tc20.facets.xml
echo "Done making 1AD facets"

echo "Sorting the rules and writing to base_rules/temp..."
./rule.sort.sh base_rules ../rules/metrics
echo "Done"

echo "Making the 1AD societies"
ruby ../bin/transform_society.rb -i $ADDIR/tiny-1ad-tc1.facets.xml -r base_rules/temp -o $ADDIR/TINY-TC1.xml
ruby ../bin/transform_society.rb -i $ADDIR/tiny-1ad-tc7.facets.xml -r base_rules/temp -o $ADDIR/TINY-TC7.xml
ruby ../bin/transform_society.rb -i $ADDIR/small-1ad-tc20.facets.xml -r base_rules/temp -o $ADDIR/SMALL-TC20.rb
ruby ../bin/transform_society.rb -i $ADDIR/full-1ad-tc20.facets.xml -r base_rules/temp -o $ADDIR/FULL-TC20.rb
echo "Done"

echo "Fix up the node names"
sed 's/localnode/1AD_TINY/' $ADDIR/TINY-TC1.xml > $ADDIR/TINY-1AD-TC1.xml
sed 's/localnode/1AD_TINY/' $ADDIR/TINY-TC7.xml > $ADDIR/TINY-1AD-TC7.xml
sed 's/localnode/SMALL_1AD/' $ADDIR/SMALL-TC20.rb > $ADDIR/SMALL-1AD-TC20.rb
sed 's/localnode/FULL_1AD/' $ADDIR/FULL-TC20.rb > $ADDIR/FULL-1AD-TC20.rb 
echo "Done"

if [ "x$1" = "x" ]; then
    # Old behavior. Just leave the zip
    echo "Create the zip package"
    rm $ADDIR/*.facets*.xml
    rm $ADDIR/TINY-TC1.xml
    rm $ADDIR/TINY-TC7.xml
    rm $ADDIR/SMALL-TC20.rb
    rm $ADDIR/FULL-TC20.rb
    zip -j $ADDIR/1ad-configs.zip $ADDIR/*.xml 
    zip -j $ADDIR/1ad-configs.zip $ADDIR/*.rb 
    echo "Done"

    echo "Clean up the mess we made"
    rm $ADDIR/*.xml
    rm $ADDIR/*.rb
else
    # Alternate behavior. Also leave the useful XML and .rb files
    echo "Clean up the mess we made"
    rm $ADDIR/*.facets*.xml
    echo "Done cleaning up"
fi

echo " ---- Done building 1AD configurations."

