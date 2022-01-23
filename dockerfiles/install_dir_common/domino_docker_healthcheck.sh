#!/bin/bash

############################################################################
# Copyright Nash!Com, Daniel Nashed 2019, 2020 - APACHE 2.0 see LICENSE
############################################################################
#
# This script defines the health check script
# The "ready" option can be used for a readiness check
#
# The following checks can be configured
#
# 1. Check health check status file if present
#  File checked: /tmp/domino_check.txt
#
# 2. Check if port is responding when configured
#  Defined in: /local/notesdata/health_port.cfg
# 
# 3. Fallback if nothing else is configured
#  Check if server process is running
#
# Takes into account service status
#
############################################################################

# Health check defines
DOMINO_PID=/tmp/domino.pid
DOMINO_REQEST_FILE=/tmp/domino_request
DOMINO_STATUS_FILE=/tmp/domino_status

HEALTH_CHECK_PORT_FILE=/local/notesdata/health_port.cfg
HEALTH_CHECK_FILE=/tmp/domino_check.txt
HEALTHY_STRING="OK"

LOTUS=/opt/hcl/domino

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

# If server is shutdown, report server is running but not ready

if [ ! -e "$DOMINO_PID" ]; then
  return_ready 1
  return_health 0
fi

if [ -e "$DOMINO_STATUS_FILE" ]; then
  DOMINO_STATUS=$(cat "$DOMINO_STATUS_FILE")
else
  DOMINO_STATUS=
fi

if [ "$DOMINO_STATUS" = "0" ]; then
  return_ready 1
  return_health 0
fi

if [ "$DOMINO_STATUS" = "c" ]; then
  return_ready 1
  return_health 0
fi

# Domino shutdown requested? -> healthy but not ready

if [ -e "$DOMINO_REQUEST_FILE" ]; then
  DOMINO_REQUEST=$(cat $DOMINO_REQUEST_FILE)
else
  DOMINO_REQUEST=
fi

if [ "$DOMINO_REQUEST" = "0" ]; then
  return_ready 1
  return_health 0
fi

# 1. Check a health check file

if [ -n "$HEALTH_CHECK_FILE" ]; then
  if [ -e "$HEALTH_CHECK_FILE" ]; then

    if [ -z "$HEALTHY_STRING" ]; then
      $HEALTHY_STRING="OK"
    fi

    FOUND=$(grep -e "$HEALTHY_STRING" "$HEALTH_CHECK_FILE" | wc -l)
  else
    FOUND=
  fi

  if [ "$FOUND" = "1" ]; then
    return_ready 1
    return_health 1
  fi

  if [ "$FOUND" = "0" ]; then
    return_ready 0
    return_health 0
  fi
fi

# 2. Check if configured port is responding

if [ -n "$HEALTH_CHECK_PORT_FILE" ]; then
  if [ -e "$HEALTH_CHECK_PORT_FILE" ]; then
    HEALTH_CHECK_PORT=$(cat $HEALTH_CHECK_PORT_FILE)
  else
    HEALTH_CHECK_PORT=
  fi
fi

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

# 3. Fallback option: Check if server process is running

DOMINO_RUNNING=$(ps -ef | grep "$LOTUS/notes" | grep "server" | grep -v " -jc")

if [ -z "$DOMINO_RUNNING" ]; then
  return_ready 1
  return_health 1
else
  return_ready 0
  return_health 0
fi

exit 0

