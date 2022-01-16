#!/bin/bash

############################################################################
# Copyright Nash!Com, Daniel Nashed 2019, 2021 - APACHE 2.0 see LICENSE
############################################################################

# This script is the main entry point for Docker container and used instead of rc_domino.
# You can still interact with the start script invoking "domino" which is Docker aware.
# This entry point is invoked by Docker to start the Domino server and also acts as a shutdown monitor.


if [ "$DOMDOCK_DEBUG_SHELL" = "yes" ]; then
  echo "--- Enable shell debugging ---"
  set -x
fi

export DOMDOCK_DIR=/domino-docker
export DOMDOCK_LOG_DIR=/domino-docker
export DOMDOCK_TXT_DIR=/domino-docker
export DOMDOCK_SCRIPT_DIR=/domino-docker/scripts
export DOMINO_REQEST_FILE=/tmp/domino_request
export DOMINO_STATUS_FILE=/tmp/domino_status

if [ -z "$LOTUS" ]; then
  if [ -x /opt/hcl/domino/bin/server ]; then
    export LOTUS=/opt/hcl/domino
  else
    export LOTUS=/opt/ibm/domino
  fi
fi

# Export required environment variables
export Notes_ExecDirectory=$LOTUS/notes/latest/linux
export DOMINO_DATA_PATH=/local/notesdata

DOMINO_DOCKER_CFG_SCRIPT=$DOMDOCK_SCRIPT_DIR/docker_prestart.sh
DOMINO_START_SCRIPT=/opt/nashcom/startscript/rc_domino_script

# This feature needs to be enabled per Docker container using an environment setting
# DOMINO_STATISTICS_FILE=/local/notesdata/domino/html/domino_stats.txt

# Get Linux version and platform
LINUX_VERSION=$(cat /etc/os-release | grep "VERSION_ID="| cut -d= -f2 | xargs)
LINUX_PRETTY_NAME=$(cat /etc/os-release | grep "PRETTY_NAME="| cut -d= -f2 | xargs)
LINUX_ID=$(cat /etc/os-release | grep "^ID="| cut -d= -f2 | xargs)

# Always use whoami
LOGNAME=$(whoami 2>/dev/null)

# Check current UID - only reliable source
CURRENT_UID=$(id -u)

if [ "$CURRENT_UID" = "0" ]; then
  # if running as root set user to "notes"
  DOMINO_USER="notes"
else
  
  if [ ! "$LOGNAME" = "notes" ]; then

    if [ -z "$LOGNAME" ]; then
      # if the uid/user is not in /etc/passwd, update notes entry --> empty if uid cannot be mapped
      $DOMDOCK_SCRIPT_DIR/nuid2pw $CURRENT_UID
      LOGNAME=notes
    else
      if [ ! -z "$DOCKER_UID_NOTES_MAP_FORCE" ]; then
        # if the uid/user is not in /etc/passwd, update notes entry and remove numeric entry for UID if present
        $DOMDOCK_SCRIPT_DIR/nuid2pw $CURRENT_UID
        LOGNAME=notes
      fi
    fi
  fi

  DOMINO_USER=$LOGNAME
fi

DOMINO_GROUP=$(id -gn)

export LOGNAME
export DOMINO_USER
export DOMINO_GROUP

# Set more paranoid umask to ensure files can be only read by user
umask 0077

log_debug()
{
  if [ "$DOMDOCK_DEBUG" = "yes" ]; then
    echo "$(date '+%F %T') debug: $@"
  fi

  return 0
}

run_external_script ()
{
  if [ -z "$1" ]; then
    return 0
  fi

  SCRIPT2RUN=$DOMDOCK_SCRIPT_DIR/$1

  if [ ! -e "$SCRIPT2RUN" ]; then
    return 0
  fi

  if [ ! -x "$SCRIPT2RUN" ]; then
    echo "Cannot execute script " [$SCRIPT2RUN]
    return 0
  fi

  if [ ! -z "$EXECUTE_SCRIPT_CHECK_OWNER" ]; then
    SCRIPT_OWNER=$(stat -c %U $SCRIPT2RUN)
    if [ ! "$SCRIPT_OWNER" = "$EXECUTE_SCRIPT_CHECK_OWNER" ]; then
      echo "Wrong owner for script -- not executing" [$SCRIPT2RUN]
      return 0
    fi
  fi

  echo "--- [$1] ---" 
  $SCRIPT2RUN
  echo "--- [$1] ---" 

  return 0
}

