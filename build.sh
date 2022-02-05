#!/bin/bash

############################################################################
# Copyright Nash!Com, Daniel Nashed 2019, 2020 - APACHE 2.0 see LICENSE
# Copyright IBM Corporation 2015, 2022 - APACHE 2.0 see LICENSE
############################################################################

# Version 2.0

# Main Script to build images.
# Run without parameters for detailed syntax.
# The script checks if software is available at configured location (download location or local directory).
# In case of a local software directory it hosts the software on a local NGINX container.

SCRIPT_NAME=$0

# Standard configuration overwritten by build.cfg
# (Default) NIGX is used hosting software from the local "software" directory.

# Default: Update CentOS while building the image
LinuxYumUpdate=yes

# Default: Check if software exits
CHECK_SOFTWARE=yes

# ----------------------------------------

log_error_exit()
{
  echo
  echo $@
  echo

  exit 1
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

check_timezone()
{
  LARCH=$(uname)

  echo

  # If Timezone is not set use host's timezone
  if [ -z $DOCKER_TZ ]; then

    if [ $LARCH = "Linux" ]; then
      DOCKER_TZ=$(readlink /etc/localtime | awk -F'/usr/share/zoneinfo/' '{print $2}')
    elif [ $LARCH = "Darwin" ]; then
      DOCKER_TZ=$(readlink /etc/localtime | awk -F'/usr/share/zoneinfo/' '{print $2}')
    else
      DOCKER_TZ=""
    fi

    echo "Using OS Timezone : [$DOCKER_TZ]"

  else
    echo "Timezone configured: [$DOCKER_TZ]"
  fi

  echo
  return 0
}

get_container_environment()
{
  # If specified use specified command. Else find out the platform.

  if [ -n "$CONTAINER_CMD" ]; then
    return 0
  fi

  if [ -n "$USE_DOCKER" ]; then
    CONTAINER_CMD=docker
    return 0
  fi

  if [ -x /usr/bin/podman ]; then
    CONTAINER_CMD=podman
    return 0
  fi

  if [ -n "$(which nerdctl 2> /dev/null)" ]; then
    CONTAINER_CMD=nerdctl
    return 0
  fi

  CONTAINER_CMD=docker

  return 0
}

check_container_environment()
{
  DOCKER_MINIMUM_VERSION="18.09.0"
  PODMAN_MINIMUM_VERSION="1.5.0"

  if [ "$CONTAINER_CMD" = "podman" ]; then
    DOCKER_ENV_NAME=Podman
    DOCKER_VERSION_STR=$(podman version | head -1)
    DOCKER_VERSION=$(echo $DOCKER_VERSION_STR | cut -d" " -f3)
    check_version "$DOCKER_VERSION" "$PODMAN_MINIMUM_VERSION" "$CONTAINER_CMD"

    if [ -z "$DOCKER_NETWORK" ]; then
      if [ -n "$DOCKER_NETWORK_NAME" ]; then
        CONTAINER_NETWORK_CMD="--network=$CONTAINER_NETWORK_NAME"
      fi
    fi

    return 0
  fi

  if [ "$CONTAINER_CMD" = "docker" ]; then

    DOCKER_ENV_NAME=Docker

    if [ -z "$DOCKERD_NAME" ]; then
      DOCKERD_NAME=dockerd
    fi

    # check docker environment
    DOCKER_VERSION_STR=$(docker -v)
    DOCKER_VERSION=$(echo $DOCKER_VERSION_STR | cut -d" " -f3|cut -d"," -f1)

    check_version "$DOCKER_VERSION" "$DOCKER_MINIMUM_VERSION" "$CONTAINER_CMD"

    # Use sudo for docker command if not root on Linux

    if [ $(uname) = "Linux" ]; then
      if [ ! "$EUID" = "0" ]; then
        if [ "$DOCKER_USE_SUDO" = "no" ]; then
          log_error_exit "Docker needs root permissions on Linux!"
        fi
        CONTAINER_CMD="sudo $CONTAINER_CMD"
      fi
    fi

    if [ -z "$DOCKER_NETWORK" ]; then
      if [ -n "$DOCKER_NETWORK_NAME" ]; then
        CONTAINER_NETWORK_CMD="--network=$CONTAINER_NETWORK_NAME"
      fi
    fi

    return 0
  fi

  if [ "$CONTAINER_CMD" = "nerdctl" ]; then
    DOCKER_ENV_NAME=nerdctl

    if [ -z "$CONTAINER_NAMESPACE" ]; then
      CONTAINER_NAMESPACE=k8s.io
    fi

    CONTAINER_NAMESPACE_CMD="--namespace=$CONTAINER_NAMESPACE"
  fi

  return 0
}


usage()
{
  echo
  echo "Usage: $(basename $SCRIPT_NAME) { domino | traveler | volt } version fp hf"
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
  echo "  $(basename $SCRIPT_NAME) domino 12.0.1 if1"
  echo "  $(basename $SCRIPT_NAME) traveler 12.0.1"
  echo

  return 0
}


print_delim()
{
  echo "--------------------------------------------------------------------------------"
}

header()
{
  echo
  print_delim
  echo "$1"
  print_delim
  echo
}

dump_config()
{
  header "Build Configuration"
  echo "Build Environment  : [$CONTAINER_CMD]"
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

nginx_start()
{
  # Create a nginx container hosting software download locally

  # Check if we already have this container in status exited
  STATUS="$($CONTAINER_CMD inspect --format '{{ .State.Status }}' $SOFTWARE_CONTAINER 2>/dev/null)"

  if [ -z "$STATUS" ]; then
    echo "Creating Docker container: $SOFTWARE_CONTAINER hosting [$SOFTWARE_DIR]"
    $CONTAINER_CMD run --name $SOFTWARE_CONTAINER -p $SOFTWARE_PORT:80 -v $SOFTWARE_DIR:/usr/share/nginx/html:Z -d nginx
  elif [ "$STATUS" = "exited" ]; then
    echo "Starting existing Docker container: $SOFTWARE_CONTAINER"
    $CONTAINER_CMD start $SOFTWARE_CONTAINER
  fi

  echo "Starting Docker container: $SOFTWARE_CONTAINER"

  # Start local nginx container to host SW Repository

  SOFTWARE_REPO_IP="$($CONTAINER_CMD inspect --format '{{ .NetworkSettings.IPAddress }}' $SOFTWARE_CONTAINER 2>/dev/null)"
  if [ -z "$SOFTWARE_REPO_IP" ]; then
    echo "No specific IP address using host address"
    SOFTWARE_REPO_IP=$(hostname --all-ip-addresses | cut -f1 -d" "):$SOFTWARE_PORT
  fi

  DOWNLOAD_FROM=http://$SOFTWARE_REPO_IP
  echo "Hosting HCL Software repository on $DOWNLOAD_FROM"
  echo
}

nginx_stop()
{
  # Stop and remove SW repository

  $CONTAINER_CMD stop $SOFTWARE_CONTAINER
  $CONTAINER_CMD container rm $SOFTWARE_CONTAINER
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

get_current_version()
{
  if [ -n "$DOWNLOAD_FROM" ]; then

    DOWNLOAD_FILE=$DOWNLOAD_FROM/$VERSION_FILE_NAME

    CURL_RET=$($CURL_CMD "$DOWNLOAD_FILE" --silent --head 2>&1)
    STATUS_RET=$(echo $CURL_RET | grep 'HTTP/1.1 200 OK')
    if [ -n "$STATUS_RET" ]; then
      DOWNLOAD_VERSION_FILE=$DOWNLOAD_FILE
    fi
  fi

  if [ -n "$DOWNLOAD_VERSION_FILE" ]; then
    echo "Getting current software version from [$DOWNLOAD_VERSION_FILE]"
    LINE=$($CURL_CMD --silent $DOWNLOAD_VERSION_FILE | grep "^$1|")
  else
    if [ ! -r "$VERSION_FILE" ]; then
      echo "No current version file found! [$VERSION_FILE]"
    else
      echo "Getting current software version from [$VERSION_FILE]"
      LINE=$(grep "^$1|" $VERSION_FILE)
    fi
  fi

  PROD_VER=$(echo $LINE|cut -d'|' -f2)
  PROD_FP=$(echo $LINE|cut -d'|' -f3)
  PROD_HF=$(echo $LINE|cut -d'|' -f4)

  return 0
}

get_current_addon_version()
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
    LINE=$($CURL_CMD --silent $DOWNLOAD_VERSION_FILE | grep "^$1|")
  else
    if [ ! -r "$VERSION_FILE" ]; then
      echo "No current version file found! [$VERSION_FILE]"
    else
      echo "Getting current software version from [$VERSION_FILE]"
      LINE=$(grep "^$1|" $VERSION_FILE)
    fi
  fi

  export $2=$(echo $LINE|cut -d'|' -f2 -s)

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

edit_config_file()
{
  if [ ! -e "$CONFIG_FILE" ]; then
    echo "Creating new config file [$CONFIG_FILE]"
    copy_config_file
  fi

  $EDIT_COMMAND $CONFIG_FILE
}

check_for_hcl_image()
{
  # If the base is the HCL Domino image,
  # Also bypass software download check.
  # But check if the image is available.

  case "$FROM_IMAGE" in

    domino-docker*)
      LINUX_NAME="HCL Base Image"
      BASE_IMAGE=$FROM_IMAGE
      ;;

    *)
      return 0
      ;;
  esac

  IMAGE_ID=$($CONTAINER_CMD images $BASE_IMAGE -q)
  if [ -z "$IMAGE_ID" ]; then
    log_error_exit "Base image [$FROM_IMAGE] does not exist"
  fi

  # Derive version from Docker image name
  PROD_NAME=domino
  PROD_VER=$(echo $FROM_IMAGE | cut -d":" -f 2 -s)

  # don't check software
  CHECK_SOFTWARE=no
  CHECK_HASH=no
}

check_from_image()
{
  if [ -z "$FROM_IMAGE" ]; then
    LINUX_NAME="CentOS Stream"
    BASE_IMAGE=quay.io/centos/centos:stream8
    return 0
  fi

  case "$FROM_IMAGE" in

    centos8)
      LINUX_NAME="CentOS Stream"
      BASE_IMAGE=quay.io/centos/centos:stream8
      ;;

    centos9)
      LINUX_NAME="CentOS Stream 9"
      BASE_IMAGE=quay.io/centos/centos:stream9
      ;;

    rocky)
      LINUX_NAME="Rocky Linux"
      BASE_IMAGE=rockylinux/rockylinux
      ;;

    alma)
      LINUX_NAME="Alma Linux"
      BASE_IMAGE=almalinux/almalinux:8
      ;;

    amazon)
      LINUX_NAME="Amazon Linux"
      BASE_IMAGE=amazonlinux
      ;;

    oracle)
      LINUX_NAME="Oracle Linux"
      BASE_IMAGE=oraclelinux:8
      ;;

    photon)
      LINUX_NAME="Photon OS"
      BASE_IMAGE=photon
      ;;

    ubi)
      LINUX_NAME="RedHat UBI"
      BASE_IMAGE=redhat/ubi8
      ;;

    leap)
      LINUX_NAME="SUSE Leap"
      BASE_IMAGE=opensuse/leap
      ;;

    astra)
      LINUX_NAME="Astra Linux"
      BASE_IMAGE=orel:latest
      ;;

    *)
      LINUX_NAME="Manual specified base image"
      BASE_IMAGE=$FROM_IMAGE
      echo "Info: Manual specified base image used! [$FROM_IMAGE]"
      ;;

  esac

  header "Base Image - $LINUX_NAME"
}


