#!/bin/sh
# Hackable script to generate an RSS Host.conf file from a TIC xxx-hosts.xml
# 
# Creates
#  $CIP/config/rss/soc-Host.config
###################
# Environment
#
CougaarCheckout=/home/jzinky/cougaar
# cvs.ultralog.net:/cvs/commons/isat/
MetricsHome=$CougaarCheckout/isat/csmart/config/rules/metrics
# cvs.ultralog.net:/cvs/commons/isat/
IsatHome=$CougaarCheckout/isat/csmart/config/rules/isat

#
# csmart app-server needs absolute paths 
# replace $CIP '/' slashes with '\/'
echo $CIP > cip1.txt
cat cip1.txt | sed -e 's/\//\\\//g' > cip2.txt
rm cip1.txt
SAFE_CIP=`head cip2.txt`
rm cip2.txt
#
# JAZ does transform_society really have to happen in $CIP?
cd $CIP

#########################
# Generate host.conf file ($CIP/config/rss/soc-Host.conf)
#
# copy rules
TEMP=/tmp/$USER-host
rm -r $TEMP
mkdir $TEMP
# 
cp $MetricsHome/rss/gen/Metrics-rss-generate-host-conf.rule $TEMP


#Transform Society
ruby $CIP/csmart/config/bin/transform_society.rb -i $1 -r $TEMP


# remove temp file created by transform society
rm new-$1


