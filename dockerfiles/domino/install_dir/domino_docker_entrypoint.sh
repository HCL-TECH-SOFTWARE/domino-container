#!/bin/bash

###########################################################################
# Docker Entrypoint - Start/Stop Script for Domino on xLinux/zLinux/AIX   #
# Version 3.3.0 17.07.2019                                                #
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

export DOMDOCK_DIR=/domino-docker
export DOMDOCK_LOG_DIR=/domino-docker
export DOMDOCK_TXT_DIR=/domino-docker
export DOMDOCK_SCRIPT_DIR=/domino-docker/scripts


if [ -z "$LOTUS" ]; then
  if [ -x /opt/hcl/domino/bin/server ]; then
    export LOTUS=/opt/hcl/domino
  else
    export LOTUS=/opt/ibm/domino
  fi
fi

# export required environment variables
export Notes_ExecDirectory=$LOTUS/notes/latest/linux
export DOMINO_DATA_PATH=/local/notesdata

DOMINO_SERVER_ID=$DOMINO_DATA_PATH/server.id
DOMINO_DOCKER_CFG_SCRIPT=$DOMDOCK_SCRIPT_DIR/docker_prestart.sh
DOMINO_START_SCRIPT=/opt/nashcom/startscript/rc_domino_script

# always use whoami
LOGNAME=`whoami 2>/dev/null`

# check current UID - only reliable source
CURRENT_UID=`id -u`

if [ "$CURRENT_UID" = "0" ]; then
  # if running as root set user to "notes"
  DOMINO_USER="notes"
else
  
  if [ ! "$LOGNAME" = "notes" ]; then
    # if the uid/user is not in /etc/passwd, update notes entry and remove numeric entry for UID if present

    $DOMDOCK_SCRIPT_DIR/nuid2pw $CURRENT_UID
    LOGNAME=notes
  fi

  DOMINO_USER=$LOGNAME
fi

DOMINO_GROUP=`id -gn`

export LOGNAME
export DOMINO_USER
export DOMINO_GROUP

# set more paranoid umask to ensure files can be only read by user
umask 0077

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

# Data Update Operations
if [ "$LOGNAME" = "$DOMINO_USER" ] ; then
  $DOMDOCK_SCRIPT_DIR/domino_install_data_copy.sh
else
  su - notes -c $DOMDOCK_SCRIPT_DIR/domino_install_data_copy.sh
fi

# Check if server is configured. Else start custom configuration script
if [ -z `grep -i "ServerSetup=" $DOMINO_DATA_PATH/notes.ini` ]; then
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
if [ -z `grep -i "ServerSetup=" $DOMINO_DATA_PATH/notes.ini` ]; then

  echo "Configuration for automated setup not found."
  echo "Starting Domino Server in listen mode"

  echo "--- Configuring Domino Server ---"

  if [ "$LOGNAME" = "$DOMINO_USER" ] ; then
    cd $DOMINO_DATA_PATH
    $LOTUS/bin/server -listen 1352
  else
    su - $DOMINO_USER -c "cd $DOMINO_DATA_PATH; $LOTUS/bin/server -listen 1352"
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