build_domino()
{
  CONTAINER_DESCRIPTION="HCL Domino Enterprise Server"

  $CONTAINER_CMD build --no-cache \
    $CONTAINER_NETWORK_CMD $CONTAINER_NAMESPACE_CMD \
    -t $DOCKER_IMAGE $DOCKER_TAG_LATEST_CMD \
    -f $DOCKER_FILE \
    --label maintainer="thomas.hampel, daniel.nashed@nashcom.de" \
    --label name="HCL Domino Community Image" \
    --label vendor="Domino Docker Community Project" \
    --label description="$CONTAINER_DESCRIPTION" \
    --label summary="$CONTAINER_DESCRIPTION" \
    --label version="$DOCKER_IMAGE_VERSION" \
    --label "buildtime"="$BUILDTIME" \
    --label release="$BUILDTIME" \
    --label architecture="x86_64" \
    --label "io.k8s.description"="HCL Domino Community Image" \
    --label "io.k8s.display-name"="HCL Domino Community Image" \
    --label io.openshift.expose-services="1352:nrpc 80:http 110:pop3 143:imap 389:ldap 443:https 636:ldaps 993:imaps 995:pop3s" \
    --label io.openshift.tags="domino" \
    --label io.openshift.non-scalable=true \
    --label io.openshift.min-memory=2Gi \
    --label io.openshift.min-cpu=2 \
    --label DominoDocker.maintainer="thomas.hampel, daniel.nashed@nashcom.de" \
    --label DominoDocker.description="$DOCKER_DESCRIPTION" \
    --label DominoDocker.version="$DOCKER_IMAGE_VERSION" \
    --label DominoDocker.buildtime="$BUILDTIME" \
    --build-arg PROD_NAME=$PROD_NAME \
    --build-arg PROD_VER=$PROD_VER \
    --build-arg PROD_FP=$PROD_FP \
    --build-arg PROD_HF=$PROD_HF \
    --build-arg DOCKER_TZ=$DOCKER_TZ \
    --build-arg BASE_IMAGE=$BASE_IMAGE \
    --build-arg DownloadFrom=$DOWNLOAD_FROM \
    --build-arg LinuxYumUpdate=$LinuxYumUpdate \
    --build-arg OPENSSL_INSTALL="$OPENSSL_INSTALL" \
    --build-arg BORG_INSTALL="$BORG_INSTALL" \
    --build-arg VERSE_VERSION="$VERSE_VERSION" \
    --build-arg START_SCRIPT_VER="$START_SCRIPT_VER" \
    --build-arg DOMINO_LANG="$DOMINO_LANG" \
    --build-arg SPECIAL_CURL_ARGS="$SPECIAL_CURL_ARGS" .
}

