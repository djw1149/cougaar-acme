#!/bin/sh
# This script creates a UL distro package of new 1AD societies.

UADIR=../societies/ua

if [ ! -d $UADIR ]; then
    mkdir $UADIR
fi

echo "Making All the 1AD facet files"
ruby org_agent_builder.rb -d 1ad.org_data -m tiny-1ad.member.csv -s $UADIR/tiny-1ad.facets.xml -o
ruby org_agent_builder.rb -d 1ad.org_data -m tiny-1ad-trans-stub.member.csv -s $UADIR/tiny-1ad-trans-stub.facets.xml -o
ruby org_agent_builder.rb -d 1ad.org_data -m small-1ad.member.csv -s $UADIR/small-1ad.facets.xml -o
ruby org_agent_builder.rb -d 1ad.org_data -m small-1ad-trans-stub.member.csv -s $UADIR/small-1ad-trans-stub.facets.xml -o
ruby org_agent_builder.rb -d 1ad.org_data -m full-1ad.member.csv -s $UADIR/full-1ad.facets.xml -o
ruby org_agent_builder.rb -d 1ad.org_data -m full-1ad-trans-stub.member.csv -s $UADIR/full-1ad-trans-stub.facets.xml -o
echo "Done making facets"

echo "Merge the 1AD and UA facet files"
../../bin/SocietyMerger $UADIR/tiny-1ad-trans-stub.facets.xml ./1ua/17a12v.facets.xml $UADIR/tiny-trans-stub-17a12v.facets.xml

../../bin/SocietyMerger $UADIR/tiny-1ad.facets.xml ./1ua/17a12v.facets.xml $UADIR/tiny-17a12v.facets.xml

../../bin/SocietyMerger $UADIR/tiny-1ad-trans-stub.facets.xml ./1ua/160a237v.facets.xml $UADIR/tiny-trans-stub-160a237v.facets.xml

../../bin/SocietyMerger $UADIR/tiny-1ad.facets.xml ./1ua/160a237v.facets.xml $UADIR/tiny-160a237v.facets.xml

../../bin/SocietyMerger $UADIR/small-1ad-trans-stub.facets.xml ./1ua/17a12v.facets.xml $UADIR/small-trans-stub-17a12v.facets.xml

../../bin/SocietyMerger $UADIR/small-1ad.facets.xml ./1ua/17a12v.facets.xml $UADIR/small-11a12v.facets.xml

../../bin/SocietyMerger $UADIR/small-1ad-trans-stub.facets.xml ./1ua/160a237v.facets.xml $UADIR/small-trans-stub-160a237v.facets.xml

../../bin/SocietyMerger $UADIR/small-1ad.facets.xml ./1ua/160a237v.facets.xml $UADIR/small-160a237v.facets.xml

../../bin/SocietyMerger $UADIR/full-1ad-trans-stub.facets.xml ./1ua/160a237v.facets.xml $UADIR/full-trans-stub-160a237v.facets.xml
../../bin/SocietyMerger $UADIR/full-1ad.facets.xml ./1ua/160a237v.facets.xml $UADIR/full-160a237v.facets.xml
echo "Done"

echo "Sorting the rules and writing to base_rules/temp..."
./rule.sort.sh base_rules ../rules/metrics
echo "Done"

echo "Making the societies"
ruby ../bin/transform_society.rb -i $UADIR/tiny-trans-stub-17a12v.facets.xml -r base_rules/temp -o $UADIR/tiny-trans-stub-17a12v.plugins.xml

ruby ../bin/transform_society.rb -i $UADIR/tiny-17a12v.facets.xml -r base_rules/temp -o $UADIR/tiny-17a12v.plugins.xml

ruby ../bin/transform_society.rb -i $UADIR/tiny-trans-stub-160a237v.facets.xml -r base_rules/temp -o $UADIR/tiny-trans-stub-160a237v.plugins.xml

ruby ../bin/transform_society.rb -i $UADIR/tiny-160a237v.facets.xml -r base_rules/temp -o $UADIR/tiny-160a237v.plugins.xml

ruby ../bin/transform_society.rb -i $UADIR/small-17a12v.facets.xml -r base_rules/temp -o $UADIR/small-17a12v.plugins.xml

ruby ../bin/transform_society.rb -i $UADIR/small-trans-stub-17a12v.facets.xml -r base_rules/temp -o $UADIR/small-trans-stub-17a12v.plugins.xml

ruby ../bin/transform_society.rb -i $UADIR/small-160a237v.facets.xml -r base_rules/temp -o $UADIR/small-160a237v.plugins.xml

ruby ../bin/transform_society.rb -i $UADIR/small-trans-stub-160a237v.facets.xml -r base_rules/temp -o $UADIR/small-trans-stub-160a237v.plugins.xml

ruby ../bin/transform_society.rb -i $UADIR/full-160a237v.facets.xml -r base_rules/temp -o $UADIR/full-160a237v.plugins.xml

ruby ../bin/transform_society.rb -i $UADIR/full-trans-stub-160a237v.facets.xml -r base_rules/temp -o $UADIR/full-trans-stub-160a237v.plugins.xml
echo "Done"

echo "Create the zip package"
zip -j $UADIR/ua-configs.zip $UADIR/*plugins*.xml 
echo "Done"

echo "Clean up the mess we made"
rm $UADIR/*.xml
echo "Done cleaning up"
