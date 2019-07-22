#!/bin/bash

if [ -z "$LOTUS" ]; then
  if [ -x /opt/hcl/domino/bin/server ]; then
    LOTUS=/opt/hcl/domino
  else
    LOTUS=/opt/ibm/domino
  fi
fi

DOMINO_RUNNING=`ps -fu notes | grep "$LOTUS/notes" | grep "server" | grep -v " -jc"`

if [ -z "$DOMINO_RUNNING" ]; then
  exit 1
else
  exit 0 
fi


exit 0
