#!/bin/sh

if [ "x$2" = "x" ]; then
  echo "Usage: $0 <1AD facets file> <UA facets file>"
  echo "  All paths are partial paths, based on the directories"
  echo "    - 1ad/   -- All 1ad facet files."
  echo "    - 1ua/   -- All 1ua facet files."
  echo ""
  echo "    Example: % gen-merged-facets-xml.sh tiny-1ad 17a12v"
  echo "        will generate: tiny-1ad-17a12v.facets.xml"
  exit
fi

# First put the rules in order
echo "Making $1-$2.facets.xml..."
if [ ! -f ./1ad/$1.facets.xml ]; then
    echo "Cannot find file: ./1ad.orig-org-id/$1.facets.xml"
    exit
fi

if [ ! -f ./1ua/$2.facets.xml ]; then
    echo "Cannot find file: ./1ua.orig-org-id/$2.facets.xml"
    exit
fi
../../bin/SocietyMerger ./1ad/$1.facets.xml ./1ua/$2.facets.xml ./$1-$2.facets.xml
echo "Done"
