#!/bin/sh
#
# Make eight plugin societies
# First put the rules in order
echo "Sorting the rules and writing to base_rules/temp..."
./rule.sort.sh base_rules ../rules/metrics
ls base_rules/temp
echo "Done"
# 
# Make plugin societies
echo "Making single-1ad.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ad/single-1ad.facets.xml -r base_rules/temp -o 1ad/single-1ad.plugins.xml
echo "Done"
echo "Making micro-1ad.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ad/micro-1ad.facets.xml -r base_rules/temp -o 1ad/micro-1ad.plugins.xml
echo "Done"
echo "Making micro-1ad-trans-stub.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ad/micro-1ad-trans-stub.facets.xml -r base_rules/temp -o 1ad/micro-1ad-trans-stub.plugins.xml
echo "Done"
echo "Making tiny-1ad.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ad/tiny-1ad.facets.xml -r base_rules/temp -o 1ad/tiny-1ad.plugins.xml
echo "Done"
echo "Making tiny-1ad-trans-stub.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ad/tiny-1ad-trans-stub.facets.xml -r base_rules/temp -o 1ad/tiny-1ad-trans-stub.plugins.xml
echo "Done"
echo "Making small-1ad.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ad/small-1ad.facets.xml -r base_rules/temp -o 1ad/small-1ad.plugins.xml
echo "Done"
echo "Making small-1ad-trans-stub.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ad/small-1ad-trans-stub.facets.xml -r base_rules/temp -o 1ad/small-1ad-trans-stub.plugins.xml
echo "Done"
echo "Making full-1ad.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ad/full-1ad.facets.xml -r base_rules/temp -o 1ad/full-1ad.plugins.xml
echo "Done"
echo "Making full-1ad-trans-stub.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ad/full-1ad-trans-stub.facets.xml -r base_rules/temp -o 1ad/full-1ad-trans-stub.plugins.xml
echo "Done"
