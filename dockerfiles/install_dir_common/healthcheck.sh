#!/bin/bash

############################################################################
# Copyright Nash!Com, Daniel Nashed 2019, 2025 - APACHE 2.0 see LICENSE
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


log()
{
  if [ -n "$HEALTH_CHECK_LOG" ]; then
    echo "$@" >> "$HEALTH_CHECK_LOG"
  fi
}


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

  log "result: $1"
  exit $1
}


return_health()
{
  log "result: $1"
  exit $1
}


# -- Main logic --

log ""
log "[$(date -Iseconds)]"


# If server is shutdown, report server is running but not ready

if [ ! -e "$DOMINO_PID" ]; then
  log "Server is shutdown"
  return_ready 1
  return_health 0
fi

if [ -e "$DOMINO_STATUS_FILE" ]; then
  DOMINO_STATUS=$(cat "$DOMINO_STATUS_FILE")
  log "Domino status file: [$DOMINO_STATUS_FILE] -> [$DOMINO_STATUS]"
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
  log "Request file [$DOMINO_REQUEST_FILE] -> [$DOMINO_REQUEST]"
else
  DOMINO_REQUEST=
fi

if [ "$DOMINO_REQUEST" = "0" ]; then
  return_ready 1
  return_health 0
fi


# 1. Check a health check file

if [ -n "$HEALTH_CHECK_FILE" ] && [ -e "$HEALTH_CHECK_FILE" ]; then

  if [ -z "$HEALTHY_STRING" ]; then
    $HEALTHY_STRING="OK"
  fi

  FOUND=$(grep -e "$HEALTHY_STRING" "$HEALTH_CHECK_FILE" | wc -l)

  log "Checking [$HEALTH_CHECK_FILE] for [$HEALTHY_STRING] -> [$FOUND]"

  if [ "$FOUND" = "0" ]; then
    return_ready 1
    return_health 1
  fi

  return_ready 0
  return_health 0
fi


# 2. Check if configured port is responding (health check can be configured in a file or env variable)

if [ -n "$HEALTH_CHECK_PORT_FILE" ]; then
  if [ -e "$HEALTH_CHECK_PORT_FILE" ]; then
    HEALTH_CHECK_PORT=$(cat $HEALTH_CHECK_PORT_FILE)
  fi
fi

if [ -n "$HEALTH_CHECK_PORT" ]; then

  log "Checking ports: [$HEALTH_CHECK_PORT]"

  for port in $HEALTH_CHECK_PORT; do

    timeout 10 bash -c "</dev/tcp/localhost/$port" 2> /dev/null
    if [ "$?" != "0" ]; then
      log "Port [$port] is down"
      return_ready 1
      return_health 1
    fi

  done

  return_ready 0
  return_health 0

fi


# 3. Fallback option: Check if server process is running

DOMINO_RUNNING=$(ps -ef | grep "$LOTUS/notes" | grep "server" | grep -v " -jc")

log "Domino Server process line: $DOMINO_RUNNING"

if [ -z "$DOMINO_RUNNING" ]; then
  return_ready 1
  return_health 1
else
  return_ready 0
  return_health 0
fi

exit 0

