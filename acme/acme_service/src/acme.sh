#!/bin/csh

while (1)
  # ACME won't start properly if Cougaar node is running, because that keeps event
  # port open.
  killall -9 java
  /usr/bin/ruby acme.rb >>& run.log &
  echo "$!" > acme.pid
  while (-e /proc/$!) 
    sleep 5
  end   
  echo ACME DIED >> run.log
end
