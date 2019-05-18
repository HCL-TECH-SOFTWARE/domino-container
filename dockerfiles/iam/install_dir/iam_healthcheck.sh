#!/bin/bash

IAM_RUNNING=`ps -ef | grep "iam" `

if [ -z "$IAM_RUNNING" ]; then
  exit 1
else
  exit 0 
fi


exit 0