stop_server ()
{
  echo "--- Stopping Domino Server ---"

  run_external_script before_shutdown.sh

  $DOMINO_START_SCRIPT stop

  echo "--- Domino Server Shutdown ---"

  run_external_script after_shutdown.sh

  exit 0
}

check_process_request()
{
  local DOMINO_REQUEST=

  # Get request and delete request file
  if [ -e "$DOMINO_REQUEST_FILE" ]; then
    DOMINO_REQUEST=$(cat $DOMINO_REQUEST_FILE)
    rm -f "$DOMINO_REQUEST_FILE"
  else
    DOMINO_REQUEST=
  fi

  if [ -z "$DOMINO_REQUEST" ]; then
    return 0
  fi

  if [ "$DOMINO_REQUEST" = "0" ]; then
    $DOMINO_START_SCRIPT stop  
    echo "0" > "$DOMINO_STATUS_FILE" 
    return 0
  fi

  if [ "$DOMINO_REQUEST" = "1" ]; then
    $DOMINO_START_SCRIPT start
    echo "1" > "$DOMINO_STATUS_FILE"
    return 0
  fi

  if [ "$DOMINO_REQUEST" = "c" ]; then
    $DOMINO_START_SCRIPT restartcompact 
    echo "c" > "$DOMINO_STATUS_FILE"
    return 0
  fi

  echo "Invalid request: [$DOMINO_REQUEST]"
}

wait_time_or_string()
{
  local MAX_SECONDS=30
  local FILE=$2
  local SEARCH_STR=$3
  local COUNT=1
  local seconds=0
  local found=

  if [ -n "$1" ]; then
    MAX_SECONDS=$1
  fi

  if [ -n "$4" ]; then
    COUNT=$4
  fi

  echo

  if [ -z "$FILE" ] || [ -z "$SEARCH_STR" ]; then
    echo "Waiting for $MAX_SECONDS seconds ..."
    sleep $MAX_SECONDS
    return 0
  fi

  echo "Waiting for [$SEARCH_STR] in [$FILE] (max: $MAX_SECONDS sec, count: $COUNT)"

  while [ "$seconds" -lt "$MAX_SECONDS" ]; do

    found=`grep -e "$SEARCH_STR" "$FILE" 2>/dev/null | wc -l`

    if [ "$found" -ge "$COUNT" ]; then
      return 0
    fi

    sleep 2
    seconds=`expr $seconds + 2`
    if [ `expr $seconds % 10` -eq 0 ]; then
      echo " ... waiting $seconds seconds"
    fi

  done
}

cleanup_setup_env()
{
  local CLEAN_ENV=
  local X=

  # One Touch setup

  CLEAN_ENV=$(set|grep "^SERVERSETUP_" | cut -f1 -d"=" -s)

  for X in $CLEAN_ENV; do
    if [ -n "$X" ]; then
      unset $X
    fi
  done

  CLEAN_ENV=$(set|grep "^IDVAULT_" | cut -f1 -d"=" -s)

  for X in $CLEAN_ENV; do
    if [ -n "$X" ]; then
      unset $X
    fi
  done

  # Classic setup

  unset isFirstServer
  unset AdminFirstName
  unset AdminIDFile
  unset AdminLastName
  unset AdminMiddleName
  unset AdminPassword
  unset CountryCode
  unset DominoDomainName
  unset HostName
  unset OrgUnitIDFile
  unset OrgUnitName
  unset OrgUnitPassword
  unset OrganizationIDFile
  unset OrganizationName
  unset OrganizationPassword
  unset OtherDirectoryServerAddress
  unset OtherDirectoryServerName
  unset ServerIDFile
  unset SafeIDFile
  unset ServerName
  unset ServerPassword
  unset SystemDatabasePath
  unset Notesini

  unset ServerType
  unset AdminUserIDPath
  unset CertifierPassword
  unset DomainName
  unset OrgName

  if [ -e ~/.bash_history ]; then
    cat /dev/null > ~/.bash_history
  fi

  history -c
}

# "docker stop" will send a SIGTERM to the shell. catch it and stop Domino gracefully.
# Use e.g. "docker stop --time=90 .." to ensure server has sufficient time to terminate.

