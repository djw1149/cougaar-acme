#!/bin/sh
# This script creates a UL distro package of new 1AD societies.

ADDIR=../societies/ad

if [ ! -d $ADDIR ]; then
    mkdir $ADDIR
fi

echo "Making All the facet files"
ruby org_agent_builder.rb -d 1ad.org_data -m tiny-1ad.member.csv -s $ADDIR/tiny-1ad.oo.facets.xml -o
ruby org_agent_builder.rb -d 1ad.org_data -m tiny-1ad-trans-stub.member.csv -s $ADDIR/tiny-1ad-trans-stub.oo.facets.xml -o
ruby org_agent_builder.rb -d 1ad.org_data -m small-1ad.member.csv -s $ADDIR/small-1ad.oo.facets.xml -o
ruby org_agent_builder.rb -d 1ad.org_data -m small-1ad-trans-stub.member.csv -s $ADDIR/small-1ad-trans-stub.oo.facets.xml -o
ruby org_agent_builder.rb -d 1ad.org_data -m full-1ad.member.csv -s $ADDIR/full-1ad.oo.facets.xml -o
ruby org_agent_builder.rb -d 1ad.org_data -m full-1ad-trans-stub.member.csv -s $ADDIR/full-1ad-trans-stub.oo.facets.xml -o
echo "Done making facets"

echo "Sorting the rules and writing to base_rules/temp..."
./rule.sort.sh base_rules ../rules/metrics
echo "Done"

echo "Making the societies"
ruby ../bin/transform_society.rb -i $ADDIR/tiny-1ad.oo.facets.xml -r base_rules/temp -o $ADDIR/TINY-TRANS.xml
ruby ../bin/transform_society.rb -i $ADDIR/tiny-1ad-trans-stub.oo.facets.xml -r base_rules/temp -o $ADDIR/TINY-TRANS-STUB.xml
ruby ../bin/transform_society.rb -i $ADDIR/small-1ad.oo.facets.xml -r base_rules/temp -o $ADDIR/SMALL-TRANS.xml
ruby ../bin/transform_society.rb -i $ADDIR/small-1ad-trans-stub.oo.facets.xml -r base_rules/temp -o $ADDIR/SMALL-TRANS-STUB.xml
ruby ../bin/transform_society.rb -i $ADDIR/full-1ad.oo.facets.xml -r base_rules/temp -o $ADDIR/FULL-TRANS.xml
ruby ../bin/transform_society.rb -i $ADDIR/full-1ad-trans-stub.oo.facets.xml -r base_rules/temp -o $ADDIR/FULL-TRANS-STUB.xml
echo "Done"

echo "Fix up the node names"
sed 's/localnode/1AD_TINY/' $ADDIR/TINY-TRANS.xml > $ADDIR/TINY-1AD-TRANS-1359.xml
sed 's/localnode/1AD_TINY/' $ADDIR/TINY-TRANS-STUB.xml > $ADDIR/TINY-1AD-TRANS-STUB-1359.xml
sed 's/localnode/SMALL_1AD/' $ADDIR/SMALL-TRANS.xml > $ADDIR/SMALL-1AD-TRANS-1359.xml
sed 's/localnode/SMALL_1AD/' $ADDIR/SMALL-TRANS-STUB.xml > $ADDIR/SMALL-1AD-TRANS-STUB-1359.xml
sed 's/localnode/FULL_1AD/' $ADDIR/FULL-TRANS.xml > $ADDIR/FULL-1AD-TRANS-1359.xml
sed 's/localnode/FULL_1AD/' $ADDIR/FULL-TRANS-STUB.xml > $ADDIR/FULL-1AD-TRANS-STUB-1359.xml
echo "Done"

echo "Create the zip package"
zip -j $ADDIR/1ad-configs.zip $ADDIR/*-*5*.xml 
echo "Done"

echo "Clean up the mess we made"
rm $ADDIR/*.xml
echo "Done cleaning up"
