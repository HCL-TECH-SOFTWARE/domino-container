#!/bin/bash

###########################################################################
# Automation Test Script                                                  #
# ----------------------                                                  #
# Version 1.1.0 01.08.2025                                                #
#                                                                         #
# This script implements automation testing the Domino Community image    #
#                                                                         #
# (C) Copyright Daniel Nashed/NashCom 2022-2025                           #
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
KEEP_API_URL="http://automation.notes.lab:8880"

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


detect_container_environment()
{

  if [ -n "$CONTAINER_CMD" ]; then
    return 0
  fi

  if [ -n "$USE_DOCKER" ]; then
     CONTAINER_CMD=docker
     return 0
  fi

  CONTAINER_RUNTIME_VERSION_STR=$(podman -v 2> /dev/null | head -1)
  if [ -n "$CONTAINER_RUNTIME_VERSION_STR" ]; then
    CONTAINER_CMD=podman
    return 0
  fi

  CONTAINER_RUNTIME_VERSION_STR=$(nerdctl -v 2> /dev/null | head -1)
  if [ -n "$CONTAINER_RUNTIME_VERSION_STR" ]; then
    CONTAINER_CMD=nerdctl
    return 0
  fi

  CONTAINER_RUNTIME_VERSION_STR=$(docker -v 2> /dev/null | head -1)
  if [ -n "$CONTAINER_RUNTIME_VERSION_STR" ]; then
    CONTAINER_CMD=docker
    return 0
  fi

  if [ -z "$CONTAINER_CMD" ]; then
    log "No container environment detected!"
    exit 1
  fi

  return 0
}

check_version()
{
  count=1

  while true
  do
    VER=$(echo $1|cut -d"." -f $count)
    CHECK=$(echo $2|cut -d"." -f $count)

    if [ -z "$VER" ]; then return 0; fi
    if [ -z "$CHECK" ]; then return 0; fi

    if [ $VER -gt $CHECK ]; then return 0; fi
    if [ $VER -lt $CHECK ]; then
      echo "Warning: Unsupported $3 version $1 - Must be at least $2 !"
      sleep 1
      return 1
    fi

    count=$(expr $count + 1)
  done

  return 0
}

check_container_environment()
{
  DOCKER_MINIMUM_VERSION="26.0.0"
  PODMAN_MINIMUM_VERSION="3.3.0"

  CONTAINER_ENV_NAME=
  CONTAINER_RUNTIME_VERSION=

  detect_container_environment

  if [ "$CONTAINER_CMD" = "docker" ]; then

    CONTAINER_ENV_NAME=docker
    if [ -z "$CONTAINER_RUNTIME_VERSION_STR" ]; then
      CONTAINER_RUNTIME_VERSION_STR=$(docker -v 2> /dev/null | head -1)
    fi
    CONTAINER_RUNTIME_VERSION=$(echo $CONTAINER_RUNTIME_VERSION_STR | awk -F'version ' '{print $2 }'|cut -d"," -f1)

    # Check container environment
    check_version "$CONTAINER_RUNTIME_VERSION" "$DOCKER_MINIMUM_VERSION" "$CONTAINER_CMD"

    # Use sudo for docker command if not root on Linux

    if [ $(uname) = "Linux" ]; then
      if [ ! "$EUID" = "0" ]; then
        if [ "$DOCKER_USE_SUDO" = "yes" ]; then
          CONTAINER_CMD="sudo $CONTAINER_CMD"
        fi
      fi
    fi

  fi

  if [ "$CONTAINER_CMD" = "podman" ]; then

    check_version "$CONTAINER_RUNTIME_VERSION" "$PODMAN_MINIMUM_VERSION" "$CONTAINER_CMD"

    CONTAINER_ENV_NAME=podman
    if [ -z "$CONTAINER_RUNTIME_VERSION_STR" ]; then
      CONTAINER_RUNTIME_VERSION_STR=$(podman -v 2> /dev/null | head -1)
    fi
    CONTAINER_RUNTIME_VERSION=$(echo $CONTAINER_RUNTIME_VERSION_STR | awk -F'version ' '{print $2 }')

  fi

  if [ "$CONTAINER_CMD" = "nerdctl" ]; then

    CONTAINER_ENV_NAME=nerdctl
    if [ -z "$CONTAINER_RUNTIME_VERSION_STR" ]; then
      CONTAINER_RUNTIME_VERSION_STR=$(nerdctl -v 2> /dev/null | head -1)
    fi
    CONTAINER_RUNTIME_VERSION=$(echo $CONTAINER_RUNTIME_VERSION_STR | awk -F'version ' '{print $2 }')

    if [ -z "$CONTAINER_NAMESPACE" ]; then
      CONTAINER_NAMESPACE=k8s.io
    fi

    # Always add namespace option to nerdctl command line
    CONTAINER_CMD="$CONTAINER_CMD --namespace=$CONTAINER_NAMESPACE"

  fi

  if [ -z "$DOCKER_NETWORK" ]; then
    if [ -n "$DOCKER_NETWORK_NAME" ]; then
      CONTAINER_NETWORK_CMD="--network=$CONTAINER_NETWORK_NAME"
    fi
  fi

  return 0
}


