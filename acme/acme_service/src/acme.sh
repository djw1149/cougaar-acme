#!/bin/csh

while (1)
  /usr/bin/ruby acme.rb >>& run.log 
  echo "$!" > acme.pid
  echo ACME DIED >> run.log
end
