#!/bin/sh

###########################################################################
# Docker Entrypoint - Start/Stop Script for Domino on xLinux/zLinux/AIX   #
# Version 3.2.2 16.05.2019                                                #
#                                                                         #
# (C) Copyright Daniel Nashed/NashCom 2005-2019                           #
# Feedback domino_unix@nashcom.de                                         #
#                                                                         #
# Licensed under the Apache License, Version 2.0 (the "License");         #
# you may not use this file except in compliance with the License.        #
# You may obtain a copy of the License at                                 #
#                                                                         #
#      http://www.apache.org/licenses/LICENSE-2.0                         #
#                                                                         #
# Unless required by applicable law or agreed to in writing, software     #
# distributed under the License is distributed on an "AS IS" BASIS,       #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.#
# See the License for the specific language governing permissions and     #
# limitations under the License.                                          #
###########################################################################

# This script is the main entry point for Docker container and used instead of rc_domino.
# You can still interact with the start script invoking rc_domino which is Docker aware.
# This entry point is invoked by Docker to start the Domino server and also acts as a shutdown monitor.

DOMINO_USER=notes
DOMINO_SERVER_ID=/local/notesdata/server.id
DOMINO_DOCKER_CFG_SCRIPT=/docker_prestart.sh
DOMINO_START_SCRIPT=/opt/ibm/domino/rc_domino_script

# in docker environment the LOGNAME is not set
if [ -z "$LOGNAME" ]; then
  LOGNAME=`whoami`
fi

stop_server ()
{
  echo "--- Stopping Domino Server ---"

  if [ "$LOGNAME" = "$DOMINO_USER" ] ; then
    $DOMINO_START_SCRIPT stop
  else
    su - notes -c "$DOMINO_START_SCRIPT stop"
  fi

  echo "--- Domino Server Shutdown ---"
  exit 0
}

# "docker stop" will send a SIGTERM to the shell. catch it and stop Domino gracefully.
# Ensure to use e.g. "docker stop --time=90 .." to ensure server has sufficient time to terminate.

trap "stop_server" 1 2 3 4 6 9 13 15 17 19 23

# Check if server is configured. Else start custom configuration script
if [ ! -e "$DOMINO_SERVER_ID" ]; then
  if [ ! -z "$DOMINO_DOCKER_CFG_SCRIPT" ]; then
    if [ -x "$DOMINO_DOCKER_CFG_SCRIPT" ]; then
      if [ "$LOGNAME" = "$DOMINO_USER" ] ; then
        $DOMINO_DOCKER_CFG_SCRIPT
      else
        su - $DOMINO_USER -c "$DOMINO_DOCKER_CFG_SCRIPT"
      fi
    fi
  fi
fi 

# Check if server is configured. Else start remote configuation on port 1352
if [ ! -e "/local/notesdata/server.id" ]; then

  echo "Configuration for automated setup not found."
  echo "Starting Domino Server in listen mode"

  echo "--- Configuring Domino Server ---"

  if [ "$LOGNAME" = "$DOMINO_USER" ] ; then
    cd /local/notesdata
    /opt/ibm/domino/bin/server -listen 1352
  else
    su - $DOMINO_USER -c "cd /local/notesdata; /opt/ibm/domino/bin/server -listen 1352"
  fi

  echo "--- Configuration ended ---"
  echo
fi

# Finally start server

echo "--- Starting Domino Server ---"

echo "LOGNAME: [$LOGNAME]"

if [ "$LOGNAME" = "$DOMINO_USER" ] ; then
  $DOMINO_START_SCRIPT start
else
  su - $DOMINO_USER -c "$DOMINO_START_SCRIPT start"
fi

# Wait for shutdown signal. This loop should never terminate, because it would 
# shutdown the Docker container immediately and kill Domino.

while true
do
  sleep 1
done

exit 0