show_version ()
{
  echo
  echo HCL Domino Container Build Script
  echo ---------------------------------
  echo "Version $CONTAINER_BUILD_SCRIPT_VERSION"
  echo "(Running on $CONTAINER_ENV_NAME Version $CONTAINER_RUNTIME_VERSION)"
  echo
  return 0
}

dump_var()
{
  header "$1"
  echo
  echo "$2"
  echo
}

log_addon_detected()
{
  if [ -z "$1" ]; then
    return 0
  fi

  echo "[X] $2"
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
      if [ "$2" = "root" ]; then
        $CONTAINER_CMD exec -it -w /local/notesdata -u 0 $CONTAINER_NAME bash
      else
        $CONTAINER_CMD exec -it -w /local/notesdata $CONTAINER_NAME bash
      fi
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

# Overwrite the standard testing file and only use a automation test specific file
DOMINO_AUTO_CONFIG_JSON_FILE=$SCRIPT_DIR/DominoContainerAutoConfig.json

if [ -n "$DOMINO_AUTO_CONFIG_TESTING_JSON_FILE" ]; then
  DOMINO_AUTO_CONFIG_JSON_FILE="$DOMINO_AUTO_CONFIG_TESTING_JSON_FILE"
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
IMAGE_SIZE="$($CONTAINER_CMD inspect --format "{{ .Size }}" $CONTAINER_IMAGE 2>/dev/null)"

CONTAINER_DOMINO_ADDONS="$($CONTAINER_CMD inspect --format "{{ index .Config.Labels \"DominoContainer.addons\" }}" $CONTAINER_IMAGE 2>/dev/null)"

$CONTAINER_CMD run -d -it $CONTAINER_PORTS --hostname=$CONTAINER_HOSTNAME --name $CONTAINER_NAME $CONTAINER_NETWORK $CONTAINER_ENV_FILE_OPTION $CONTAINER_NOTES_UID_OPTION $CONTAINER_VOLUMES --stop-timeout=$DOMINO_SHUTDOWN_TIMEOUT --cap-add=SYS_PTRACE --cap-add=NET_BIND_SERVICE -e NO_PROXY="127.0.0.1,localhost,$CONTAINER_HOSTNAME" -e no_proxy="127.0.0.1,localhost,$CONTAINER_HOSTNAME" $CONTAINER_HEALTH_CHECK $CONTAINER_IMAGE

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

HOST_LINUX_PRETTY_NAME=$(cat /etc/os-release | grep "PRETTY_NAME="| cut -d= -f2 | xargs)
HOST_LINUX_VERSION=$(cat /etc/os-release | grep "VERSION="| cut -d= -f2 | xargs)

LINUX_PRETTY_NAME=$($CONTAINER_CMD exec $CONTAINER_NAME cat /etc/os-release | grep "PRETTY_NAME="| cut -d= -f2 | xargs)
LINUX_VERSION=$($CONTAINER_CMD exec $CONTAINER_NAME cat /etc/os-release | grep "VERSION="| cut -d= -f2 | xargs)

kernelVersion="$($CONTAINER_CMD exec $CONTAINER_NAME uname -r)"
kernelBuildTime="$($CONTAINER_CMD exec $CONTAINER_NAME uname -v)"
glibcVersion=$($CONTAINER_CMD exec $CONTAINER_NAME ldd --version| head -1 | rev | cut -d' ' -f1 | rev)
timezone=$($CONTAINER_CMD exec $CONTAINER_NAME readlink /etc/localtime | awk -F'/zoneinfo/' '{print $2}')
javaVersion=$($CONTAINER_CMD exec $CONTAINER_NAME /opt/hcl/domino/notes/latest/linux/jvm/bin/java -version 2>&1 | grep "openjdk version" | awk -F "openjdk version" '{print $2}' | xargs)
curl_version=$($CONTAINER_CMD exec $CONTAINER_NAME curl -V)

header $LINUX_PRETTY_NAME

# Wait until server is started
wait_for_string $CONSOLE_LOG "Server started on physical node" 100

# Start Tika process and get version
$CONTAINER_CMD exec $CONTAINER_NAME bash -c '/opt/hcl/domino/notes/latest/linux/jvm/bin/java -jar /opt/hcl/domino/notes/latest/linux/tika-server.jar -noFork --port 1234 > /tmp/tika.log 2>&1 &'
TIKA_VERSION_STR=$($CONTAINER_CMD exec $CONTAINER_NAME curl --retry 10 --retry-delay 1 --retry-connrefused --silent http://127.0.0.1:1234/version)
# Try again after one second to ensure we get a proper result
sleep 1
TIKA_VERSION_STR=$($CONTAINER_CMD exec $CONTAINER_NAME curl --retry 10 --retry-delay 1 --retry-connrefused --silent http://127.0.0.1:1234/version)
TIKA_VERSION=$(echo "$TIKA_VERSION_STR" | awk -F "Apache Tika" '{print $2}' | xargs)

# Start testing ..

log_json_begin
log_json_begin testResults

# Write test meta data

log_json "harness" "DominoCommunityImage"
log_json "suite" "Regression"
log_json "testClient" "testing.notes.lab"
log_json "testServer" "testing.notes.lab"
log_json "platform" "$LINUX_PRETTY_NAME"
log_json "platformVersion" "$LINUX_VERSION"
log_json "hostVersion" "$HOST_LINUX_VERSION"
log_json "hostPlatform" "$HOST_LINUX_PRETTY_NAME"
log_json "testBuild" "$IMAGE_VERSION"
log_json "imageSize" "$IMAGE_SIZE"

log_json "containerPlatform" "$CONTAINER_ENV_NAME"
log_json "containerPlatformVersion" "$CONTAINER_RUNTIME_VERSION"

log_json "kernelVersion" "$kernelVersion"
log_json "kernelBuildTime" "$kernelBuildTime"
log_json "glibcVersion" "$glibcVersion"
log_json "timezone" "$timezone"
log_json "javaVersion" "$javaVersion"
log_json "tikaVersion" "$TIKA_VERSION"
log_json "dominoAddons" "$CONTAINER_DOMINO_ADDONS"


log_json_begin_array testcase

header "Detecting JVM Lib Install Directory"

if [ -n "$($CONTAINER_CMD exec $CONTAINER_NAME find /opt/hcl/domino/notes/latest/linux/ndext)" ]; then
  JVM_LIB_INSTALL_DIRECTORY="/opt/hcl/domino/notes/latest/linux/ndext"
elif [ -n "$($CONTAINER_CMD exec $CONTAINER_NAME find /opt/hcl/domino/notes/latest/jvm/ext)" ]; then
  JVM_LIB_INSTALL_DIRECTORY="$Notes_ExecDirectory/jvm/lib/ext"
else
  JVM_LIB_INSTALL_DIRECTORY=
fi

log
log "$JVM_LIB_INSTALL_DIRECTORY"
log


header "Detecting Add-Ons"

# Check if Traveler binary exits
traveler_binary=$($CONTAINER_CMD exec $CONTAINER_NAME find /opt/hcl/domino/notes/latest/linux/traveler 2>/dev/null)
log_addon_detected "$traveler_binary" "Traveler Server"

# Check if Nomad Server binary exists
nomad_binary=$($CONTAINER_CMD exec $CONTAINER_NAME find /opt/hcl/domino/notes/latest/linux/nomad 2>/dev/null)
log_addon_detected "$nomad_binary" "Nomad Server"

# Check if REST-API binary exists
domrestapi_binary=$($CONTAINER_CMD exec $CONTAINER_NAME find /opt/hcl/domino/notes/latest/linux/restapi 2>/dev/null)
log_addon_detected "$domrestapi_binary" "Domino REST-API"

# Check if Domino Leap/Volt jar exists
dleap_jar=$($CONTAINER_CMD exec $CONTAINER_NAME find /opt/hcl/domino/notes/latest/linux/osgi/volt/eclipse/plugins -name "dleap*.jar" 2>/dev/null)
log_addon_detected "$dleap_jar" "Domino Leap"

# Check if Verse jar exists
verse_jar=$($CONTAINER_CMD exec $CONTAINER_NAME find /opt/hcl/domino/notes/latest/linux/osgi/shared/eclipse/plugins -name "core-*.jar" 2>/dev/null)

if [ -z "$verse_jar" ]; then
  sleep 10
  verse_jar=$($CONTAINER_CMD exec $CONTAINER_NAME find /local/notesdata/domino/workspace/applications/eclipse/plugins -name "core-*.jar" 2>/dev/null)
fi

log_addon_detected "$verse_jar" "HCL Verse"

lp_strings=$($CONTAINER_CMD exec $CONTAINER_NAME find /opt/hcl/domino/notes/latest/linux/res/C -name "strings_*.res" | awk -F "strings_" '{print $2}' | cut -d. -f1 2>/dev/null)

log_addon_detected "$lp_strings" "Language Pack [$lp_strings]"

# Check if OnTime binary exists
ontime_binary=$($CONTAINER_CMD exec $CONTAINER_NAME find /opt/hcl/domino/notes/latest/linux/ontimegc 2>/dev/null)
log_addon_detected "$ontime_binary" "OnTime group calendar"

# Check if C-API global.h and lib notes0.o exists
capi_lib=$($CONTAINER_CMD exec $CONTAINER_NAME find /opt/hcl/domino/notesapi/lib/linux64/notes0.o 2>/dev/null)
capi_include=$($CONTAINER_CMD exec $CONTAINER_NAME find /opt/hcl/domino/notesapi/include/global.h 2>/dev/null)

log_addon_detected "$capi_include" "C-API SDK"

domiq_binary=$($CONTAINER_CMD exec $CONTAINER_NAME find /opt/hcl/domino/notes/latest/linux/llama-server 2>/dev/null)
log_addon_detected "$domiq_binary" "DominoIQ Server"

domprom_binary=$($CONTAINER_CMD exec $CONTAINER_NAME find /opt/hcl/domino/notes/latest/linux/domprom 2>/dev/null)
log_addon_detected "$domprom_binary" "Domino Prom stats exporter"

node_exporter_binary=$($CONTAINER_CMD exec $CONTAINER_NAME find /opt/prometheus/node_exporter/node_exporter 2>/dev/null)
log_addon_detected "$node_exporter_binary" "Prometheus Node Exporter"

nshmailx_binary=$($CONTAINER_CMD exec $CONTAINER_NAME find /usr/bin/nshmailx 2>/dev/null)
log_addon_detected "$nshmailx_binary" "Nash!Com nshmailx"

borg_binary=$($CONTAINER_CMD exec $CONTAINER_NAME find /usr/bin/borg 2>/dev/null)
log_addon_detected "$borg_binary" "Borg Backup"

domborg_binary=$($CONTAINER_CMD exec $CONTAINER_NAME find /usr/bin/nshborg 2>/dev/null)
log_addon_detected "$borg_binary" "Domino Borg Backup helper"

mysql_jdbc_binary=$($CONTAINER_CMD exec $CONTAINER_NAME find /opt/hcl/domino/notes/latest/linux/Traveler/lib -name "mysql-connector-j-*.jar" 2>/dev/null)
log_addon_detected "$mysql_jdbc_binary" "MySQL JDBC driver for Traveler"

postgresql_jdbc_binary=$($CONTAINER_CMD exec $CONTAINER_NAME find /opt/hcl/domino/notes/latest/linux/Traveler/lib -name "postgresql-*.jar"  2>/dev/null)
log_addon_detected "$postgresql_jdbc_binary" "PostgreSQL JDBC driver for Traveler"

mysql_jdbc_binary=$($CONTAINER_CMD exec $CONTAINER_NAME find "$JVM_LIB_INSTALL_DIRECTORY" -name "mysql-connector-j-*.jar" 2>/dev/null)
log_addon_detected "$mysql_jdbc_binary" "MySQL JDBC driver for Domino"

postgresql_jdbc_binary=$($CONTAINER_CMD exec $CONTAINER_NAME find "$JVM_LIB_INSTALL_DIRECTORY" -name "postgresql-*.jar"  2>/dev/null)
log_addon_detected "$postgresql_jdbc_binary" "PostgreSQL JDBC driver for Domino"


OLDIFS=$IFS
IFS=$'\n'

for ADDON_LINE in $(echo "$CONTAINER_DOMINO_ADDONS" | tr ',' '\n' | tr -d ' ');
do

  ERROR_MSG=
  ADDON_NAME=$(echo $ADDON_LINE | cut -d'=' -f1)
  ADDON_VERSION=$(echo $ADDON_LINE | cut -d'=' -f2)

  case "$ADDON_NAME" in

    traveler)
      TRAVELER_IMAGE_VERSION="$ADDON_VERSION"

      if [ -z "$traveler_binary" ]; then
        ERROR_MSG="$ADDON_NAME binary not found"
      fi
      ;;

    nomad)
      NOMAD_IMAGE_VERSION="$ADDON_VERSION"

      if [ -z "$nomad_binary" ]; then
        ERROR_MSG="$ADDON_NAME binary not found"
      fi
      ;;

    domrestapi)
      KEEP_IMAGE_VERSION=$(echo "$ADDON_VERSION" | cut -f1 -d'-')

      if [ -z "$domrestapi_binary" ]; then
        ERROR_MSG="$ADDON_NAME binary not found"
      fi
      ;;

    verse)
      VERSE_IMAGE_VERSION="$ADDON_VERSION"

      if [ -z "$verse_jar" ]; then
        ERROR_MSG="$ADDON_NAME main jar not found"
      fi
      ;;

    leap)
      LEAP_IMAGE_VERSION="$ADDON_VERSION"

      if [ -z "$dleap_jar" ]; then
        ERROR_MSG="$ADDON_NAME main jar not found"
      fi
      ;;

    capi)
      CAPI_IMAGE_VERSION="$ADDON_VERSION"

      if [ -z "$capi_lib" ] || [ -z "$capi_include" ]; then
        ERROR_MSG="$$ADDON_NAME not found"
      fi
      ;;

    languagepack)
      if [ -z "$lp_strings" ]; then
        ERROR_MSG="$ADDON_NAME not found"
      elif [ -z $(echo "$ADDON_VERSION" | grep -i "$lp_strings" 2>/dev/null) ]; then
        ERROR_MSG="$ADDON_NAME - Wrong Language Pack. Expected: $ADDON_VERSION, Found: $lp_strings"
      fi
      ;;

    ontime)
      ONTIME_IMAGE_VERSION="$ADDON_VERSION"

      if [ -z "$ontime_binary" ]; then
        ERROR_MSG="$ADDON_NAME binary not found"
      fi
      ;;

    domiq)
      DOMIQ_IMAGE_VERSION="$ADDON_VERSION"

      if [ -z "$domiq_binary" ]; then
        ERROR_MSG="$ADDON_NAME binary not found"
      fi
      ;;


    domprom)
      DOMPROM_IMAGE_VERSION="$ADDON_VERSION"

      if [ -z "$domprom_binary" ]; then
        ERROR_MSG="$ADDON_NAME binary not found"
      fi
      ;;

    node_exporter)
      NODE_EXPORTER_IMAGE_VERSION="$ADDON_VERSION"

      if [ -z "$node_exporter_binary" ]; then
        ERROR_MSG="$ADDON_NAME binary not found"
      fi
      ;;

    nshmailx)
      NSHMAILX_IMAGE_VERSION="$ADDON_VERSION"

      if [ -z "$nshmailx_binary" ]; then
        ERROR_MSG="$ADDON_NAME binary not found"
      fi
      ;;

    borg)
      BORG_IMAGE_VERSION="$ADDON_VERSION"

      if [ -z "$borg_binary" ]; then
        ERROR_MSG="$ADDON_NAME binary not found"
      fi
      ;;

    domborg)
      DOMBORG_IMAGE_VERSION="$ADDON_VERSION"

      if [ -z "$domborg_binary" ]; then
        ERROR_MSG="$ADDON_NAME binary not found"
      fi
      ;;

    mysql-jdbc)
      MYSQL_JDBC_IMAGE_VERSION="$ADDON_VERSION"

      if [ -z "$mysql_jdbc_binary" ]; then
        ERROR_MSG="$ADDON_NAME binary not found"
      fi
      ;;

    postgresql-jdbc)
      POSTGRESQL_JDBC_IMAGE_VERSION="$ADDON_VERSION"

      if [ -z "$postgresql_jdbc_binary" ]; then
        ERROR_MSG="$ADDON_NAME binary not found"
      fi
      ;;


    *)
      echo "LATER: [$ADDON_NAME] not checked"
      ;;
  esac

  test_result "addon.installed.$ADDON_NAME" "$ADDON installed" "" "$ERROR_MSG"

