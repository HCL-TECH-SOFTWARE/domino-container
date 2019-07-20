#!/bin/bash

LOTUS=/opt/ibm/domino

DOMINO_RUNNING=`ps -fu notes | grep "$LOTUS/notes" | grep "server" | grep -v " -jc"`

if [ -z "$DOMINO_RUNNING" ]; then
  exit 1
else
  exit 0 
fi


exit 0