build_traveler()
{
  CONTAINER_DESCRIPTION="HCL Traveler"

  $CONTAINER_CMD build --no-cache \
    $CONTAINER_NETWORK_CMD $CONTAINER_NAMESPACE_CMD \
    -t $DOCKER_IMAGE $DOCKER_TAG_LATEST_CMD \
    -f $DOCKER_FILE \
    --label maintainer="thomas.hampel, daniel.nashed@nashcom.de" \
    --label name="HCL Traveler Community Image" \
    --label vendor="Domino Docker Community Project" \
    --label description="HCL Traveler Mobile Sync Server" \
    --label summary="HCL Traveler Mobile Sync Server" \
    --label version="$DOCKER_IMAGE_VERSION" \
    --label "buildtime"="$BUILDTIME" \
    --label release="$BUILDTIME" \
    --label architecture="x86_64" \
    --label "io.k8s.description"="HCL Traveler Community Image" \
    --label "io.k8s.display-name"="HCL Traveler Community Image" \
    --label io.openshift.expose-services="1352:nrpc 25:smtp 80:http 389:ldap 443:https 636:ldaps" \
    --label TravelerDocker.description="$CONTAINER_DESCRIPTION" \
    --label TravelerDocker.version="$DOCKER_IMAGE_VERSION" \
    --label TravelerDocker.buildtime="$BUILDTIME" \
    --build-arg PROD_NAME="$PROD_NAME" \
    --build-arg PROD_VER="$PROD_VER" \
    --build-arg DownloadFrom="$DOWNLOAD_FROM" \
    --build-arg LinuxYumUpdate="$LinuxYumUpdate" \
    --build-arg BASE_IMAGE=$BASE_IMAGE \
    --build-arg SPECIAL_CURL_ARGS="$SPECIAL_CURL_ARGS" .
}

