#!/bin/sh
#
# Make eight facet societies
echo "Making single-1ad.oo.facets.xml..."
ruby org_agent_builder.rb -d org_data -m single-1ad.member.csv -s 1ad.orig-org-id/single-1ad.oo.facets.xml -f false
echo "Done"
echo "Making micro-1ad.oo.facets.xml..."
ruby org_agent_builder.rb -d org_data -m micro-1ad.member.csv -s 1ad.orig-org-id/micro-1ad.oo.facets.xml -f false
echo "Done"
echo "Making tiny-1ad.oo.facets.xml..."
ruby org_agent_builder.rb -d org_data -m tiny-1ad.member.csv -s 1ad.orig-org-id/tiny-1ad.oo.facets.xml -f false
echo "Done"
echo "Making tiny-1ad-trans-stub.oo.facets.xml..."
ruby org_agent_builder.rb -d org_data -m tiny-1ad-trans-stub.member.csv -s 1ad.orig-org-id/tiny-1ad-trans-stub.oo.facets.xml -f false
echo "Done"
echo "Making small-1ad.oo.facets.xml..."
ruby org_agent_builder.rb -d org_data -m small-1ad.member.csv -s 1ad.orig-org-id/small-1ad.oo.facets.xml -f false
echo "Done"
echo "Making small-1ad-trans-stub.oo.facets.xml..."
ruby org_agent_builder.rb -d org_data -m small-1ad-trans-stub.member.csv -s 1ad.orig-org-id/small-1ad-trans-stub.oo.facets.xml -f false
echo "Done"
echo "Making full-1ad.oo.facets.xml..."
ruby org_agent_builder.rb -d org_data -m full-1ad.member.csv -s 1ad.orig-org-id/full-1ad.oo.facets.xml -f false
echo "Done"
echo "Making full-1ad-trans-stub.oo.facets.xml..."
ruby org_agent_builder.rb -d org_data -m full-1ad-trans-stub.member.csv -s 1ad.orig-org-id/full-1ad-trans-stub.oo.facets.xml -f false
echo "Done"