done

IFS=$OLDIFS
echo


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

# Start Domino REST-API Server task

if [ -n "$domrestapi_binary" ]; then
  # Wait 10 sec to process the last server command to avoid console buffer errors. We need to wait for HTTP start anyhow
  sleep 10
  header "Starting Domino REST-API"
  server_console_cmd "load restapi"
fi

# Start Nomad Server task

if [ -n "$nomad_binary" ]; then
  # Wait 10 sec to process the last server command to avoid console buffer errors. We need to wait for HTTP start anyhow
  sleep 10
  header "Starting Nomad Server"
  server_console_cmd "load nomad"
fi


# Wait 10 sec to process the last server command to avoid console buffer errors. We need to wait for HTTP start anyhow
sleep 10

# Start HTTP or Traveler task

if [ -z "$traveler_binary" ]; then
  header "Starting HTTP"
  server_console_cmd "load http"
else
  header "Starting Traveler"
  server_console_cmd "load traveler"
fi

sleep 5


# Test if HTTP is running

ERROR_MSG=

wait_for_string $CONSOLE_LOG "HTTP Server: Started" 100 1
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


# Test C-API SDK
if [ -n "$capi_include" ]; then

  header "$Verifying C-API SDK"

  $CONTAINER_CMD cp makefile $CONTAINER_NAME:/tmp
  $CONTAINER_CMD cp nshver.cpp $CONTAINER_NAME:/tmp
  sleep 1

  capi_result=$($CONTAINER_CMD exec -it -w /tmp $CONTAINER_NAME /usr/bin/bash -i -l -c "make test | tail -1" 2>&1)
  capi_version=$(echo $capi_result | grep "DominoVersion=" | cut -d"=" -f2)

  if [ -n "$capi_version" ]; then
    ERROR_MSG=
    echo "C-API SDK verified: $capi_version"
  else
    echo "C-API error: $capi_result"
    ERROR_MSG="Invalid status returned"
  fi

  test_result "capi.compile&run" "C-API SDK compile & run works" "" "$ERROR_MSG"
