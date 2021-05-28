#!/bin/bash

############################################################################
# Copyright Nash!Com, Daniel Nashed 2019, 2020 - APACHE 2.0 see LICENSE
# Copyright IBM Corporation 2015, 2019 - APACHE 2.0 see LICENSE
############################################################################

# Main Script to build images 
# Run without parameters for detailed syntax
# The script checks if software is avialable at configured location (download location or local directory).
# In case of a local software directory it hosts the software on a local NGINX container


SCRIPT_NAME=$0
TARGET_IMAGE=$1

TARGET_DIR=`echo $1 | cut -f 1 -d"-"`

# Standard configuration overwritten by build.cfg
# (Default) NIGX is used hosting software from the local "software" directory.

DominoMoveInstallData=yes

# Default: Update CentOS while building the image
LinuxYumUpdate=yes

# Default: Check if software exits
CHECK_SOFTWARE=yes

# use vi if no other editor specified in config
if [ -z "$EDIT_COMMAND" ]; then
  EDIT_COMMAND="vi"
fi

# Default config directory. Can be overwritten by environment

if [ -z "$BUILD_CFG_FILE"]; then
  BUILD_CFG_FILE=build.cfg
fi

if [ -z "$DOMINO_DOCKER_CFG_DIR" ]; then

  # Check for legacy config else use new location in user home 
  if [ -r /local/cfg/build_config ]; then
    DOMINO_DOCKER_CFG_DIR=/local/cfg
    CONFIG_FILE=$DOMINO_DOCKER_CFG_DIR/build_config
  else
    DOMINO_DOCKER_CFG_DIR=~/DominoDocker
    CONFIG_FILE=$DOMINO_DOCKER_CFG_DIR/$BUILD_CFG_FILE
  fi
fi

# use a config file if present
if [ -r "$CONFIG_FILE" ]; then
  echo "(Using config file $CONFIG_FILE)"
  . $CONFIG_FILE
else
  if [ -r "$BUILD_CFG_FILE" ]; then
    . build.cfg
  fi
fi

check_version ()
{
  count=1

  while true
  do
    VER=`echo $1|cut -d"." -f $count`
    CHECK=`echo $2|cut -d"." -f $count`

    if [ -z "$VER" ]; then return 0; fi
    if [ -z "$CHECK" ]; then return 0; fi

    if [ $VER -gt $CHECK ]; then return 0; fi
    if [ $VER -lt $CHECK ]; then
      echo "Warning: Unsupported $3 version $1 - Must be at least $2 !"
      sleep 1
      return 1
    fi

    count=`expr $count + 1`
  done

  return 0
}


check_docker_environment()
{
  DOCKER_MINIMUM_VERSION="18.09.0"
  PODMAN_MINIMUM_VERSION="1.5.0"

  if [ -x /usr/bin/podman ]; then
    if [ -z "$USE_DOCKER" ]; then
      # podman environment detected
      DOCKER_CMD=podman
      DOCKER_ENV_NAME=Podman
      DOCKER_VERSION_STR=`podman version | head -1`
      DOCKER_VERSION=`echo $DOCKER_VERSION_STR | cut -d" " -f3`
      check_version "$DOCKER_VERSION" "$PODMAN_MINIMUM_VERSION" "$DOCKER_CMD"
      return 0
    fi
  fi

  if [ -z "$DOCKERD_NAME" ]; then
    DOCKERD_NAME=dockerd
  fi

  DOCKER_ENV_NAME=Docker

  # check docker environment
  DOCKER_VERSION_STR=`docker -v`
  DOCKER_VERSION=`echo $DOCKER_VERSION_STR | cut -d" " -f3|cut -d"," -f1`

  check_version "$DOCKER_VERSION" "$DOCKER_MINIMUM_VERSION" "$DOCKER_CMD"

  if [ -z "$DOCKER_CMD" ]; then

    DOCKER_CMD=docker

    # Use sudo for docker command if not root on Linux

    if [ `uname` = "Linux" ]; then
      if [ ! "$EUID" = "0" ]; then
        if [ "$DOCKER_USE_SUDO" = "no" ]; then
          echo "Docker needs root permissions on Linux!"
          exit 1
        fi
        DOCKER_CMD="sudo $DOCKER_CMD"
      fi
    fi
  fi

  return 0
}


