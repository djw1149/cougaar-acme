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
ruby org_agent_builder.rb -d 1ad.org_data -m tiny-1ad.member.csv -s $ADDIR/tiny-1ad.facets.xml -o
ruby org_agent_builder.rb -d 1ad.org_data -m tiny-1ad-trans-stub.member.csv -s $ADDIR/tiny-1ad-trans-stub.facets.xml -o
ruby org_agent_builder.rb -d 1ad.org_data -m small-1ad.member.csv -s $ADDIR/small-1ad.facets.xml -o
#ruby org_agent_builder.rb -d 1ad.org_data -m small-1ad-trans-stub.member.csv -s $ADDIR/small-1ad-trans-stub.facets.xml -o
ruby org_agent_builder.rb -d 1ad.org_data -m small-1ad.member.csv -s $ADDIR/small-1ad.facets.ammo.xml -o -x13P9
ruby org_agent_builder.rb -d 1ad.org_data -m full-1ad.member.csv -s $ADDIR/full-1ad.facets.xml -o
#ruby org_agent_builder.rb -d 1ad.org_data -m full-1ad-trans-stub.member.csv -s $ADDIR/full-1ad-trans-stub.facets.xml -o
echo "Done making 1AD facets"

echo "Sorting the rules and writing to base_rules/temp..."
./rule.sort.sh base_rules ../rules/metrics
echo "Done"

echo "Making the 1AD societies"
ruby ../bin/transform_society.rb -i $ADDIR/tiny-1ad.facets.xml -r base_rules/temp -o $ADDIR/TINY-TRANS.xml
ruby ../bin/transform_society.rb -i $ADDIR/tiny-1ad-trans-stub.facets.xml -r base_rules/temp -o $ADDIR/TINY-TRANS-STUB.xml
ruby ../bin/transform_society.rb -i $ADDIR/small-1ad.facets.xml -r base_rules/temp -o $ADDIR/SMALL-TRANS.rb
#ruby ../bin/transform_society.rb -i $ADDIR/small-1ad-trans-stub.facets.xml -r base_rules/temp -o $ADDIR/SMALL-TRANS-STUB.rb
ruby ../bin/transform_society.rb -i $ADDIR/small-1ad.facets.ammo.xml -r base_rules/temp -o $ADDIR/SMALL-TRANS-AMMO.rb
ruby ../bin/convert_society.rb -i $ADDIR/SMALL-TRANS-AMMO.rb -o $ADDIR/SMALL-TRANS-AMMO.xml
ruby ../bin/transform_society.rb -i $ADDIR/full-1ad.facets.xml -r base_rules/temp -o $ADDIR/FULL-TRANS.rb
#ruby ../bin/transform_society.rb -i $ADDIR/full-1ad-trans-stub.facets.xml -r base_rules/temp -o $ADDIR/FULL-TRANS-STUB.rb
echo "Done"

echo "Fix up the node names"
sed 's/localnode/1AD_TINY/' $ADDIR/TINY-TRANS.xml > $ADDIR/TINY-1AD-TRANS-1359.xml
sed 's/localnode/1AD_TINY/' $ADDIR/TINY-TRANS-STUB.xml > $ADDIR/TINY-1AD-TRANS-STUB-1359.xml
sed 's/localnode/SMALL_1AD/' $ADDIR/SMALL-TRANS.rb > $ADDIR/SMALL-1AD-TRANS-1359.rb
#sed 's/localnode/SMALL_1AD/' $ADDIR/SMALL-TRANS-STUB.rb > $ADDIR/SMALL-1AD-TRANS-STUB-1359.rb
sed 's/localnode/SMALL_1AD/' $ADDIR/SMALL-TRANS-AMMO.xml > $ADDIR/SMALL-1AD-TRANS-5.xml
sed 's/localnode/SMALL_1AD/' $ADDIR/SMALL-TRANS-AMMO.rb > $ADDIR/SMALL-1AD-TRANS-5.rb
sed 's/localnode/FULL_1AD/' $ADDIR/FULL-TRANS.rb > $ADDIR/FULL-1AD-TRANS-1359.rb
#sed 's/localnode/FULL_1AD/' $ADDIR/FULL-TRANS-STUB.rb > $ADDIR/FULL-1AD-TRANS-STUB-1359.rb
echo "Done"

if [ "x$1" = "x" ]; then
    # Old behavior. Just leave the zip
    echo "Create the zip package"
    zip -j $ADDIR/1ad-configs.zip $ADDIR/*-*5*.xml 
    zip -j $ADDIR/1ad-configs.zip $ADDIR/*-*5*.rb 
    echo "Done"

    echo "Clean up the mess we made"
    rm $ADDIR/*.xml
    rm $ADDIR/*.rb
else
    # Alternate behavior. Also leave the useful XML and .rb files
    echo "Clean up the mess we made"
    rm $ADDIR/*.facets*.xml
    rm $ADDIR/*AMMO.xml
    rm $ADDIR/*AMMO.rb
    rm $ADDIR/*TRANS.xml
    rm $ADDIR/*TRANS.rb
    rm $ADDIR/*TRANS-STUB.xml
    rm $ADDIR/*TRANS-STUB.rb
    echo "Done cleaning up"
fi

echo " ---- Done building 1AD configurations."

