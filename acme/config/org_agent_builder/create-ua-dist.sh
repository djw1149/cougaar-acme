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

ADFACETS=1ad.facets/
UAFACETS=1ua.facets/
UADIR=../societies/ua

if [ ! -d $UADIR ]; then
    mkdir $UADIR
fi

echo "Merge the 1AD and UA facet files"
../../bin/SocietyMerger.sh $ADFACETS/tiny-1ad-tc1.facets.xml $UAFACETS/17a12v.facets.xml $UADIR/tiny-tc1-17a12v.facets.xml
../../bin/SocietyMerger.sh $ADFACETS/tiny-1ad-tc7.facets.xml $UAFACETS/17a12v.facets.xml $UADIR/tiny-tc7-17a12v.facets.xml
../../bin/SocietyMerger.sh $ADFACETS/small-1ad-tc20.facets.xml $UAFACETS/17a12v.facets.xml $UADIR/small-tc20-17a12v.facets.xml
../../bin/SocietyMerger.sh $ADFACETS/full-1ad-tc20.facets.xml $UAFACETS/160a147v.facets.xml $UADIR/full-tc20-160a147v.facets.xml
../../bin/SocietyMerger.sh $ADFACETS/full-1ad-tc20.facets.xml $UAFACETS/160a208v.facets.xml $UADIR/full-tc20-160a208v.facets.xml
echo "Done"

echo "Sorting the rules and writing to base_rules/temp..."
./rule.sort.sh base_rules ../rules/metrics
echo "Done"

echo "Making the UA societies"
ruby ../bin/transform_society.rb -i $UADIR/tiny-tc1-17a12v.facets.xml -r base_rules/temp -o $UADIR/tiny-tc1-17a12v.plugins.xml

ruby ../bin/transform_society.rb -i $UADIR/tiny-tc7-17a12v.facets.xml -r base_rules/temp -o $UADIR/tiny-tc7-17a12v.plugins.xml

ruby ../bin/transform_society.rb -i $UADIR/small-tc20-17a12v.facets.xml -r base_rules/temp -o $UADIR/small-tc20-17a12v.plugins.rb

ruby ../bin/transform_society.rb -i $UADIR/full-tc20-160a147v.facets.xml -r base_rules/temp -o $UADIR/full-tc-20-160a147v.plugins.rb

ruby ../bin/transform_society.rb -i $UADIR/full-tc20-160a208v.facets.xml -r base_rules/temp -o $UADIR/full-tc-20-160a208v.plugins.rb
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
