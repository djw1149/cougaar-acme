#!/bin/csh

while (1)
  /usr/bin/ruby acme.rb >>& run.log 
  echo ACME DIED >> run.log
end