build_volt()
{
  CONTAINER_DESCRIPTION="HCL Volt"

  $CONTAINER_CMD build --no-cache \
    $CONTAINER_NETWORK_CMD $CONTAINER_NAMESPACE_CMD \
    -t $DOCKER_IMAGE $DOCKER_TAG_LATEST_CMD \
    -f $DOCKER_FILE \
    --label maintainer="thomas.hampel, daniel.nashed@nashcom.de" \
    --label name="HCL Volt Community Image" \
    --label vendor="Domino Docker Community Project" \
    --label description="HCL Volt - Low Code platform" \
    --label summary="HCL Volt - Low Code platform" \
    --label version="$DOCKER_IMAGE_VERSION" \
    --label "buildtime"="$BUILDTIME" \
    --label release="$BUILDTIME" \
    --label architecture="x86_64" \
    --label "io.k8s.description"="HCL Volt Community Image" \
    --label "io.k8s.display-name"="HCL Volt Community Image" \
    --label io.openshift.expose-services="1352:nrpc 25:smtp 80:http 389:ldap 443:https 636:ldaps" \
    --label VoltDocker.description="$CONTAINER_DESCRIPTION" \
    --label VoltDocker.version="$DOCKER_IMAGE_VERSION" \
    --label VoltDocker.buildtime="$BUILDTIME" \
    --build-arg PROD_NAME="$PROD_NAME" \
    --build-arg PROD_VER="$PROD_VER" \
    --build-arg DownloadFrom="$DOWNLOAD_FROM" \
    --build-arg LinuxYumUpdate="$LinuxYumUpdate" \
    --build-arg BASE_IMAGE=$BASE_IMAGE \
    --build-arg SPECIAL_CURL_ARGS="$SPECIAL_CURL_ARGS" .
}