fi


# Test Traveler server available

if [ -n "$traveler_binary" ]; then

  header "$Verifying Traveler Server"

  wait_for_string $CONSOLE_LOG "Traveler: Server started." 50
  sleep 2

  traveler_status=$($CONTAINER_CMD exec $CONTAINER_NAME curl $CURL_OPTIONS -u "$USER:$PASSWORD" -sL 'https://automation.notes.lab/traveler?action=getStatus' 2>&1)

  if [ "$traveler_status" = "Traveler server is available." ]; then
    ERROR_MSG=
  else
    ERROR_MSG="Invalid response to status command: [$traveler_status]"
  fi

  test_result "traveler.server.available" "Traveler server available" "" "$ERROR_MSG"
fi


# Test Nomad server available

if [ -n "$nomad_binary" ]; then

  header "$Verifying Verifying Nomad Server"

  wait_for_string $CONSOLE_LOG "Listening on 0.0.0.0:9443" 50
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


# Test Verse available

if [ -n "$verse_jar" ]; then

  verse_response=$($CONTAINER_CMD exec $CONTAINER_NAME curl $CURL_OPTIONS -u "$USER:$PASSWORD" -s 'https://automation.notes.lab/verse' 2>&1)
  verse_check=$(echo "$verse_response" | grep "HCL Verse")

  if [ -n "$verse_check" ]; then
    ERROR_MSG=
  else
    ERROR_MSG="Invalid response from Verse URL"
    dump_var "Verse Response" "$verse_response"
  fi

  test_result "verse.server.available" "Verse available" "" "$ERROR_MSG"
