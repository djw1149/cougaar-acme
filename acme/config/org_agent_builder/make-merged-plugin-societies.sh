#!/bin/sh
#
# Make eight plugin societies
# First put the rules in order
echo "Sorting the rules and writing to base_rules/temp..."
./rule.sort.sh base_rules ../rules/metrics
ls base_rules/temp
echo "Done"
# 
# Make the plugin societies
echo "Making micro-trans-stub-17a12v.oo.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ad.1ua/micro-trans-stub-17a12v.oo.facets.xml -r base_rules/temp -o 1ad.1ua/micro-trans-stub-17a12v.oo.plugins.xml
echo "Done"
echo "Making micro-17a12v.oo.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ad.1ua/micro-17a12v.oo.facets.xml -r base_rules/temp -o 1ad.1ua/micro-17a12v.oo.plugins.xml
echo "Done"

echo "Making micro-trans-stub-160a237v.oo.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ad.1ua/micro-trans-stub-160a237v.oo.facets.xml -r base_rules/temp -o 1ad.1ua/micro-trans-stub-160a237v.oo.plugins.xml
echo "Done"
echo "Making micro-160a237v.oo.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ad.1ua/micro-160a237v.oo.facets.xml -r base_rules/temp -o 1ad.1ua/micro-160a237v.oo.plugins.xml
echo "Done"

echo "Making tiny-trans-stub-17a12v.oo.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ad.1ua/tiny-trans-stub-17a12v.oo.facets.xml -r base_rules/temp -o 1ad.1ua/tiny-trans-stub-17a12v.oo.plugins.xml
echo "Done"
echo "Making tiny-17a12v.oo.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ad.1ua/tiny-17a12v.oo.facets.xml -r base_rules/temp -o 1ad.1ua/tiny-17a12v.oo.plugins.xml
echo "Done"

echo "Making tiny-trans-stub-160a237v.oo.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ad.1ua/tiny-trans-stub-160a237v.oo.facets.xml -r base_rules/temp -o 1ad.1ua/tiny-trans-stub-160a237v.oo.plugins.xml
echo "Done"
echo "Making tiny-160a237v.oo.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ad.1ua/tiny-160a237v.oo.facets.xml -r base_rules/temp -o 1ad.1ua/tiny-160a237v.oo.plugins.xml
echo "Done"

echo "Making small-17a12v.oo.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ad.1ua/small-17a12v.oo.facets.xml -r base_rules/temp -o 1ad.1ua/small-17a12v.oo.plugins.xml
echo "Done"

echo "Making small-trans-stub-17a12v.oo.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ad.1ua/small-trans-stub-17a12v.oo.facets.xml -r base_rules/temp -o 1ad.1ua/small-trans-stub-17a12v.oo.plugins.xml
echo "Done"

echo "Making small-160a237v.oo.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ad.1ua/small-160a237v.oo.facets.xml -r base_rules/temp -o 1ad.1ua/small-160a237v.oo.plugins.xml
echo "Done"

echo "Making small-trans-stub-160a237v.oo.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ad.1ua/small-trans-stub-160a237v.oo.facets.xml -r base_rules/temp -o 1ad.1ua/small-trans-stub-160a237v.oo.plugins.xml
echo "Done"

echo "Making full-1ad-160a237v.oo.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ad.1ua/full-160a237v.oo.facets.xml -r base_rules/temp -o 1ad.1ua/full-160a237v.oo.plugins.xml
echo "Done"
echo "Making full-trans-stub-160a237v.oo.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ad.1ua/full-trans-stub-160a237v.oo.facets.xml -r base_rules/temp -o 1ad.1ua/full-trans-stub-160a237v.oo.plugins.xml
echo "Done"
