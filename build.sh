#!/bin/bash
############################################################################
# (C) Copyright IBM Corporation 2015, 2018                                 #
#                                                                          #
# Licensed under the Apache License, Version 2.0 (the "License");          #
# you may not use this file except in compliance with the License.         #
# You may obtain a copy of the License at                                  #
#                                                                          #
#      http://www.apache.org/licenses/LICENSE-2.0                          #
#                                                                          #
# Unless required by applicable law or agreed to in writing, software      #
# distributed under the License is distributed on an "AS IS" BASIS,        #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. #
# See the License for the specific language governing permissions and      #
# limitations under the License.                                           #
#                                                                          #
############################################################################

# Main Script to build images 
# Run without parameters for detailed syntax
# The script checks if software is avialable at configured location (download location or local directory).
# In case of a local software directory it hosts the software on a local NGINX container


SCRIPT_NAME=$0
TARGET_IMAGE=$1

TARGET_DIR=`echo $1 | cut -f 1 -d"-"`
EDIT_COMMAND=vi

# (Default) NIGX is used hosting software from the local "software" directory.
# (Optional) Configure software download location.
# DOWNLOAD_FROM=http://192.168.1.1

# With NGINX container you could chose your own local directory or if variable is empty use the default "software" subdirectory 
# SOFTWARE_DIR=/local/software

DominoMoveInstallData=yes

# Default: Update CentOS while building the image
LinuxYumUpdate=yes

# Default: Check if software exits
CHECK_SOFTWARE=yes

# Default config directory. Can be overwritten by environment
if [ -z "$DOMINO_DOCKER_CFG_DIR" ]; then
  DOMINO_DOCKER_CFG_DIR=/local/cfg
fi

# External configuration
CONFIG_FILE=$DOMINO_DOCKER_CFG_DIR/build_config

# use a config file if present
if [ -e "$CONFIG_FILE" ]; then
  echo "(Using config file $CONFIG_FILE)"
  . $CONFIG_FILE
fi


if [ -z "$DOCKER_CMD" ]; then

  if [ -x /usr/bin/podman ]; then
    DOCKER_CMD=podman

  else
    DOCKER_CMD=docker

    # Use sudo for docker command if not root on Linux

    if [ `uname` = "Linux" ]; then
      if [ ! "$EUID" = "0" ]; then
        if [ "$DOCKER_USE_SUDO" = "no" ]; then
          echo "Docker needs root permissions on Linux!"
          exit 1
        fi
      fi
    fi

    DOCKER_CMD="sudo $DOCKER_CMD"
  fi
fi

usage ()
{
  echo
  echo "Usage: `basename $SCRIPT_NAME` { domino | domino-ce | traveler } version fp hf"
  echo
  echo "-checkonly      checks without build"
  echo "-verifyonly     checks download file checksum without build"
  echo "-(no)check      checks if files exist (default: yes)"
  echo "-(no)verify     checks downloaded file checksum (default: no)"
  echo "-(no)url        shows all download URLs, even if file is downloaded (default: no)"
  echo "-(no)linuxupd   updates container Linux  while building image (default: yes)"
  echo "cfg|config      edits config file (either in current directory or if created in /local/cfg)"
  echo "cpcfg           copies the config file to config directory (default: /local/cfg/build_config)"
  echo
  echo "Examples:"
  echo
  echo "  `basename $SCRIPT_NAME` domino 10.0.1 fp3"
  echo "  `basename $SCRIPT_NAME` traveler 10.0.1.2"
  echo

  return 0
}


print_delim ()
{
  echo "--------------------------------------------------------------------------------"
}

header ()
{
  echo
  print_delim
  echo "$1"
  print_delim
  echo
}

dump_config ()
{
  header "Build Configuration"
  echo "DOWNLOAD_FROM      : [$DOWNLOAD_FROM]"
  echo "SOFTWARE_DIR       : [$SOFTWARE_DIR]"
  echo "PROD_NAME          : [$PROD_NAME]"
  echo "PROD_VER           : [$PROD_VER]"
  echo "PROD_FP            : [$PROD_FP]"
  echo "PROD_HF            : [$PROD_HF]"
  echo "PROD_EXT           : [$PROD_EXT]"
  echo "CHECK_SOFTWARE     : [$CHECK_SOFTWARE]"
  echo "CHECK_HASH         : [$CHECK_HASH]"
  echo "DOWNLOAD_URLS_SHOW : [$DOWNLOAD_URLS_SHOW]"
  echo "TAG_LATEST         : [$TAG_LATEST]"
  echo "DOCKER_FILE        : [$DOCKER_FILE]"
  echo "LinuxYumUpdate     : [$LinuxYumUpdate]"
  echo 
  return 0
}