usage ()
{
  echo
  echo "Usage: `basename $SCRIPT_NAME` { domino | traveler | volt } version fp hf"
  echo
  echo "-checkonly      checks without build"
  echo "-verifyonly     checks download file checksum without build"
  echo "-(no)check      checks if files exist (default: yes)"
  echo "-(no)verify     checks downloaded file checksum (default: no)"
  echo "-(no)url        shows all download URLs, even if file is downloaded (default: no)"
  echo "-(no)linuxupd   updates container Linux  while building image (default: yes)"
  echo "cfg|config      edits config file (either in current directory or if created in home dir)"
  echo "cpcfg           copies standard config file to config directory (default: $CONFIG_FILE)"
  echo
  echo Add-On options
  echo
  echo "-git            adds Git client to Domino image"
  echo "-openssl        adds OpenSSL to Domino image"
  echo "-borg           adds borg client and Domino Borg Backup integration to image"
  echo "-verse          adds the latest verse version to a Domino image"
  echo
  echo
  echo "Examples:"
  echo
  echo "  `basename $SCRIPT_NAME` domino 11.0.1 fp3"
  echo "  `basename $SCRIPT_NAME` traveler 11.0.1.1"
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
  echo "Build Environment  : [$DOCKER_CMD]"
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
  echo "VERSE_VERSION      : [$VERSE_VERSION]"
  echo "LinuxYumUpdate     : [$LinuxYumUpdate]"
  echo "DOMINO_LANG        : [$DOMINO_LANG]"
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
    echo "No specific IP address using host address"
    SOFTWARE_REPO_IP=$(hostname --all-ip-addresses | cut -f1 -d" "):$SOFTWARE_PORT
  fi
    
  DOWNLOAD_FROM=http://$SOFTWARE_REPO_IP
  echo "Hosting HCL Software repository on $DOWNLOAD_FROM"
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

    CURL_RET=$($CURL_CMD "$DOWNLOAD_FILE" --silent --head 2>&1)
    STATUS_RET=$(echo $CURL_RET | grep 'HTTP/1.1 200 OK')
    if [ -n "$STATUS_RET" ]; then
      DOWNLOAD_VERSION_FILE=$DOWNLOAD_FILE
    fi
  fi

  if [ ! -z "$DOWNLOAD_VERSION_FILE" ]; then
    echo "Getting current software version from [$DOWNLOAD_VERSION_FILE]"
    LINE=`$CURL_CMD --silent $DOWNLOAD_VERSION_FILE | grep "^$1|"`
  else
    if [ ! -r "$VERSION_FILE" ]; then
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

get_current_addon_version ()
{
  local S1=$2
  local S2=${!2}

  if [ -n "$DOWNLOAD_FROM" ]; then

    DOWNLOAD_FILE=$DOWNLOAD_FROM/$VERSION_FILE_NAME
    echo "getting current add-on version from: [$DOWNLOAD_FILE]"

    CURL_RET=$($CURL_CMD "$DOWNLOAD_FILE" --silent --head 2>&1)
    STATUS_RET=$(echo $CURL_RET | grep 'HTTP/1.1 200 OK')
    if [ -n "$STATUS_RET" ]; then
      DOWNLOAD_VERSION_FILE=$DOWNLOAD_FILE
    fi
  fi

  if [ -n "$DOWNLOAD_VERSION_FILE" ]; then
    echo "Getting current add-on version from [$DOWNLOAD_VERSION_FILE]"
    LINE=`$CURL_CMD --silent $DOWNLOAD_VERSION_FILE | grep "^$1|"`
  else
    if [ ! -r "$VERSION_FILE" ]; then
      echo "No current version file found! [$VERSION_FILE]"
    else
      echo "Getting current software version from [$VERSION_FILE]"
      LINE=`grep "^$1|" $VERSION_FILE`
    fi
  fi

  export $2=`echo $LINE|cut -d'|' -f2 -s`

  return 0
}

copy_config_file()
{
  if [ -e "$CONFIG_FILE" ]; then
    echo "Config File [$CONFIG_FILE] already exists!"
    return 0
  fi

  mkdir -p $DOMINO_DOCKER_CFG_DIR 
  if [ -e "$BUILD_CFG_FILE" ]; then
    cp "$BUILD_CFG_FILE" "$CONFIG_FILE"
  else
    echo "Cannot copy config file"
  fi
}

SCRIPT_DIR=`dirname $SCRIPT_NAME`
SOFTWARE_PORT=7777
SOFTWARE_CONTAINER=hclsoftware
CURL_CMD="curl --fail --connect-timeout 15 --max-time 300 $SPECIAL_CURL_ARGS"

VERSION_FILE_NAME=current_version.txt
VERSION_FILE=$SOFTWARE_DIR/$VERSION_FILE_NAME

# if version file isn't found check standard location (check might lead to the same directory if standard location already)
if [ ! -e "$VERSION_FILE" ]; then
  VERSION_FILE=$PWD/software/$VERSION_FILE_NAME
fi


if [ -z "$1" ]; then
  usage
  exit 0
fi

for a in $@; do

  p=`echo "$a" | awk '{print tolower($0)}'`
  case "$p" in
    domino|traveler|volt)
      PROD_NAME=$p
      ;;

    -verse*|verse*)
      VERSE_VERSION=`echo "$a" | cut -f2 -d= -s`

      if [ -z "$VERSE_VERSION" ]; then
        get_current_addon_version verse VERSE_VERSION
      fi
      ;;

    9*|10*|11*|12*)
      PROD_VER=$p
      ;;

    fp*)
      PROD_FP=$p
      ;;

   beta*)
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

    domino-docker:*)
      BASE_IMAGE=$a
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

    -borg)
      BORG_INSTALL=yes
      ;;

    -openssl)
      OPENSSL_INSTALL=yes
      ;;

    -git)
      GIT_INSTALL=YES
      ;;

    *)
      echo "Invalid parameter [$a]"
      echo
      exit 1
      ;;
  esac
