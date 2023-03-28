#!/bin/bash

###########################################################################
# Automation Test Script                                                  #
# ----------------------                                                  #
# Version 1.0.1 01.09.2022                                                #
#                                                                         #
# This script implements automation testing the Domino Community image    #
#                                                                         #
# (C) Copyright Daniel Nashed/NashCom 2022                                #
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


# Environment
CONTAINER_NAME=domino-autotesting
CONTAINER_HOSTNAME=automation.notes.lab
CONTAINER_ENV_FILE=
DOMINO_SHUTDOWN_TIMEOUT=120
USER="full admin"
PASSWORD="domino4ever"

# CONTAINER_PORTS="-p 1352:1352 -p 80:80 -p 443:443"
# CONTAINER_NETWORK_NAME=host
# CONTAINER_SPECIAL_OPTIONS="--ip 172.17.0.1"

# Optional script to allow additional tests, based on the same framework
# CUSTOM_AUTOMATION_CHECK_SCRIPT=/local/custom_tests.sh

SCRIPT_NAME=$(readlink -f $0)
SCRIPT_DIR=$(dirname $SCRIPT_NAME)

. $SCRIPT_DIR/script_lib.sh


print_help()
{
  header "Syntax: $1"

  log "Runs automation test for Domino Community images"
  log

  log  "logs            Show container logs"
  log  "bash            Run a container bash"
  log  "root            Run bash with root permissions inside container"
  log  "exec            Execute a command inside the container"
  log  "console         Run live Domino server console"
  log  "domino          Run Domino start script command"
  log  "stop            Stop container"
  log  "rm              Remove container"
  log  "cleanup         Cleanup Domino server"
  log
  log  "-image=<name>   Specify image to test"
  log  "-nostop         Don't stop container after testing (debugging/testing)"
  log  "-debug          Debug output"
  log
}

check_container_environment()
{
  CONTAINER_CMD=
  CONTAINER_ENV_NAME=
  CONTAINER_RUNTIME_VERSION=

  if [ -x /usr/bin/podman ]; then
    if [ -z "$USE_DOCKER" ]; then
      # Podman environment detected
      CONTAINER_CMD=podman
      CONTAINER_ENV_NAME=Podman
      CONTAINER_RUNTIME_VERSION_STR=$(podman -v | head -1)
      CONTAINER_RUNTIME_VERSION=$(echo $CONTAINER_RUNTIME_VERSION_STR | awk -F'version ' '{print $2 }')
    fi
  fi

  if [ -z "$CONTAINER_CMD" ]; then
    if [ -n "$(which nerdctl 2> /dev/null)" ]; then
      CONTAINER_CMD=nerdctl
      CONTAINER_ENV_NAME=nerdctl
      CONTAINER_RUNTIME_VERSION_STR=$(nerdctl -v | head -1)
      CONTAINER_RUNTIME_VERSION=$(echo $CONTAINER_RUNTIME_VERSION_STR | awk -F'version ' '{print $2 }')

      # Nerdctl needs no additional config
      return 0
    fi
  fi

  if [ -z "$CONTAINER_CMD" ]; then
    if [ -x "/usr/bin/docker" ] || [ -x "/usr/local/bin/docker" ]; then
      CONTAINER_CMD=docker
      # Docker doesn't uses systemd
      CONTAINER_ENV_NAME=Docker

      # Check container environment
      CONTAINER_RUNTIME_VERSION_STR=$(docker -v | head -1)
      CONTAINER_RUNTIME_VERSION=$(echo $CONTAINER_RUNTIME_VERSION_STR | awk -F'version ' '{print $2 }'|cut -d"," -f1)

      # For Docker we are done here
      return 0
    fi
  fi

  if [ -z "$CONTAINER_CMD" ]; then
    log "No container environment detected!"
    exit 1
  fi

  return 0
}

# Check & setup container environment
check_container_environment

header "Container environment: $CONTAINER_ENV_NAME $CONTAINER_RUNTIME_VERSION"

# Get all the parameters

