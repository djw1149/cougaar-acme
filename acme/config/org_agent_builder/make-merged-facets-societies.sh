#!/bin/sh

echo "Merging Micro-1AD-trans-stub with 17a12v"
../../bin/SocietyMerger ./1ad.orig-org-id/micro-1ad-trans-stub.oo.facets.xml ./1ua.orig-org-id/17a12v.oo.facets.xml ./1ua.orig-org-id/micro-trans-stub-17a12v.oo.facets.xml
echo "Done."

echo "Merging Micro-1AD with 17a12v"
../../bin/SocietyMerger ./1ad.orig-org-id/micro-1ad.oo.facets.xml ./1ua.orig-org-id/17a12v.oo.facets.xml ./1ua.orig-org-id/micro-17a12v.oo.facets.xml
echo "Done."

echo "Merging Tiny-1AD-trans-stub with 17a12v"
../../bin/SocietyMerger ./1ad.orig-org-id/tiny-1ad-trans-stub.oo.facets.xml ./1ua.orig-org-id/17a12v.oo.facets.xml ./1ua.orig-org-id/tiny-trans-stub-17a12v.oo.facets.xml
echo "Done."

echo "Merging Tiny-1AD with 17a12v"
../../bin/SocietyMerger ./1ad.orig-org-id/tiny-1ad.oo.facets.xml ./1ua.orig-org-id/17a12v.oo.facets.xml ./1ua.orig-org-id/tiny-17a12v.oo.facets.xml
echo "Done."

echo "Merging Full-1AD-trans-stub with 160a237v"
../../bin/SocietyMerger ./1ad.orig-org-id/full-1ad-trans-stub.oo.facets.xml ./1ua.orig-org-id/160a237v.oo.facets.xml ./1ua.orig-org-id/full-trans-stub-160a237v.oo.facets.xml
echo "Done."

echo "Merging Full-1AD with 160a237v"
../../bin/SocietyMerger ./1ad.orig-org-id/full-1ad.oo.facets.xml ./1ua.orig-org-id/160a237v.oo.facets.xml ./1ua.orig-org-id/full-160a237v.oo.facets.xml
echo "Done."