#!/bin/sh

# Reads in the file 'rule_order.txt' and
# creates new files in ./temp sorted in
# the order specified in the text file.

RULEDIR=${1:?Error: Must specify RuleDir}
TEMPDIR=$RULEDIR/temp
# TEMPDIR="./temp"
RULE_FILE=$RULEDIR/rule_order.txt

if [ -f $RULE_FILE ]; then
    if [ -d $TEMPDIR ]; then
      # Clean it out, to be save.
	rm -rf $TEMPDIR
	mkdir $TEMPDIR
    else
	mkdir $TEMPDIR	
    fi
    i=100;
    while read rulefilename; do
     # This test should not be needed, but it seems to fail without it.	
      if [ -z $rulefilename ]; then
	  break
      fi
      cp $RULEDIR/$rulefilename $TEMPDIR/$i.$rulefilename
      i=`expr $i + 1`
    done < $RULE_FILE
fi
