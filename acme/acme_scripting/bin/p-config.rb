
# $POLARIS - Is Polaris running?  Should always be true.
$POLARIS=true

# $POLARIS_HOST - Which Polaris Host are you running against?
# It should be polaris.ultralog.net for production stuff, u180 for testing.
$POLARIS_HOST="polaris.ultralog.net"

# $POLARIS_UPDATE - Should we download Cougaar and its Overlays, or reuse
# the installation already on the the disk.
$POLARIS_UPDATE=false

# $POLARIS_CVS_HOME - This is the place where p-runner.rb will check out
# the scripts it needs to run.
$POLARIS_CVS_HOME="/polaris"

# $POLARIS_REGIME - Set this value to the type of tests being run.  For
# example:
#    DEV - Developing scripts, not for reporting.
#    ETA - Engineering Tests
#    ASMT - Assessment
#    ART - Art & Mark (ISAT)
$POLARIS_REGIME="DEV"