docker_build()
{
  # Get product name from file name
  if [ -z $PROD_NAME ]; then
    log_error_exit "No product specified"
  fi

  if [ -z "$DOWNLOAD_FROM" ]; then
    log_error_exit "No download location specified!"
  fi

  CUSTOM_VER=$(echo "$CUSTOM_VER" | awk '{print toupper($0)}')
  CUSTOM_FP=$(echo "$CUSTOM_FP" | awk '{print toupper($0)}')
  CUSTOM_HF=$(echo "$CUSTOM_HF" | awk '{print toupper($0)}')

  if [ -n "$CUSTOM_VER" ]; then
    PROD_VER=$CUSTOM_VER
    PROD_FP=$CUSTOM_FP
    PROD_HF=$CUSTOM_HF
  fi

  DOCKER_IMAGE_NAME="hclcom/$PROD_NAME"
  DOCKER_IMAGE_VERSION=$PROD_VER$PROD_FP$PROD_HF$PROD_EXT

  # Set default or custom LATEST tag
  if [ -n "$TAG_LATEST" ]; then
    DOCKER_TAG_LATEST="$DOCKER_IMAGE_NAME:$TAG_LATEST"
  fi

  if [ "$CONTAINER_CMD" = "nerdctl" ]; then
    # Currently nerdctl cannot handle a second tag
    DOCKER_TAG_LATEST=
  fi

  echo "Building Image : " $IMAGENAME

  if [ -z "$DOCKER_TAG_LATEST" ]; then
    DOCKER_IMAGE=$DOCKER_IMAGE_NAMEVERSION
    DOCKER_TAG_LATEST_CMD=""
  else
    DOCKER_IMAGE=$DOCKER_TAG_LATEST
    DOCKER_TAG_LATEST_CMD="-t $DOCKER_TAG_LATEST"
  fi

  # Get Build Time
  BUILDTIME=$(date +"%d.%m.%Y %H:%M:%S")

  # Get build arguments
  DOCKER_IMAGE=$DOCKER_IMAGE_NAME:$DOCKER_IMAGE_VERSION

  # Switch to directory containing the dockerfiles
  cd dockerfiles

  DOCKER_IMAGE_BUILD_VERSION=$DOCKER_IMAGE_VERSION

  case "$PROD_NAME" in

    domino)

      # Find the right base image to build with
      check_from_image

      if [ -z "$DOCKER_FILE" ]; then
        DOCKER_FILE=dockerfile
      fi

      build_domino
      ;;

    traveler)
      DOCKER_FILE=dockerfile_traveler

      if [ -z "$BASE_IMAGE" ]; then
        BASE_IMAGE=hclcom/domino:latest
      fi

      build_traveler
      ;;

    volt)
      DOCKER_FILE=dockerfile_volt

      if [ -z "$BASE_IMAGE" ]; then
        BASE_IMAGE=hclcom/domino:latest
      fi

      build_volt
      ;;

    *)
      log_error_exit "Unknown product [$PROD_NAME] - Terminating installation"
      ;;
  esac

  echo
  return 0
}