fi


# Test Domino REST-API available

if [ -n "$domrestapi_binary" ]; then

  header "$Verifying Verifying Domino REST-API"

  wait_for_string $CONSOLE_LOG "REST API: Started" 50
  sleep 5

  restapi_response=$($CONTAINER_CMD exec $CONTAINER_NAME curl $CURL_OPTIONS -sL $KEEP_API_URL/api 2>&1)

  restapi_check=$(echo "$restapi_response" | grep "HCL Domino REST API")

  if [ -n "$restapi_check" ]; then
    ERROR_MSG=
  else
    ERROR_MSG="Invalid response to status command"
    dump_var "Domino REST-API Response" "$restapi_response"
  fi

  test_result "restapi.server.available" "Domino REST-API available" "" "$ERROR_MSG"

  dump_var "Domino REST-API Response" "$restapi_response"

  # Check authentication and version

  ERROR_MSG=

  KEEP_AUTH_RESULT=$($CONTAINER_CMD exec $CONTAINER_NAME curl -s -X POST --header "Content-Type: application/json" $KEEP_API_URL/api/v1/auth -d "{\"username\": \"$USER\",\"password\": \"$PASSWORD\"}")
  KEEP_AUTH_TOKEN=$(echo "$KEEP_AUTH_RESULT" | jq -r .bearer)

  if [ -z "$KEEP_AUTH_TOKEN" ]; then
    ERROR_MSG="No authentication token returned"
    dump_var "Domino REST-API Authentication Response" "$KEEP_AUTH_RESULT"
  fi

  test_result "restapi.server.authentication" "Domino REST-API authentication OK" "" "$ERROR_MSG"

  ERROR_MSG=

  if [ -z "$KEEP_AUTH_TOKEN" ]; then
    ERROR_MSG="No authentication token returned. Cannot query version"
  else

    KEEP_INFO=$($CONTAINER_CMD exec $CONTAINER_NAME curl -s --header "Content-Type: application/json"  -H "Authorization: Bearer $KEEP_AUTH_TOKEN"  $KEEP_API_URL/api/v1/info)
    KEEP_VERSION=$(echo "$KEEP_INFO" | jq .KeepProperties.version)

    if [ -z "$KEEP_INFO" ]; then
      ERROR_MSG="No keep info returned"

    elif [ -z "$KEEP_VERSION" ]; then
      ERROR_MSG="No keep version returned"

    else
      case "$KEEP_VERSION" in

        *v$KEEP_IMAGE_VERSION*)
          echo "RESTAPI matches expected version: [$KEEP_VERSION]"
          ;;

        *)
          ERROR_MSG="Wrong RESTAPI Version returned"
          ;;
      esac
    fi
  fi

  dump_var "Keep Info" "$KEEP_INFO"
  dump_var "Keep Version" "$KEEP_VERSION"

  test_result "restapi.server.version" "Domino REST-API version OK" "" "$ERROR_MSG"

