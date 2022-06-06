#!/bin/bash

############################################################################
# Copyright Nash!Com, Daniel Nashed 2022 - APACHE 2.0 see LICENSE
############################################################################
#
# This script defines the health check script
# The "ready" option can be used for a readiness check
#
############################################################################

HEALTHY_STRING="OK"

# We support "ready" checks and by default health checks
if [ "$1" = "ready" ]; then
  CHECK_READY=1
fi

return_ready()
{
  if [ -z "$CHECK_READY" ]; then
    return 0
  fi
  exit $1
}

return_health()
{
  exit $1
}


# Check port is responding 

if [ -n "HEALTH_CHECK_PORT" ]; then

  timeout 10 bash -c "</dev/tcp/$HEALTH_SERVER_NAME/$HEALTH_CHECK_PORT" 2> /dev/null

  if [ $? -eq 0 ]; then
    return_ready 1
    return_health 1
  else
    return_ready 0
    return_health 0
  fi
fi

# Check if server process is running

RUNNING=$(ps -ef | grep "/opt/hcl/SafeLinx/bin/wgated")

if [ -z "$RUNNING" ]; then
  return_ready 1
  return_health 1
else
  return_ready 0
  return_health 0
fi

exit 0