# --- Main script logic ---

SCRIPT_DIR=$(dirname $SCRIPT_NAME)
SOFTWARE_PORT=7777
SOFTWARE_CONTAINER=hclsoftware
CURL_CMD="curl --fail --connect-timeout 15 --max-time 300 $SPECIAL_CURL_ARGS"

VERSION_FILE_NAME=current_version.txt
VERSION_FILE=$SOFTWARE_DIR/$VERSION_FILE_NAME

# Use vi if no other editor specified in config

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

  elif [ -r ~/DominoDocker/build.cfg ]; then
    DOMINO_DOCKER_CFG_DIR=~/DominoDocker
    CONFIG_FILE=$DOMINO_DOCKER_CFG_DIR/build.cfg

  else
    DOMINO_DOCKER_CFG_DIR=~/.DominoDocker
    CONFIG_FILE=$DOMINO_DOCKER_CFG_DIR/$BUILD_CFG_FILE
  fi
fi

# Use a config file if present

if [ -r "$CONFIG_FILE" ]; then
  echo "(Using config file $CONFIG_FILE)"
  . $CONFIG_FILE
else
  if [ -r "$BUILD_CFG_FILE" ]; then
    . build.cfg
  fi
fi

# If version file isn't found check standard location (check might lead to the same directory if standard location already)

if [ ! -e "$VERSION_FILE" ]; then
  VERSION_FILE=$PWD/software/$VERSION_FILE_NAME
fi

if [ -z "$1" ]; then
  usage
  exit 0
fi

for a in $@; do

  p=$(echo "$a" | awk '{print tolower($0)}')
  case "$p" in
    domino|traveler|volt)
      PROD_NAME=$p
      ;;

    -verse*|verse*)
      VERSE_VERSION=$(echo "$a" | cut -f2 -d= -s)

      if [ -z "$VERSE_VERSION" ]; then
        get_current_addon_version verse VERSE_VERSION
      fi
      ;;

    -startscript=*)
      START_SCRIPT_VER=$(echo "$a" | cut -f2 -d= -s)
      ;;

    -from=*)
      FROM_IMAGE=$(echo "$a" | cut -f2 -d= -s)
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

    # Special for other latest tags
    latest*)
      TAG_LATEST=$a
      ;;

    dockerfile*)
      DOCKER_FILE=$a
      ;;

    domino-docker:*)
      # To build on top of HCL image
      FROM_IMAGE=$a
      DOCKER_FILE=dockerfile_hcl
      ;;

    cfg|config)
      edit_config_file
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

    *)
      log_error_exit "Invalid parameter [$a]"
      ;;
  esac
done

check_timezone
get_container_environment
check_container_environment

echo "[Running in $CONTAINER_CMD configuration]"

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

check_for_hcl_image
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
    #Terminate if status is not OK. Errors are already logged
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

if [ -z "$PROD_NAME" ]; then
  log_error_exit "No product specified! - Terminating"
fi

if [ -z "$PROD_VER" ]; then
  log_error_exit "No Target version specified! - Terminating"
fi

# Podman started to use OCI images by default. We still want Docker image format

if [ -z "$BUILDAH_FORMAT" ]; then
  BUILDAH_FORMAT=docker
fi

if [ "$SOFTWARE_USE_NGINX" = "1" ]; then
  nginx_start
fi

CURRENT_DIR=$(pwd)

docker_build

cd "$CURRENT_DIR"

if [ "$SOFTWARE_USE_NGINX" = "1" ]; then
  nginx_stop
fi

print_runtime

exit 0