fi


# Test Domino Leap available

if [ -n "$dleap_jar" ]; then

  header "$Verifying Verifying Domino Leap"

  leap_response=$($CONTAINER_CMD exec $CONTAINER_NAME curl $CURL_OPTIONS -u "$USER:$PASSWORD" -sL 'https://automation.notes.lab/volt-apps' 2>&1)
  echo $CONTAINER_CMD exec $CONTAINER_NAME curl $CURL_OPTIONS -u "$USER:$PASSWORD" -s 'https://automation.notes.lab/volt-apps'

  leap_check=$(echo "$leap_response" | grep "HCL Domino Leap")

  if [ -n "$leap_check" ]; then
    ERROR_MSG=
  else
    ERROR_MSG="Invalid response to status command"
    dump_var "Domino Domino Leap Response" "$leap_response"
  fi

  test_result "domino-leap.server.available" "Domino Leap available" "" "$ERROR_MSG"

  server_console_cmd "tell http osgi ss dleap"
  wait_for_string $CONSOLE_LOG "dleap_" 10

  DLEAP_VERSION=$(grep "dleap_" "$CONSOLE_LOG" | awk -F "dleap_" '{print $2}')

  log "Domino Leap Version: $DLEAP_VERSION"
  if [ -z "$DLEAP_VERSION" ]; then
    ERROR_MSG="Leap version not found"
  fi

  test_result "domino-leap.server.version" "Domino Leap version found" "" "$ERROR_MSG"
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