for a in $@; do

  PARAM=$(echo "$a" | awk '{print tolower($0)}')
  case "$PARAM" in

    -nostop)
      NO_CONTAINER_STOP="yes"
      ;;

    -debug)
      AUTO_TEST_DEBUG=1
      ;;

    logs)
      $CONTAINER_CMD logs $CONTAINER_NAME
      exit 0
      ;;

    bash)
      $CONTAINER_CMD exec -it -w /local/notesdata $CONTAINER_NAME bash
      exit 0
      ;;

    exec)
      container_cmd "$2"
      exit 0
      ;;

    cleanup)
      startscript_cmd cleanup
      exit 0
      ;;

    console)
      startscript_cmd_it console
      exit 0
      ;;

    domino)
      startscript_cmd "$2" "$3" "$4"
      exit 0
      ;;

    stop)
      $CONTAINER_CMD stop $CONTAINER_NAME
      exit 0
      ;;

    rm)
      $CONTAINER_CMD rm $CONTAINER_NAME
      exit 0
      ;;

    root)
      $CONTAINER_CMD exec -it -u 0 $CONTAINER_NAME bash
      exit 0
      ;;

    -image=*)
      CONTAINER_IMAGE=$(echo "$a" | cut -f2 -d= -s)
      ;;

    -json=*)
      RESULT_FILE_JSON=$(echo "$a" | cut -f2 -d= -s)
      ;;

    -csv=*)
      RESULT_FILE_CSV=$(echo "$a" | cut -f2 -d= -s)
      ;;

    -autocfg=*)
      DOMINO_AUTO_CONFIG_JSON_FILE=$(echo "$a" | cut -f2 -d= -s)
      ;;

    -volume=*)
      DOMINO_VOLUME=$(echo "$a" | cut -f2 -d= -s)
      ;;

    -env=*)
      CONTAINER_FULL_ENV_FILE=$(echo "$a" | cut -f2 -d= -s)
      ;;

    -?|-h|-help|help)
      print_help "$0"
      exit 0
      ;;

    *)
      log_error "Invalid parameter [$a]"
      exit 1
      ;;
  esac
done

# Use defaults if not specified in options/environment vars

if [ -z "$DOMINO_VOLUME" ]; then
  DOMINO_VOLUME=/tmp/domino_automation_test_local
fi

# For SELinux always add :Z to any volume mounts
CONTAINER_VOLUMES="-v $DOMINO_VOLUME:/local:Z"

if [ -z "$RESULT_FILE_JSON" ]; then
  RESULT_FILE_JSON=$DOMINO_VOLUME/result_autotest.json
fi

if [ -z "$RESULT_FILE_CSV" ]; then
  RESULT_FILE_CSV=$DOMINO_VOLUME/result_autotest.csv
fi

if [ -z "$DOMINO_AUTO_CONFIG_JSON_FILE" ]; then
  DOMINO_AUTO_CONFIG_JSON_FILE=$SCRIPT_DIR/DominoContainerAutoConfig.json
fi

TECHNICAL_SUPPORT=$DOMINO_VOLUME/notesdata/IBM_TECHNICAL_SUPPORT
CONSOLE_LOG=$TECHNICAL_SUPPORT/console.log
NOTES_LOG=$DOMINO_VOLUME/notes.log

if [ -z "$CONTAINER_IMAGE" ]; then
  CONTAINER_IMAGE=hclcom/domino:latest
fi

IMAGE_ID=$($CONTAINER_CMD images $CONTAINER_IMAGE -q)
if [ -z "$IMAGE_ID" ]; then
  log_error "Image not found [$CONTAINER_IMAGE]"
  exit 1
fi

CONTAINER_ID="$($CONTAINER_CMD inspect --format "{{ .Id }}" $CONTAINER_NAME 2>/dev/null)"

# Cleanup existing test environment just in case

header "Cleanup & setup environment"

if [ -n "$CONTAINER_ID" ]; then
  echo "Stopping existing container [$CONTAINER_ID]"
fi

if [ -n "$CONTAINER_ID" ]; then
  $CONTAINER_CMD stop $CONTAINER_NAME
  $CONTAINER_CMD rm $CONTAINER_NAME
fi

remove_dir "$DOMINO_VOLUME"

# Create empty local Domino server data with full permissions
create_dir "$DOMINO_VOLUME" 777

# Reset results, by default written to the root of the data directory
reset_results

header "Bring up server environment"

if [ -z "$CONTAINER_NETWORK" ]; then
   
  if [ ! -z "$CONTAINER_NETWORK_NAME" ]; then
    CONTAINER_NETWORK="--network=$CONTAINER_NETWORK_NAME"
  fi
fi

if [ -z "$CONTAINER_FULL_ENV_FILE" ]; then
  CONTAINER_FULL_ENV_FILE="$SCRIPT_DIR/.env"
fi