nginx_start ()
{
  # Create a nginx container hosting software download locally

  # Check if we already have this container in status exited
  STATUS="$($DOCKER_CMD inspect --format '{{ .State.Status }}' $SOFTWARE_CONTAINER 2>/dev/null)"

  if [ -z "$STATUS" ]; then
    echo "Creating Docker container: $SOFTWARE_CONTAINER hosting [$SOFTWARE_DIR]"
    $DOCKER_CMD run --name $SOFTWARE_CONTAINER -p $SOFTWARE_PORT:80 -v $SOFTWARE_DIR:/usr/share/nginx/html:ro -d nginx
  elif [ "$STATUS" = "exited" ]; then
    echo "Starting existing Docker container: $SOFTWARE_CONTAINER"
    $DOCKER_CMD start $SOFTWARE_CONTAINER
  fi

  echo "Starting Docker container: $SOFTWARE_CONTAINER"
  # Start local nginx container to host SW Repository
  SOFTWARE_REPO_IP="$($DOCKER_CMD inspect --format '{{ .NetworkSettings.IPAddress }}' $SOFTWARE_CONTAINER 2>/dev/null)"
  if [ -z "$SOFTWARE_REPO_IP" ]; then
    echo "Unable to locate software repository."
  else
    DOWNLOAD_FROM=http://$SOFTWARE_REPO_IP
    echo "Hosting IBM Software repository on $DOWNLOAD_FROM"
  fi
  echo
}

nginx_stop ()
{
  # Stop and remove SW repository
  $DOCKER_CMD stop $SOFTWARE_CONTAINER
  $DOCKER_CMD container rm $SOFTWARE_CONTAINER
  echo "Stopped & Removed Software Repository Container"
  echo
}

print_runtime()
{
  hours=$((SECONDS / 3600))
  seconds=$((SECONDS % 3600))
  minutes=$((seconds / 60))
  seconds=$((seconds % 60))
  h=""; m=""; s=""
  if [ ! $hours = "1" ] ; then h="s"; fi
  if [ ! $minutes = "1" ] ; then m="s"; fi
  if [ ! $seconds = "1" ] ; then s="s"; fi
  if [ ! $hours = 0 ] ; then echo "Completed in $hours hour$h, $minutes minute$m and $seconds second$s"
  elif [ ! $minutes = 0 ] ; then echo "Completed in $minutes minute$m and $seconds second$s"
  else echo "Completed in $seconds second$s"; fi
}

get_current_version ()
{
  if [ ! -z "$DOWNLOAD_FROM" ]; then

    DOWNLOAD_FILE=$DOWNLOAD_FROM/$VERSION_FILE_NAME

    WGET_RET_OK=`$WGET_COMMAND -S --spider "$DOWNLOAD_FILE" 2>&1 | grep 'HTTP/1.1 200 OK'`
    if [ ! -z "$WGET_RET_OK" ]; then
      DOWNLOAD_VERSION_FILE=$DOWNLOAD_FILE
    fi
  fi

  if [ ! -z "$DOWNLOAD_VERSION_FILE" ]; then
    echo "Getting current software version from [$DOWNLOAD_VERSION_FILE]"
    LINE=`$WGET_COMMAND -qO- $DOWNLOAD_VERSION_FILE | grep "^$1|"`
  else
    if [ ! -r $VERSION_FILE ]; then
      echo "No current version file found! [$VERSION_FILE]"
    else
      echo "Getting current software version from [$VERSION_FILE]"
      LINE=`grep "^$1|" $VERSION_FILE`
    fi
  fi

  PROD_VER=`echo $LINE|cut -d'|' -f2`
  PROD_FP=`echo $LINE|cut -d'|' -f3`
  PROD_HF=`echo $LINE|cut -d'|' -f4`

  return 0
}

copy_config_file()
{
  if [ -e "$CONFIG_FILE" ]; then
    echo "Config File [$CONFIG_FILE] already exists!"
    return 0
  fi

  mkdir -p $DOMINO_DOCKER_CFG_DIR 
  cp sample_build_config $CONFIG_FILE
}

WGET_COMMAND="wget --connect-timeout=20"

SCRIPT_DIR=`dirname $SCRIPT_NAME`
SOFTWARE_PORT=7777
SOFTWARE_CONTAINER=ibmsoftware

if [ -z "$1" ]; then
  usage
  exit 0
fi