done

check_docker_environment

echo "[Running in $DOCKER_CMD configuration]"

# in case we are starting with a specific HCL Domino image, set the DOCKER_FILE accordingly if not explicitly specified
# also bypass software download check
# but check if the image is available

echo "BASE_IMAGE: [$BASE_IMAGE]"
if [ -n "$BASE_IMAGE" ]; then

  if [ -z "$DOCKER_FILE" ]; then
    DOCKER_FILE=dockerfile_hcl
  fi

  IMAGE_ID=`$DOCKER_CMD images $BASE_IMAGE -q`
  if [ -z "$IMAGE_ID" ]; then
    echo "Base image [$BASE_IMAGE] does not exist"
    exit 1
  fi

  # Derive version from Docker image name
  PROD_NAME=domino
  PROD_VER=`echo $BASE_IMAGE | cut -d":" -f 2`
    
  # don't check software
  CHECK_SOFTWARE=no
  CHECK_HASH=no
fi

TARGET_IMAGE=$PROD_NAME
TARGET_DIR=`echo $TARGET_IMAGE | cut -f 1 -d"-"`

# In case software directory is not set and the well know location is filled with software
if [ -z "$SOFTWARE_DIR" ]; then
  SOFTWARE_DIR=$PWD/software
fi

if [ -z "$DOWNLOAD_FROM" ]; then
  SOFTWARE_USE_NGINX=1
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
  echo "No Target Image specified! - Terminating"
  echo
  exit 1
fi

if [ -z "$PROD_VER" ]; then
  echo "No Target version specified! - Terminating"
  echo
  exit 1
fi

# Podman started to use OCI images by default. We still want Docker image format
if [ -z "$BUILDAH_FORMAT" ]; then
  BUILDAH_FORMAT=docker
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
export VERSE_VERSION
export CHECK_SOFTWARE
export CHECK_HASH
export DOWNLOAD_URLS_SHOW
export LinuxYumUpdate
export DominoMoveInstallData
export TAG_LATEST
export DOCKER_FILE
export BASE_IMAGE 
export SPECIAL_CURL_ARGS
export USE_DOCKER
export DOCKER_NETWORK_NAME
export GIT_INSTALL
export OPENSSL_INSTALL
export BORG_INSTALL
export BUILDAH_FORMAT
export DOMINO_LANG

$BUILD_SCRIPT "$DOWNLOAD_FROM" "$PROD_VER" "$PROD_FP" "$PROD_HF"

if [ "$SOFTWARE_USE_NGINX" = "1" ]; then
  nginx_stop
fi

print_runtime

exit 0