# Test NSD call stacks via GDB

ERROR_MSG=

header "Running NSD -stacks -nomemcheck ..."

NSD_BEGIN=$SECONDS
startscript_cmd "stacks -nomemcheck" > /dev/null
NSD_END=$SECONDS
NSD_RUNTIME_SECONDS=$(expr $NSD_END - $NSD_BEGIN)

header "NSD Done after $NSD_RUNTIME_SECONDS seconds"

NSD_FILE=$(find $DOMINO_VOLUME/notesdata/IBM_TECHNICAL_SUPPORT -name "nsd*.log")
NSD_SEARCH="$(grep 'ServerMain' $NSD_FILE)"

if [ -z "$NSD_SEARCH" ]; then
  ERROR_MSG="No server main callstack found"
fi

test_result "nsd.gdb" "NSD GDB callstacks" "" "$ERROR_MSG"


# Test Start Script: container health

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

send_smtp_mail()
{
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
}

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


# Mail check depends on curl functionality supporting smtps/pop3s

MAIL_CHECK=1

if [ -z "$(echo $curl_version | grep smtps)" ]; then
  MAIL_CHECK=0
fi

if [ -z "$(echo $curl_version | grep pop3s)" ]; then
  MAIL_CHECK=0
fi


if [ "$MAIL_CHECK" = "0" ]; then

  log
  log "Info: Installed Curl does not support smtps/pop3s --> Skipping test"
  log

