#!/bin/bash

############################################################################
# Copyright Nash!Com, Daniel Nashed 2019, 2025 - APACHE 2.0 see LICENSE
############################################################################

# This script is the main entry point for Docker container and used instead of rc_domino.
# You can still interact with the start script invoking "domino" which is Docker aware.
# This entry point is invoked by Docker to start the Domino server and also acts as a shutdown monitor.

if [ "$DOMDOCK_DEBUG_SHELL" = "yes" ]; then
  echo "--- Enable shell debugging ---"
  set -x
fi

export DOMDOCK_DIR=/domino-container
export DOMDOCK_LOG_DIR=/tmp/domino-container
export DOMDOCK_TXT_DIR=/domino-container
export DOMDOCK_SCRIPT_DIR=/domino-container/scripts
export LOTUS=/opt/hcl/domino
export Notes_ExecDirectory=$LOTUS/notes/latest/linux
export DOMINO_DATA_PATH=/local/notesdata

export DOMINO_REQEST_FILE=/tmp/domino_request
export DOMINO_STATUS_FILE=/tmp/domino_status

# Explicitly set container environment to ensure any container implementation works
export CONTAINER_ENV=any

DOMINO_CONTAINER_CFG_SCRIPT=$DOMDOCK_SCRIPT_DIR/domino_prestart.sh
DOMINO_START_SCRIPT=/opt/nashcom/startscript/rc_domino_script
DOMDOCK_UPDATE_CHECK_STATUS_FILE=$DOMDOCK_LOG_DIR/domino_data_upd_checked.txt

# If log dir does not exist, create it. Important for environments assigning a new /tmp
if [ ! -e "$DOMDOCK_LOG_DIR" ]; then
  mkdir -p "$DOMDOCK_LOG_DIR"
fi

# Get Linux version and platform
LINUX_VERSION=$(cat /etc/os-release | grep "VERSION_ID="| cut -d= -f2 | xargs)
LINUX_PRETTY_NAME=$(cat /etc/os-release | grep "PRETTY_NAME="| cut -d= -f2 | xargs)
LINUX_ID=$(cat /etc/os-release | grep "^ID="| cut -d= -f2 | xargs)

# Always use whoami
LOGNAME=$(whoami 2>/dev/null)

# Check current UID - only reliable source
CURRENT_UID=$(id -u)

if [ "$CURRENT_UID" = "0" ]; then
  # If running as root set Domino user to "notes"
  DOMINO_USER="notes"
else

  # Special configuration for K8s environments to ensure the user is mapped correctly.
  # OpenShift adds the UID to /etc/passwd automatically.
  # This logic is only required for K8s environments not providing user mapping.

  if [ ! "$LOGNAME" = "notes" ]; then

    if [ -z "$LOGNAME" ]; then
      # If the uid/user is not in /etc/passwd, update notes entry --> empty if uid cannot be mapped
      if [ -x "$DOMDOCK_SCRIPT_DIR/nuid2pw" ]; then
        $DOMDOCK_SCRIPT_DIR/nuid2pw $CURRENT_UID
        LOGNAME=notes
      else
        echo "Warning: Cannot enable K8s runAsUser support not found (nuid2pw)!"
      fi

    else
      if [ -n "$DOCKER_UID_NOTES_MAP_FORCE" ]; then
        # If the uid/user is not in /etc/passwd, update notes entry and remove numeric entry for UID if present
        if [ -x "$DOMDOCK_SCRIPT_DIR/nuid2pw" ]; then
          $DOMDOCK_SCRIPT_DIR/nuid2pw $CURRENT_UID
          LOGNAME=notes
        else
          echo "Warning: Cannot enable K8s runAsUser support not found (nuid2pw)!"
        fi
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


log()
{
  echo
  echo "$@"
  echo
}

log_delim()
{
   echo "--------------------------------------------------------------------------------"
}

header()
{
   echo
   log_delim
   echo "$@"
   log_delim
   echo
}


run_external_script()
{
  if [ -z "$1" ]; then
    return 0
  fi

  SCRIPT2RUN=$DOMDOCK_SCRIPT_DIR/$1

  if [ ! -e "$SCRIPT2RUN" ]; then
    return 0
  fi

  if [ ! -x "$SCRIPT2RUN" ]; then
    log "Cannot execute script " [$SCRIPT2RUN]
    return 0
  fi

  if [ -n "$EXECUTE_SCRIPT_CHECK_OWNER" ]; then
    SCRIPT_OWNER=$(stat -c %U $SCRIPT2RUN)
    if [ ! "$SCRIPT_OWNER" = "$EXECUTE_SCRIPT_CHECK_OWNER" ]; then
      log "Wrong owner for script -- not executing" [$SCRIPT2RUN]
      return 0
    fi
  fi

  log "--- [$1] ---"
  $SCRIPT2RUN
  log "--- [$1] ---"

  return 0
}

