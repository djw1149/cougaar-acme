#!/bin/sh
#
# Make eight plugin societies
# First put the rules in order
echo "Sorting the rules and writing to base_rules/temp..."
./rule.sort.sh base_rules
ls base_rules/temp
echo "Done"
# 
# Make the plugin societies
echo "Making micro-trans-stub-17a12v.oo.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ua.orig-org-id/micro-trans-stub-17a12v.oo.facets.xml -r base_rules/temp -o 1ua.orig-org-id/micro-trans-stub-17a12v.oo.plugins.xml
echo "Done"
echo "Making micro-17a12v.oo.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ua.orig-org-id/micro-17a12v.oo.facets.xml -r base_rules/temp -o 1ua.orig-org-id/micro-17a12v.oo.plugins.xml
echo "Done"

echo "Making tiny-trans-stub-17a12v.oo.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ua.orig-org-id/tiny-trans-stub-17a12v.oo.facets.xml -r base_rules/temp -o 1ua.orig-org-id/tiny-trans-stub-17a12v.oo.plugins.xml
echo "Done"
echo "Making tiny-17a12v.oo.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ua.orig-org-id/tiny-17a12v.oo.facets.xml -r base_rules/temp -o 1ua.orig-org-id/tiny-17a12v.oo.plugins.xml
echo "Done"
echo "Making full-1ad-160a237v.oo.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ua.orig-org-id/full-160a237v.oo.facets.xml -r base_rules/temp -o 1ad.orig-org-id/full-160a237v.oo.plugins.xml
echo "Done"
echo "Making full-trans-stub-160a237v.oo.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ad.orig-org-id/full-trans-stub-160a237v.oo.facets.xml -r base_rules/temp -o 1ad.orig-org-id/full-trans-stub-160a237v.oo.plugins.xml
echo "Done"
