#!/bin/sh

if [ "x$1" = "x" ]; then
  echo "Usage: $0 <partial relative path to member file> [1][3][P][5][9][S]"
  echo "    IE: micro-1ad arg produces micro-1ad.facets.xml from micro-1ad.member.csv"
  echo "    An optional thread exclusion argument can also be specified."
  echo "    For example: gen-facets-xml.sh micro-1ad 3P "
  echo "    Will generate a facets file that excludes both bulk and packaged POL"
  echo "    omitting this optional argument will generate a facets file with all threads included"
  exit
fi

echo "Making $1.facets.xml..."
if [ "x$2" = "x" ]; then
    ruby org_agent_builder.rb -d minitest -m $1.member.csv -s minitest/$1.facets.xml -o
else
    ruby org_agent_builder.rb -d minitest -m $1.member.csv -s minitest/$1-x$2.facets.xml -o -x $2
fi   
echo "Done"
