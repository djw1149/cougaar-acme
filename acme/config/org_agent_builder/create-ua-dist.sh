#!/bin/sh
# This script creates a UL distro package of new 1AD societies.

# This script re-generates the basic 1AD and UA configurations from scratch.
# Note the dependency on a SocietyDesigner install -- which
# requires some Cougaar jars and a COUGAAR_INSTALL_PATH and Java
# It also depends on a working transform_society.rb -- so Ruby and minimal
# ACME scripting
# It also needs a zip executable

# Note that most configuration combinations are commented out
# Also note that some configurations are generated as .rb files

UADIR=../societies/ua

if [ ! -d $UADIR ]; then
    mkdir $UADIR
fi

echo "Making All the 1AD facet files for UA configurations"
ruby org_agent_builder.rb -d 1ad.org_data -m tiny-1ad.member.csv -s $UADIR/tiny-1ad.facets.xml -o
ruby org_agent_builder.rb -d 1ad.org_data -m tiny-1ad-trans-stub.member.csv -s $UADIR/tiny-1ad-trans-stub.facets.xml -o
ruby org_agent_builder.rb -d 1ad.org_data -m small-1ad.member.csv -s $UADIR/small-1ad.facets.xml -o
#ruby org_agent_builder.rb -d 1ad.org_data -m small-1ad-trans-stub.member.csv -s $UADIR/small-1ad-trans-stub.facets.xml -o
ruby org_agent_builder.rb -d 1ad.org_data -m full-1ad.member.csv -s $UADIR/full-1ad.facets.xml -o
#ruby org_agent_builder.rb -d 1ad.org_data -m full-1ad-trans-stub.member.csv -s $UADIR/full-1ad-trans-stub.facets.xml -o
echo "Done making 1AD facets"

echo "Merge the 1AD and UA facet files"
../../bin/SocietyMerger.sh $UADIR/tiny-1ad-trans-stub.facets.xml ./1ua/17a12v.facets.xml $UADIR/tiny-trans-stub-17a12v.facets.xml

../../bin/SocietyMerger.sh $UADIR/tiny-1ad.facets.xml ./1ua/17a12v.facets.xml $UADIR/tiny-17a12v.facets.xml

#../../bin/SocietyMerger.sh $UADIR/tiny-1ad-trans-stub.facets.xml ./1ua/160a237v.facets.xml $UADIR/tiny-trans-stub-160a237v.facets.xml

#../../bin/SocietyMerger.sh $UADIR/tiny-1ad.facets.xml ./1ua/160a237v.facets.xml $UADIR/tiny-160a237v.facets.xml

#../../bin/SocietyMerger.sh $UADIR/small-1ad-trans-stub.facets.xml ./1ua/17a12v.facets.xml $UADIR/small-trans-stub-17a12v.facets.xml

../../bin/SocietyMerger.sh $UADIR/small-1ad.facets.xml ./1ua/17a12v.facets.xml $UADIR/small-17a12v.facets.xml

#../../bin/SocietyMerger.sh $UADIR/small-1ad-trans-stub.facets.xml ./1ua/160a237v.facets.xml $UADIR/small-trans-stub-160a237v.facets.xml

#../../bin/SocietyMerger.sh $UADIR/small-1ad.facets.xml ./1ua/160a237v.facets.xml $UADIR/small-160a237v.facets.xml

#../../bin/SocietyMerger.sh $UADIR/full-1ad-trans-stub.facets.xml ./1ua/160a237v.facets.xml $UADIR/full-trans-stub-160a237v.facets.xml
../../bin/SocietyMerger.sh $UADIR/full-1ad.facets.xml ./1ua/160a237v.facets.xml $UADIR/full-160a237v.facets.xml
echo "Done"

echo "Sorting the rules and writing to base_rules/temp..."
./rule.sort.sh base_rules ../rules/metrics
echo "Done"

echo "Making the UA societies"
ruby ../bin/transform_society.rb -i $UADIR/tiny-trans-stub-17a12v.facets.xml -r base_rules/temp -o $UADIR/tiny-trans-stub-17a12v.plugins.xml

ruby ../bin/transform_society.rb -i $UADIR/tiny-17a12v.facets.xml -r base_rules/temp -o $UADIR/tiny-17a12v.plugins.xml

#ruby ../bin/transform_society.rb -i $UADIR/tiny-trans-stub-160a237v.facets.xml -r base_rules/temp -o $UADIR/tiny-trans-stub-160a237v.plugins.xml

#ruby ../bin/transform_society.rb -i $UADIR/tiny-160a237v.facets.xml -r base_rules/temp -o $UADIR/tiny-160a237v.plugins.xml

ruby ../bin/transform_society.rb -i $UADIR/small-17a12v.facets.xml -r base_rules/temp -o $UADIR/small-17a12v.plugins.rb

#ruby ../bin/transform_society.rb -i $UADIR/small-trans-stub-17a12v.facets.xml -r base_rules/temp -o $UADIR/small-trans-stub-17a12v.plugins.xml

#ruby ../bin/transform_society.rb -i $UADIR/small-160a237v.facets.xml -r base_rules/temp -o $UADIR/small-160a237v.plugins.xml

#ruby ../bin/transform_society.rb -i $UADIR/small-trans-stub-160a237v.facets.xml -r base_rules/temp -o $UADIR/small-trans-stub-160a237v.plugins.xml

ruby ../bin/transform_society.rb -i $UADIR/full-160a237v.facets.xml -r base_rules/temp -o $UADIR/full-160a237v.plugins.rb

#ruby ../bin/transform_society.rb -i $UADIR/full-trans-stub-160a237v.facets.xml -r base_rules/temp -o $UADIR/full-trans-stub-160a237v.plugins.xml
echo "Done"

if [ "x$1" = "x" ]; then
    # Old behavior. Just leave the zip
    echo "Create the UA zip package"
    zip -j $UADIR/ua-configs.zip $UADIR/*plugins*.xml 
    zip -j $UADIR/ua-configs.zip $UADIR/*plugins*.rb
    echo "Done"

    echo "Clean up the mess we made"
    rm $UADIR/*.xml
    rm $UADIR/*.rb
    echo "Done cleaning up"
else
    # Alternate behavior. Also leave the useful XML and .rb files
    echo "Clean up the mess we made"
    rm $ADDIR/*.facets*.xml
    echo "Done cleaning up"
fi

echo " ---- Done building UA configurations"
