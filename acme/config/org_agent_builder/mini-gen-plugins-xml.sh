#!/bin/sh

if [ "x$1" = "x" ]; then
  echo "Usage: $0 <partial relative path to facets file>"
  echo "    IE: 1ua/17a11v arg produces 1ua/17a11v.plugins.xml from"
  echo "        17a11v.facets.xml"
  exit
fi

# First put the rules in order
echo "Sorting the rules and writing to base_rules/temp..."
./rule.sort.sh minitest_rules ../rules/minitest
ls minitest_rules/temp
echo "Done"
echo "Making $1.plugins.xml..."
ruby ../bin/transform_society.rb -i minitest/$1.facets.xml -r minitest_rules/temp -o minitest/$1.plugins.xml
echo "Done"
