#!/bin/sh
#
#!/bin/sh
# First put the rules in order
echo "Sorting the rules and writing to base_rules/temp..."
./rule.sort.sh base_rules
ls base_rules/temp
echo "Done"
echo "Making single-1ad.oo.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ua/1-ca-bn.oo.facets.xml -r base_rules/temp -o 1ua.orig-org-id/1-ca-bn.oo.plugins.xml
echo "Done"
echo "Making 17a18v.oo.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ua/17a18v-facets.xml -r base_rules/temp -o 1ua.orig-org-id/17a18v.oo.plugins.xml
echo "Done"