if [ -n "$CONTAINER_FULL_ENV_FILE" ]; then

  if [ -r "$CONTAINER_FULL_ENV_FILE" ]; then
    CONTAINER_ENV_FILE_OPTION="--env-file $CONTAINER_FULL_ENV_FILE"
  else
    log_error "Error - Cannot read environment file [$CONTAINER_FULL_ENV_FILE]"
  fi
fi

if [ ! -z "$CONTAINER_NOTES_UID" ]; then
  CONTAINER_NOTES_UID_OPTION="--user $CONTAINER_NOTES_UID"
fi

if [ -z "$CONTAINER_HEALTH_CHECK" ]; then
  CONTAINER_HEALTH_CHECK="--health-cmd=/healthcheck.sh --health-interval=10s --health-retries=4 --health-start-period=30s"
fi


IMAGE_VERSION="$($CONTAINER_CMD inspect --format "{{ .Config.Labels.version }}" $CONTAINER_IMAGE 2>/dev/null)"
IMAGE_BUILDTIME="$($CONTAINER_CMD inspect --format "{{ .Config.Labels.buildtime }}" $CONTAINER_IMAGE 2>/dev/null)"
IMAGE_DOMINO_VERSION="$($CONTAINER_CMD inspect --format "{{ index .Config.Labels \"DominoDocker.version\" }}" $CONTAINER_IMAGE 2>/dev/null)"

$CONTAINER_CMD run -d -it $CONTAINER_PORTS --hostname=$CONTAINER_HOSTNAME --name $CONTAINER_NAME $CONTAINER_NETWORK $CONTAINER_ENV_FILE_OPTION $CONTAINER_NOTES_UID_OPTION $CONTAINER_VOLUMES --stop-timeout=$DOMINO_SHUTDOWN_TIMEOUT --cap-add=SYS_PTRACE --cap-add=NET_BIND_SERVICE $CONTAINER_HEALTH_CHECK $CONTAINER_IMAGE

echo "Copying OneTouch configuration into container"

count=10
while [ $count -gt 0 ]; do
  sleep 1
  $CONTAINER_CMD cp "$DOMINO_AUTO_CONFIG_JSON_FILE" $CONTAINER_NAME:/local/notesdata/DominoAutoConfig.json
  if [ "$?" = "0" ];then
    count=0
  else
    count=$(expr $count - 1)
  fi
done

LINUX_PRETTY_NAME=$($CONTAINER_CMD exec $CONTAINER_NAME cat /etc/os-release | grep "PRETTY_NAME="| cut -d= -f2 | xargs)

kernelVersion="$($CONTAINER_CMD exec $CONTAINER_NAME uname -r)"
kernelBuildTime="$($CONTAINER_CMD exec $CONTAINER_NAME uname -v)"
glibcVersion=$($CONTAINER_CMD exec $CONTAINER_NAME rpm -qa|grep -e "glibc-[0-9]+*")
libstdcVersion=$($CONTAINER_CMD exec $CONTAINER_NAME rpm -qa|grep -e "libstdc++-[0-9]+*")
timezone=$($CONTAINER_CMD exec $CONTAINER_NAME readlink /etc/localtime | awk -F'/zoneinfo/' '{print $2}')
javaVersion=$($CONTAINER_CMD exec $CONTAINER_NAME /opt/hcl/domino/notes/latest/linux/jvm/bin/java -version 2>&1 | grep "openjdk version" | awk -F "openjdk version" '{print $2}' | xargs)

header $LINUX_PRETTY_NAME

# Start testing ..

log_json_begin
log_json_begin testResults

# Write test meta data

log_json "harness" "DominoCommunityImage"
log_json "suite" "Regression"
log_json "testClient" "testing.notes.lab"
log_json "testServer" "testing.notes.lab"
log_json "platform" "$LINUX_PRETTY_NAME"
log_json "testBuild" "$IMAGE_VERSION"

log_json "containerPlatform" "$CONTAINER_ENV_NAME"
log_json "containerPlatformVersion" "$CONTAINER_RUNTIME_VERSION"

log_json "kernelVersion" "$kernelVersion"
log_json "kernelBuildTime" "$kernelBuildTime"
log_json "glibcVersion" "$glibcVersion"
log_json "libstdcVersion" "$libstdcVersion"
log_json "timezone" "$timezone"
log_json "javaVersion" "$javaVersion"


log_json_begin_array testcase


# Check if Traveler binary exits
traveler_binary=$($CONTAINER_CMD exec $CONTAINER_NAME find /opt/hcl/domino/notes/latest/linux/traveler 2>/dev/null)

if [ -n "$traveler_binary" ]; then
  echo "Info: Traveler Server detected"
fi

# Check if Nomad Server binary exists
nomad_binary=$($CONTAINER_CMD exec $CONTAINER_NAME find /opt/hcl/domino/notes/latest/linux/nomad 2>/dev/null)
if [ -n "$nomad_binary" ]; then
  echo "Info: Nomad Server detected"
fi


# Test Java Version

ERROR_MSG=

header "Check Java Version"

java_version=$($CONTAINER_CMD exec $CONTAINER_NAME /opt/hcl/domino/notes/latest/linux/jvm/bin/java -version 2>&1 | grep "openjdk version" | awk -F "openjdk version" '{print $2}' | xargs)

log "JVM Version: $java_version"

if [ -z "$java_version" ];then
  ERROR_MSG="No JVM found"
fi

test_result "domino.jvm.available" "Domino JVM available" "" "$ERROR_MSG"


# Test server running

ERROR_MSG=
wait_for_string $CONSOLE_LOG "Server started on physical node" 100
SERVER_STATUS=$?

if [ "$SERVER_STATUS" = "0" ];then
  ERROR_MSG="Domino server failed to start"
fi

test_result "domino.server.running" "Domino Server startup" "" "$ERROR_MSG"


# Check if OSGI is needed, else disable to reduce HTTP start/stop time

if [ -n "$traveler_binary" ]; then
  osgi_needed=1
fi

if [ -z "$osgi_needed" ]; then
  server_console_cmd "set config iNotesDisableXPageCmd=1"
fi


# Start HTTP or Traveler task

if [ -z "$traveler_binary" ]; then
  header "Starting HTTP"
  server_console_cmd "load http"
  sleep 2
else
  header "Starting Traveler"
  server_console_cmd "load traveler"
  sleep 2
fi

# Start Nomad Server task

if [ -n "$nomad_binary" ]; then
  header "Starting Nomad Server"
  server_console_cmd "load nomad"
fi


# Test if HTTP is running

ERROR_MSG=

wait_for_string $CONSOLE_LOG "HTTP Server: Started" 70 1
HTTPS_STATUS=$?

if [ "$HTTP_STATUS" = "0" ];then
  ERROR_MSG="Domino server failed to start"
fi

test_result "domino.http.running" "Domino HTTP Server running" "" "$ERROR_MSG"

# Test Download certificate chain

ERROR_MSG=

header "Download certificate chain"

$CONTAINER_CMD exec $CONTAINER_NAME /opt/hcl/domino/notes/latest/linux/jvm/bin/keytool -printcert -rfc -sslserver automation.notes.lab > "$DOMINO_VOLUME/notesdata/cert.pem" 
CURL_OPTIONS="--cacert /local/notesdata/cert.pem"

if [ ! -e "$DOMINO_VOLUME/notesdata/cert.pem" ];then
  ERROR_MSG="No certificate chain downloaded"
fi

CERTIFCATE_COUNT=$(grep -e "-----END CERTIFICATE-----" "$DOMINO_VOLUME/notesdata/cert.pem" | wc -l) 

if [ "$CERTIFCATE_COUNT" != "2" ];then
  ERROR_MSG="Wrong number of certificates found: $CERTIFCATE_COUNT, expected: 2"
fi

test_result "domino.certificate.available" "Certificate chain downloaded" "" "$ERROR_MSG"

# Test One Touch MicroCA create

ERROR_MSG=

curl_count=$($CONTAINER_CMD exec $CONTAINER_NAME curl $CURL_OPTIONS -vs -I https://automation.notes.lab 2>&1 | grep "subject: O=Automation MicroCA Certificate" | wc -l)

if [ "$curl_count" = "0" ]; then
  ERROR_MSG="No HTTPS certificate response from Domino"
  echo
  print_delim
  $CONTAINER_CMD exec $CONTAINER_NAME curl $CURL_OPTIONS -vs -I https://automation.notes.lab
  print_delim
  echo
fi

test_result "domino.server.onetouch.microca-cert" "Domino One Touch create MicroCA" "" "$ERROR_MSG"

# Test Traveler server available

if [ -n "$traveler_binary" ]; then

  wait_for_string $CONSOLE_LOG "Traveler: Server started." 50 
  sleep 2

  traveler_status=$($CONTAINER_CMD exec $CONTAINER_NAME curl $CURL_OPTIONS -u "$USER:$PASSWORD" -s 'https://automation.notes.lab/traveler?action=getStatus' 2>&1)

  if [ "$traveler_status" = "Traveler server is available." ]; then
    ERROR_MSG=
  else
    ERROR_MSG="Invalid response to status command: [$traveler_status]"
  fi

  test_result "traveler.server.available" "Traveler server available" "" "$ERROR_MSG"
fi

# Test Nomad server available

if [ -n "$nomad_binary" ]; then

  wait_for_string $CONSOLE_LOG "Nomad: Server initialized" 50
  sleep 2

  curl_count=$($CONTAINER_CMD exec $CONTAINER_NAME curl $CURL_OPTIONS -vs -I https://automation.notes.lab:9443 2>&1 | grep "subject: O=Automation MicroCA Certificate" | wc -l)

  if [ "$curl_count" = "0" ]; then
    ERROR_MSG="No HTTPS certificate response from Domino"
    echo
    print_delim
    $CONTAINER_CMD exec $CONTAINER_NAME curl $CURL_OPTIONS -vs -I https://automation.notes.lab:9443
    print_delim
    echo
  fi

  test_result "nomad.server.available" "Nomad server available" "" "$ERROR_MSG"
fi


# Test OneTouch database create

ERROR_MSG=

if [ ! -e "$DOMINO_VOLUME/notesdata/iwaredir.nsf" ]; then
  ERROR_MSG="iwaredir.nsf not created"
fi

test_result "domino.server.onetouch.createdb" "Domino One Touch create database" "" "$ERROR_MSG"


# Test ID-Vault

ERROR_MSG=

if [ ! -e "$DOMINO_VOLUME/notesdata/IBM_ID_VAULT/dominolab_vault.nsf" ]; then
  ERROR_MSG="Vault database not created"
fi

if [ ! -e "$DOMINO_VOLUME/notesdata/vault.id" ]; then
  ERROR_MSG="Vault.id not created"
fi

test_result "domino.idvault.create" "Domino ID Vault create" "" "$ERROR_MSG"


# Test Backup database

ERROR_MSG=

server_console_cmd "load backup"
sleep 2
server_console_cmd "load backup log.nsf"

# Wait up to 10 seconds for log.nsf backup to be created
count=10
while [ $count -gt 0 ]; do
  sleep 1
  count_backup=$(find $DOMINO_VOLUME/backup -name "log.nsf" 2>/dev/null | wc -l)

  if [ "$count_backup" = "0" ];then
    count=$(expr $count - 1)
  else
    count=0
  fi
done

if [ "$count_backup" = "0" ]; then
  ERROR_MSG="Database backup not found"
fi

test_result "domino.backup.create" "Backup create" "" "$ERROR_MSG"

# Test Start Script: archivelog

ERROR_MSG=

startscript_cmd "archivelog"
sleep 2

logs_archived=$(find $DOMINO_VOLUME/notesdata/ -name "notes_*.log.gz" |wc -l)

if [ "$logs_archived" = "0" ]; then
  ERROR_MSG="Start script archive logs failed"
fi

test_result "startscript.archivelog" "Start Script archivelog" "" "$ERROR_MSG"


# Test Start Script: restart

ERROR_MSG=

CONTAINER_HEALTH="$($CONTAINER_CMD inspect --format "{{ .State.Health.Status }}" $CONTAINER_NAME 2>/dev/null)"

if [ "$CONTAINER_HEALTH" != "healthy" ];then
  ERROR_MSG="Container not healthy"
  echo
  print_delim
  $CONTAINER_CMD inspect --format "{{ .State.Health.Status }}" $CONTAINER_NAME
  print_delim
  $CONTAINER_CMD ps
  print_delim
  echo
fi

test_result "container.health" "Container health" "" "$ERROR_MSG"


# Test Start Script: restart

ERROR_MSG=

startscript_cmd "restart"

wait_for_string $CONSOLE_LOG "Restart Recovery complete" 60

SERVER_RESTART=$?

if [ "$SERVER_RESTART" = "0" ];then
  ERROR_MSG="Domino server failed to restart"
fi

test_result "startscript.server.restart" "Start Script restart server" "" "$ERROR_MSG"

# --- Operations after server restart ---


# Test: Check if transaction logs have been created

ERROR_MSG=

count_txn=$(find $DOMINO_VOLUME/translog -name "*.TXN" | wc -l)

if [ "$count_txn" = "0" ]; then
  ERROR_MSG="Translog not created"
fi

test_result "domino.translog.create" "Translog create" "" "$ERROR_MSG"


# Wait until SMTP started
wait_for_string $CONSOLE_LOG "SMTP Server: Started" 30

# SMTP takes some time to be fully available
sleep 10 

MAIL_TXT=$DOMINO_VOLUME/notesdata/email.txt
MAIL_FROM=john.doe@acme.com
MAIL_TO=fadmin@notes.lab
SUBJECT="Hello via CURL"
RANDOM_TXT=$(echo $RANDOM | sha256sum | head -c 64)
SMTP_SERVER="smtp://automation.notes.lab"
POP3_SERVER="pop3s://automation.notes.lab"

# Create mail txt file
echo > $MAIL_TXT
echo "From: <$MAIL_FROM>" >> $MAIL_TXT
echo "To: <$MAIL_TO>" >> $MAIL_TXT
echo "Subject: $SUBJECT" >> $MAIL_TXT
echo "Date: $(date)" >> $MAIL_TXT

# Add the random text to the body to identify the message
echo "$RANDOM_TXT" >> $MAIL_TXT

# Send message

$CONTAINER_CMD exec $CONTAINER_NAME curl $CURL_OPTIONS -s --ssl-reqd --mail-from "$MAIL_FROM" --mail-rcpt "$MAIL_TO" --upload-file /local/notesdata/email.txt "$SMTP_SERVER"

if  [ "$?" != "0" ]; then
  ERROR_MSG="Mail send failed"
fi


check_pop3()
{
  local MESSAGES=$($CONTAINER_CMD exec $CONTAINER_NAME curl $CURL_OPTIONS -s -u "$USER:$PASSWORD" "$POP3_SERVER" | wc -l)
  local RESULT=
  local COUNT=$MESSAGES
  local TEXT2FIND="$1"

  echo "Pop3 Messages: [$MESSAGES]"

  if [ -z "$MESSAGES" ]; then
    return 0
  fi

  while [ $COUNT -gt 0 ]; do
    RESULT=$($CONTAINER_CMD exec $CONTAINER_NAME curl $CURL_OPTIONS -s -u "$USER:$PASSWORD" "$POP3_SERVER/$COUNT" | grep "$TEXT2FIND")

    if [ -n "$RESULT" ]; then
       return $COUNT
    fi

    COUNT=$(expr $COUNT-1)
  done

  return 0
}

# Wait until POP3 started
wait_for_string $CONSOLE_LOG "POP3 Server: Started" 30

check_pop3 "$RANDOM_TXT"

if [ "$?" = "0" ]; then
  if [ -z "$ERROR_MSG" ]; then
    ERROR_MSG="Mail receive failed"
  fi
fi

test_result "domino.smtp_pop3.mail" "Mail sent/received" "" "$ERROR_MSG"


# Run custom commands 

if [ -n "$CUSTOM_AUTOMATION_CHECK_SCRIPT" ]; then
  if [ -x "$CUSTOM_AUTOMATION_CHECK_SCRIPT" ]; then

    # Export useful variables
    export CONTAINER_CMD
    export DOMINO_VOLUME

    $CUSTOM_AUTOMATION_CHECK_SCRIPT
  fi
fi

# Shutdown environment and collect the logs

if [ "$NO_CONTAINER_STOP" = "yes" ]; then
  log "Skipping shutdown"
else

  # Compressing logs and keep them, when a test failed
  if [ "$count_error" != "0" ]; then
    $CONTAINER_CMD exec $CONTAINER_NAME tar -czf local/ibm_technical_support.taz /local/notesdata/IBM_TECHNICAL_SUPPORT >/dev/null 2>&1
  fi

  # Delete created directories created during load test
  $CONTAINER_CMD exec $CONTAINER_NAME find /local -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} \;
  # Sometimes the first delete does not remove all files. A second delete always cleaned the remaining files.
  $CONTAINER_CMD exec $CONTAINER_NAME find /local -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} \;

  # Change permissions to provide access for all remaining files to world
  $CONTAINER_CMD exec $CONTAINER_NAME chmod -R u+rw,g+rw,o+rw /local >/dev/null 2>&1

  header "Shutting down server environment"
  $CONTAINER_CMD stop $CONTAINER_NAME
  $CONTAINER_CMD rm $CONTAINER_NAME
fi

# End testing

log_json_end_array testcase
log_json_end testResults
log_json_end

log
print_runtime
log

show_results

# Cleanup test data directory and keep logs

if [ "$NO_CONTAINER_STOP" = "yes" ]; then
  log "Keeping Domino server running on request"
fi

# Return number of errors (0 = success)
exit $count_error

