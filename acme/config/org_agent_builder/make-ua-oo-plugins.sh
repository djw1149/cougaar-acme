#!/bin/sh
#
#!/bin/sh
# First put the rules in order
echo "Sorting the rules and writing to base_rules/temp..."
./rule.sort.sh base_rules
ls base_rules/temp
echo "Done"
echo "Making 160a237v.oo.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ua.orig-org-id/full-160a237v.oo.facets.xml -r base_rules/temp -o 1ua.orig-org-id/full-160a237v.oo.plugins.xml
echo "Done"