# signal child died causes issues in bash 5.x
case "$BASH_VERSION" in
  5*)
    trap "stop_server" 1 2 3 4 6 9 13 15 19 23
    ;;
  *)
    trap "stop_server" 1 2 3 4 6 9 13 15 17 19 23
    ;;
esac

run_external_script before_data_copy.sh

# Data Update Operations
$DOMDOCK_SCRIPT_DIR/domino_install_data_copy.sh

run_external_script before_config_script.sh

# Check if server is configured. Else start custom configuration script
CHECK_SERVER_SETUP=$(grep -i "ServerSetup=" $DOMINO_DATA_PATH/notes.ini)
if [ -z "$CHECK_SERVER_SETUP" ]; then
  if [ ! -z "$DOMINO_DOCKER_CFG_SCRIPT" ]; then
    if [ -x "$DOMINO_DOCKER_CFG_SCRIPT" ]; then
      # Ensure variables modified in pre start script are returned
      . $DOMINO_DOCKER_CFG_SCRIPT
    fi
  fi
  DOMINO_IS_CONFIGURED=false
else
  DOMINO_IS_CONFIGURED=true
fi 

run_external_script after_config_script.sh

# Check if server is configured or Domino One Touch Setup is requested.
# Else start remote configuation on port 1352

CHECK_SERVER_SETUP=$(grep -i "ServerSetup=" $DOMINO_DATA_PATH/notes.ini)
if [ -n "$CHECK_SERVER_SETUP" ]; then
  echo "Server already setup"
  cleanup_setup_env

elif [ -n "$SetupAutoConfigure" ]; then
  echo "Running Domino One-Touch setup"

else

  echo "Configuration for automated setup not found."
  echo "Starting Domino Server in listen mode"

  echo "--- Configuring Domino Server ---"

  cd $DOMINO_DATA_PATH
  $LOTUS/bin/server -listen 1352

  echo "--- Configuration ended ---"
  echo
fi

run_external_script before_server_start.sh

# Finally start server

echo "--- Starting Domino Server ---"

# Cleanup all setup variables & co if still set

# Inside the container we can always safely start as "notes" user
$DOMINO_START_SCRIPT start

# Now check and wait if a post config restart is requested
if [ "$DOMINO_IS_CONFIGURED" = "false" ]; then
  if [ -n "$DominoConfigRestartWaitTime" ] || [ -n "$DominoConfigRestartWaitString" ]; then

    sleep 2
    wait_time_or_string "$DominoConfigRestartWaitTime" $DOMINO_DATA_PATH/IBM_TECHNICAL_SUPPORT/console.log "$DominoConfigRestartWaitString" 

    #cleanup environment at restart
    cleanup_setup_env

    # Invoke restart server command
    echo "Restarting Domino server to finalize configuration"
    $DOMINO_START_SCRIPT cmd "restart server"
  fi
fi


# Wait for shutdown signal. This loop should never terminate, because it would 
# shutdown the Docker container immediately and kill Domino.


while true
do

  check_process_request

  # Read from console if using Docker standard output option
  if [ "$DOMINO_DOCKER_STDOUT" = "yes" ]; then

    # read can causes i/o error we can't check. but in that case the output is empty (as long var is empty before)
    read var 2> /dev/null

    CHARS=$(echo "$var" | wc -m)
    if [ "$CHARS" -lt 4 ]; then
      : # Invalid input
    elif [ "$var" = "exit" ]; then
      echo "'$var' ignored. use 'QUIT' to shutdown the server. use 'close' or 'stop' to close live console"
    elif [ "$var" = "quit" ]; then
      echo "'$var' ignored. use 'QUIT' to shutdown the server. use 'close' or 'stop' to close live console"
    elif [ "$var" = "e" ]; then
      echo "'$var' ignored. use 'QUIT' to shutdown the server. use 'close' or 'stop' to close live console"
    elif [ "$var" = "q" ]; then
      echo "'$var' ignored. use 'QUIT' to shutdown the server. use 'close' or 'stop' to close live console"
    else
      if [ ! -z "$var" ]; then
        cd "$DOMINO_DATA_PATH"
        $LOTUS/bin/server -c "$var"
      fi
    fi
    var=
  fi

  sleep 1
done

# For debug purposes we want to keep the container alive if requested
if [ "$DOMDOCK_NOEXIT" = "yes" ]; then
  while true
    sleep 10
  do
fi

exit 0