stop_server()
{
  log "--- Stopping Domino Server ---"

  run_external_script before_shutdown.sh

  $DOMINO_START_SCRIPT stop

  log "--- Domino Server Shutdown ---"

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

  log "Invalid request: [$DOMINO_REQUEST]"
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

    found=$(grep -e "$SEARCH_STR" "$FILE" 2>/dev/null | wc -l)

    if [ "$found" -ge "$COUNT" ]; then
      return 0
    fi

    sleep 1
    seconds=$(expr $seconds + 1)
    if [ $(expr $seconds % 10) -eq 0 ]; then
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

  # Additional variables

  unset SetupAutoConfigureParams
  unset DominoTrialKeyFile
  unset SafeIDFile
  unset Notesini

  if [ -e ~/.bash_history ]; then
    cat /dev/null > ~/.bash_history
  fi

  history -c
}

start_node_exporter()
{
  local NODE_EXPORTER_BIN=/opt/prometheus/node_exporter/node_exporter

  if [ ! -x "$NODE_EXPORTER_BIN" ]; then
     return 0;
  fi

  if [ -z "$DOMINO_PROM_STATS_DIR" ]; then
    export DOMINO_PROM_STATS_DIR=/local/notesdata/domino/stats

  else
    # Use default if no other option is specified and the stats dir is set
    if [ -z "$NODE_EXPORTER_OPTIONS" ]; then
       $NODE_EXPORTER_OPTIONS=default
    fi
  fi

  if [ -z "$NODE_EXPORTER_OPTIONS" ]; then
    return 0;
  fi

  if [ "$NODE_EXPORTER_OPTIONS" = "default" ]; then
    NODE_EXPORTER_OPTIONS="--collector.disable-defaults --collector.textfile --collector.textfile.directory=$DOMINO_PROM_STATS_DIR"
  fi

  header "Starting Prometheus Node Exporter"

  # Start node exporter in background logging errors to container STDOUT/STDERR
  "$NODE_EXPORTER_BIN" $NODE_EXPORTER_OPTIONS &
}


# Ensure security limits don't have more than 1024*1024 open files. This can cause high CPU usage for LSOF used by NSD

CONTAINER_ORIGINAL_NOFILES_LIMIT=$(ulimit -n)

if [ "$CONTAINER_ORIGINAL_NOFILES_LIMIT" -gt "1048576" ]; then

  log "Info: Changing number of open files from $CONTAINER_ORIGINAL_NOFILES_LIMIT to 1048576"
  ulimit -n 1048576
fi


# "docker stop" will send a SIGTERM to the shell. catch it and stop Domino gracefully.
# Use e.g. "docker stop --time=90 .." to ensure server has sufficient time to terminate.

# Note: signal child died causes issues in bash 5.x
trap "stop_server" 1 2 3 4 6 9 13 15 19 23

# Check data update only at first container start

if [ ! -e "$DOMDOCK_UPDATE_CHECK_STATUS_FILE" ]; then
  run_external_script before_data_copy.sh

  "$DOMDOCK_SCRIPT_DIR/domino_install_data_copy.sh"
  date > "$DOMDOCK_UPDATE_CHECK_STATUS_FILE"
fi

# Check if server is configured. Else start custom configuration script.

CHECK_SERVER_SETUP=$(grep -i "ServerSetup=" $DOMINO_DATA_PATH/notes.ini)
if [ -z "$CHECK_SERVER_SETUP" ]; then

  log "Server is not yet configured. The Domino start script logic takes care of configuring it ..."

  run_external_script before_config_script.sh

  DOMINO_IS_CONFIGURED=false

  # Invoke pre setup script to see if any additional logic needs to be performed. This can include SetupAutoConfigure triggered action or OTS files
  if [ -n "$DOMINO_CONTAINER_CFG_SCRIPT" ]; then
    if [ -x "$DOMINO_CONTAINER_CFG_SCRIPT" ]; then
      # Ensure variables modified in pre start script are returned
      . "$DOMINO_CONTAINER_CFG_SCRIPT"
    fi
  fi

else
  DOMINO_IS_CONFIGURED=true

  log "Server already setup"
  cleanup_setup_env
fi

run_external_script before_server_start.sh

# Finally start server or have the start script configure it

log "--- Starting Domino Server ---"

# Cleanup all setup variables & co if still set

# Inside the container we can always safely start as "notes" user
$DOMINO_START_SCRIPT start

# Check post setup operations after configuration
if [ "$DOMINO_IS_CONFIGURED" = "false" ]; then

  run_external_script after_config_script.sh

  if [ -n "$DominoConfigPostSetupConsoleCmd" ]; then

    log "Waiting 30 seconds before running post setup server command"
    sleep 30

    log "Running post setup server command"
    $DOMINO_START_SCRIPT cmd "$DominoConfigPostSetupConsoleCmd"
    sleep 10
  fi

  # Now check and wait if a post config restart is requested
  if [ -n "$DominoConfigRestartWaitTime" ] || [ -n "$DominoConfigRestartWaitString" ]; then

    sleep 2
    wait_time_or_string "$DominoConfigRestartWaitTime" $DOMINO_DATA_PATH/IBM_TECHNICAL_SUPPORT/console.log "$DominoConfigRestartWaitString"

    # Cleanup environment at restart
    cleanup_setup_env

    # Invoke restart server command
    log "Restarting Domino server to finalize configuration"
    $DOMINO_START_SCRIPT cmd "restart server"
  fi
fi


start_node_exporter


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
      if [ -n "$var" ]; then
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
  do
    sleep 1
  done
fi

# Exit terminates the calling script cleanly
exit 0