for a in $@; do

  p=`echo "$a" | awk '{print tolower($0)}'`
  case "$p" in
    domino|domino-ce|traveler|proton|iam)
      PROD_NAME=$p
      ;;

    latest)
      PROD_VER=$p
      ;;

    9*|10*|11*)
      PROD_VER=$p
      ;;

    fp*)
      PROD_FP=$p
      ;;

    hf*|if*)
      PROD_HF=$p
      ;;

    _*)
      PROD_EXT=$a
      ;;

    # special for other latest tags
    latest*)
      TAG_LATEST=$a
      ;;

    dockerfile*)
      DOCKER_FILE=$a
      ;;

    cfg|config)
      $EDIT_COMMAND $CONFIG_FILE
      exit 0
      ;;

    cpcfg)
      copy_config_file
      exit 0
      ;;

    -checkonly)
      BUILD_IMAGE=no
      CHECK_SOFTWARE=yes
      ;;

    -check)
      CHECK_SOFTWARE=yes
      ;;

    -nocheck)
      CHECK_SOFTWARE=no
      ;;

    -verifyonly)
      BUILD_IMAGE=no
      CHECK_SOFTWARE=yes
      CHECK_HASH=yes
      ;;

    -verify)
      CHECK_SOFTWARE=yes
      CHECK_HASH=yes
      ;;

    -noverify)
      CHECK_HASH=no
      ;;

    -url)
      DOWNLOAD_URLS_SHOW=yes
      ;;

    -nourl)
      DOWNLOAD_URLS_SHOW=no
      ;;

    -linuxupd)
      LinuxYumUpdate=yes
      ;;

    -nolinuxupd)
      LinuxYumUpdate=no
      ;;

    *)
      echo "Invalid parameter [$a]"
      echo
      exit 1
      ;;
  esac
done

TARGET_IMAGE=$PROD_NAME
TARGET_DIR=`echo $TARGET_IMAGE | cut -f 1 -d"-"`

# In case software directory is not set and the well know location is filled with software
if [ -z "$SOFTWARE_DIR" ]; then
  SOFTWARE_DIR=$PWD/software
fi

if [ -z "$DOWNLOAD_FROM" ]; then
  SOFTWARE_USE_NGINX=1
fi

VERSION_FILE_NAME=current_version.txt
VERSION_FILE=$SOFTWARE_DIR/$VERSION_FILE_NAME

# if version file isn't found check standard location (check might lead to the same directory if standard location already)
if [ ! -e "$VERSION_FILE" ]; then
  VERSION_FILE=$PWD/software/$VERSION_FILE_NAME  
fi

if [ -z "$DOWNLOAD_FROM" ]; then

  echo "Getting software from [$SOFTWARE_DIR]"
else
  echo "Getting software from [$DOWNLOAD_FROM]"
fi

if [ -z "$PROD_VER" ]; then
  PROD_VER="latest"
fi

dump_config

if [ "$PROD_VER" = "latest" ]; then
  get_current_version "$PROD_NAME"
  echo
  echo "Product to install: $PROD_NAME $PROD_VER $PROD_FP $PROD_HF"
  echo
  
  if [ -z "$TAG_LATEST" ]; then
    TAG_LATEST="latest"
  fi
fi

if [ "$CHECK_SOFTWARE" = "yes" ]; then
  . ./check_software.sh "$PROD_NAME" "$PROD_VER" "$PROD_FP" "$PROD_HF"

  if [ ! "$CHECK_SOFTWARE_STATUS" = "0" ]; then
    #terminate if status is not OK. Errors are already logged
    exit 0
  fi
fi

if [ "$BUILD_IMAGE" = "no" ]; then
  # no build requested
  exit 0
fi

if [ -z "$DOWNLOAD_FROM" ]; then
  SOFTWARE_USE_NGINX=1

  if [ -z "$SOFTWARE_DIR" ]; then
    SOFTWARE_DIR=$PWD/software
  fi
fi

echo

if [ -z "$TARGET_IMAGE" ]; then
  echo "No Taget Image specified! - Terminating"
  echo
  exit 1
fi

if [ -z "$PROD_VER" ]; then
  echo "No Taget version specified! - Terminating"
  echo
  exit 1
fi

BUILD_SCRIPT=dockerfiles/$TARGET_DIR/build_$TARGET_IMAGE.sh

if [ ! -e "$BUILD_SCRIPT" ]; then
  echo "Cannot execute build script for [$TARGET_IMAGE] -- Terminating [$BUILD_SCRIPT]"
  echo
  exit 1
fi

if [ "$SOFTWARE_USE_NGINX" = "1" ]; then
  nginx_start
fi

export DOWNLOAD_FROM
export SOFTWARE_DIR
export PROD_NAME
export PROD_VER
export PROD_FP
export PROD_HF
export PROD_EXT
export CHECK_SOFTWARE
export CHECK_HASH
export DOWNLOAD_URLS_SHOW
export LinuxYumUpdate
export DominoMoveInstallData
export TAG_LATEST
export DOCKER_FILE

$BUILD_SCRIPT "$DOWNLOAD_FROM" "$PROD_VER" "$PROD_FP" "$PROD_HF"

if [ "$SOFTWARE_USE_NGINX" = "1" ]; then
  nginx_stop
fi

print_runtime

exit 0

