#!/bin/csh

while (1)
  /usr/bin/ruby acme.rb >>& run.log &
  echo "$!" > acme.pid
  while (-e /proc/$!) 
    sleep 5
  end   
  echo ACME DIED >> run.log
end
