#!/bin/sh
#
# Make eight facet societies
echo "Making single-1ad.facets.xml..."
ruby org_agent_builder.rb -d 1ad.org_data -m single-1ad.member.csv -s 1ad/single-1ad.facets.xml -o
echo "Done"
echo "Making micro-1ad.facets.xml..."
ruby org_agent_builder.rb -d 1ad.org_data -m micro-1ad.member.csv -s 1ad/micro-1ad.facets.xml -o
echo "Done"
echo "Making micro-1ad-trans-stub.facets.xml..."
ruby org_agent_builder.rb -d 1ad.org_data -m micro-1ad-trans-stub.member.csv -s orig-org-id/micro-1ad-trans-stub.facets.xml -o
echo "Done"
echo "Making tiny-1ad.facets.xml..."
ruby org_agent_builder.rb -d 1ad.org_data -m tiny-1ad.member.csv -s 1ad/tiny-1ad.facets.xml -o
echo "Done"
echo "Making tiny-1ad-trans-stub.facets.xml..."
ruby org_agent_builder.rb -d 1ad.org_data -m tiny-1ad-trans-stub.member.csv -s 1ad/tiny-1ad-trans-stub.facets.xml -o
echo "Done"
echo "Making small-1ad.facets.xml..."
ruby org_agent_builder.rb -d 1ad.org_data -m small-1ad.member.csv -s 1ad/small-1ad.facets.xml -o
echo "Done"
echo "Making small-1ad-trans-stub.facets.xml..."
ruby org_agent_builder.rb -d 1ad.org_data -m small-1ad-trans-stub.member.csv -s 1ad/small-1ad-trans-stub.facets.xml -o
echo "Done"
echo "Making full-1ad.facets.xml..."
ruby org_agent_builder.rb -d 1ad.org_data -m full-1ad.member.csv -s 1ad/full-1ad.facets.xml -o
echo "Done"
echo "Making full-1ad-trans-stub.facets.xml..."
ruby org_agent_builder.rb -d 1ad.org_data -m full-1ad-trans-stub.member.csv -s 1ad/full-1ad-trans-stub.facets.xml -o
echo "Done"
 