else

  send_smtp_mail
  # Wait until POP3 started
  wait_for_string $CONSOLE_LOG "POP3 Server: Started" 30

  check_pop3 "$RANDOM_TXT"

  if [ "$?" = "0" ]; then
    if [ -z "$ERROR_MSG" ]; then
      ERROR_MSG="Mail receive failed"
    fi
  fi

  test_result "domino.smtp_pop3.mail" "Mail sent/received" "" "$ERROR_MSG"

fi


# Test Check Tika version

ERROR_MSG=

if [ -z "$TIKA_VERSION" ]; then
  ERROR_MSG="Tika server failed to restart"
fi

echo "TIKA_VERSION: [$TIKA_VERSION]"

test_result "tikaserver.available" "Check if Tika Server can be started" "" "$ERROR_MSG"


header "Security check"

# Check if no binary has SUID set for root

ERROR_MSG=

SUID_BIN_COUNT=$($CONTAINER_CMD exec $CONTAINER_NAME find /opt -perm -4000 -type f -user root 2>/dev/null | wc -l)

if [ "$SUID_BIN_COUNT" != "0" ]; then
  ERROR_MSG="$SUID_BIN_COUNT binaries have SUID set for root"
  header "Files with SUID for root"
  $CONTAINER_CMD exec $CONTAINER_NAME find /opt -perm -4000 -type f -user root
fi

test_result "security.no-suid-bin" "Ensure not binaries have SUID set for root" "" "$ERROR_MSG"


# Ensure /opt/hcl is not writable

ERROR_MSG=

CHECK_DIR=/opt/hcl

WRITABLE_BIN_COUNT=$($CONTAINER_CMD exec $CONTAINER_NAME find "$CHECK_DIR" -writable 2>/dev/null | wc -l)

if [ "$WRITABLE_BIN_COUNT" != "0" ]; then
  ERROR_MSG="$WRITABLE_BIN_COUNT file in $CHECK_DIR are writable"
  header "Writable files in $CHECK_DIR"
  $CONTAINER_CMD exec $CONTAINER_NAME find "$CHECK_DIR" -writable
  echo
fi

# Work in progress for now don't fail only report if all are read-only. Else the code above lists all files not read only
if [ -z "$ERROR_MSG" ]; then
  test_result "security.domino.bin.readonly" "Ensure $CHECK_DIR is not writable" "" "$ERROR_MSG"
fi


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

