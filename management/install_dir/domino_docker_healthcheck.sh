#!/bin/bash

DOMINO_RUNNING=`ps -fu notes | grep "/opt/ibm/domino/notes" | grep "server" | grep -v " -jc"`

if [ -z "$DOMINO_RUNNING" ]; then
  exit 1
else
  exit 0 
fi


exit 0
