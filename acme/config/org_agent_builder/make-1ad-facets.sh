#!/bin/sh
#
# Make four facet societies

FACETDIR=1ad.facets

echo "Making All the 1AD facet files for 1AD configurations"
ruby org_agent_builder.rb -d 1ad.org_data -m tiny-1ad-tc1.member.csv -s $FACETDIR/tiny-1ad-tc1.facets.xml
ruby org_agent_builder.rb -d 1ad.org_data -m tiny-1ad-tc7.member.csv -s $FACETDIR/tiny-1ad-tc7.facets.xml
ruby org_agent_builder.rb -d 1ad.org_data -m small-1ad-tc20.member.csv -s $FACETDIR/small-1ad-tc20.facets.xml
ruby org_agent_builder.rb -d 1ad.org_data -m full-1ad-tc20.member.csv -s $FACETDIR/full-1ad-tc20.facets.xml
echo "Done making 1AD facets"
