#!/bin/sh
#
# Make seven plugin societies
echo "Making single-1ad.oo.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ad.orig-org-id/single-1ad.oo.facets.xml -r base_rules -o 1ad.orig-org-id/single-1ad.oo.plugins.xml
echo "Done"
echo "Making micro-1ad.oo.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ad.orig-org-id/micro-1ad.oo.facets.xml -r base_rules -o 1ad.orig-org-id/micro-1ad.oo.plugins.xml
echo "Done"
echo "Making tiny-1ad.oo.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ad.orig-org-id/tiny-1ad.oo.facets.xml -r base_rules -o 1ad.orig-org-id/tiny-1ad.oo.plugins.xml
echo "Done"
echo "Making tiny-1ad-trans-stub.oo.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ad.orig-org-id/tiny-1ad-trans-stub.oo.facets.xml -r base_rules -o 1ad.orig-org-id/tiny-1ad-trans-stub.oo.plugins.xml
echo "Done"
echo "Making small-1ad.oo.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ad.orig-org-id/small-1ad.oo.facets.xml -r base_rules -o 1ad.orig-org-id/small-1ad.oo.plugins.xml
echo "Done"
echo "Making small-1ad-trans-stub.oo.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ad.orig-org-id/small-1ad-trans-stub.oo.facets.xml -r base_rules -o 1ad.orig-org-id/small-1ad-trans-stub.oo.plugins.xml
echo "Done"
echo "Making full-1ad.oo.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ad.orig-org-id/full-1ad.oo.facets.xml -r base_rules -o 1ad.orig-org-id/full-1ad.oo.plugins.xml
echo "Done"
echo "Making full-1ad-trans-stub.oo.plugins.xml..."
ruby ../bin/transform_society.rb -i 1ad.orig-org-id/full-1ad-trans-stub.oo.facets.xml -r base_rules -o 1ad.orig-org-id/full-1ad-trans-stub.oo.plugins.xml
echo "Done"
