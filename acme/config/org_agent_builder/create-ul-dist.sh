#!/bin/sh
# This script creates a UL distro package of new 1AD societies.

ULDIR=../societies/ul

if [ ! -d $ULDIR ]; then
    mkdir $ULDIR
fi

echo "Making All the facet files"
ruby org_agent_builder.rb -d 1ad.org_data -m tiny-1ad.member.csv -s ../societies/ul/tiny-1ad.oo.facets.xml -o
ruby org_agent_builder.rb -d 1ad.org_data -m tiny-1ad-trans-stub.member.csv -s ../societies/ul/tiny-1ad-trans-stub.oo.facets.xml -o
ruby org_agent_builder.rb -d 1ad.org_data -m small-1ad.member.csv -s ../societies/ul/small-1ad.oo.facets.xml -o
ruby org_agent_builder.rb -d 1ad.org_data -m small-1ad-trans-stub.member.csv -s ../societies/ul/small-1ad-trans-stub.oo.facets.xml -o
ruby org_agent_builder.rb -d 1ad.org_data -m full-1ad.member.csv -s ../societies/ul/full-1ad.oo.facets.xml -o
ruby org_agent_builder.rb -d 1ad.org_data -m full-1ad-trans-stub.member.csv -s ../societies/ul/full-1ad-trans-stub.oo.facets.xml -o
## Currently the ammo facets is generated in the SocietyDesigner (until org_agent_builder is fixed).  So copy it.
cp ./1ad.orig-org-id/small-1ad-ammo.facets.xml ../societies/ul/
echo "Done making facets"

echo "Sorting the rules and writing to base_rules/temp..."
./rule.sort.sh base_rules ../rules/metrics
echo "Done"

echo "Making the societies"
ruby ../bin/transform_society.rb -i $ULDIR/tiny-1ad.oo.facets.xml -r base_rules/temp -o $ULDIR/TINY-TRANS.xml
ruby ../bin/transform_society.rb -i $ULDIR/tiny-1ad-trans-stub.oo.facets.xml -r base_rules/temp -o $ULDIR/TINY-TRANS-STUB.xml
ruby ../bin/transform_society.rb -i $ULDIR/small-1ad.oo.facets.xml -r base_rules/temp -o $ULDIR/SMALL-TRANS.xml
ruby ../bin/transform_society.rb -i $ULDIR/small-1ad-trans-stub.oo.facets.xml -r base_rules/temp -o $ULDIR/SMALL-TRANS-STUB.xml
ruby ../bin/transform_society.rb -i $ULDIR/small-1ad-ammo.facets.xml -r base_rules/temp -o $ULDIR/SMALL-TRANS-AMMO.xml
ruby ../bin/transform_society.rb -i $ULDIR/full-1ad.oo.facets.xml -r base_rules/temp -o $ULDIR/FULL-TRANS.xml
ruby ../bin/transform_society.rb -i $ULDIR/full-1ad-trans-stub.oo.facets.xml -r base_rules/temp -o $ULDIR/FULL-TRANS-STUB.xml
echo "Done"

echo "Fix up the node names"
sed 's/localnode/1AD_TINY/' $ULDIR/TINY-TRANS.xml > $ULDIR/TINY-1AD-TRANS-1359.xml
sed 's/localnode/1AD_TINY/' $ULDIR/TINY-TRANS-STUB.xml > $ULDIR/TINY-1AD-TRANS-STUB-1359.xml
sed 's/localnode/SMALL_1AD/' $ULDIR/SMALL-TRANS.xml > $ULDIR/SMALL-1AD-TRANS-1359.xml
sed 's/localnode/SMALL_1AD/' $ULDIR/SMALL-TRANS-STUB.xml > $ULDIR/SMALL-1AD-TRANS-STUB-1359.xml
sed 's/localnode/SMALL_1AD/' $ULDIR/SMALL-TRANS-AMMO.xml > $ULDIR/SMALL-1AD-TRANS-5.xml
sed 's/localnode/FULL_1AD/' $ULDIR/FULL-TRANS.xml > $ULDIR/FULL-1AD-TRANS-1359.xml
sed 's/localnode/FULL_1AD/' $ULDIR/FULL-TRANS-STUB.xml > $ULDIR/FULL-1AD-TRANS-STUB-1359.xml
echo "Done"

echo "Create the zip package"
zip -j $ULDIR/1ad-configs.zip $ULDIR/*-*5*.xml 
echo "Done"

echo "Clean up the mess we made"
rm $ULDIR/*.xml
echo "Done cleaning up"
