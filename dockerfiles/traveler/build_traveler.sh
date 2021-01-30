#!/bin/bash

############################################################################
# Copyright Nash!Com, Daniel Nashed 2019, 2020 - APACHE 2.0 see LICENSE
# Copyright IBM Corporation 2015, 2019 - APACHE 2.0 see LICENSE
############################################################################

# Traveler Docker Build Script
# Usage  : ./build.sh <URL for download repository> [ Traveler Version ]
# Example: ./build-image.sh http://192.168.1.1

SCRIPT_NAME=$0
DOWNLOAD_FROM=$1

# Select product to install
PROD_NAME=traveler

# Get product name from file name
if [ -z $PROD_NAME ]; then
  PROD_NAME=`basename $0 | cut -f 2 -d"_" | cut -f 1 -d"."`
fi

# Specify Version to install
# Can be overwritten on command-line
PROD_VER=10.0.1.1

CUSTOM_VER=`echo "$2" | awk '{print toupper($0)}'`

if [ ! -z "$CUSTOM_VER" ]; then
  PROD_VER=$CUSTOM_VER
fi

case "$PROD_VER" in
  9*|10*)
    DOCKER_IMAGE_NAME="ibmcom/$PROD_NAME"
    COMPANY=IBM
    ;;
  *)
    DOCKER_IMAGE_NAME="hclcom/$PROD_NAME"
    COMPANY=HCL
    ;;
esac

DOCKER_IMAGE_VERSION=$PROD_VER$PROD_EXT

if [ -z "$DOCKER_FILE" ]; then
  DOCKER_FILE=dockerfile
fi

# Set default or custom LATEST tag

if [ ! -z "$TAG_LATEST" ]; then
  DOCKER_TAG_LATEST="$DOCKER_IMAGE_NAME:$TAG_LATEST"
fi

usage ()
{
  echo
  echo "Usage: `basename $SCRIPT_NAME` <URL for download repository> [TRAVELER-VERSION] "
  echo
  return 0
}

print_runtime()
{
  echo
  
  # the following line does not work on OSX 
  # echo "Completed in" `date -d@$SECONDS -u +%T`
 
  hours=$((SECONDS / 3600))
  seconds=$((SECONDS % 3600))
  minutes=$((seconds / 60))
  seconds=$((seconds % 60))
  h=""; m=""; s=""
  if [ ! $hours =  "1" ] ; then h="s"; fi
  if [ ! $minutes =  "1" ] ; then m="s"; fi
  if [ ! $seconds =  "1" ] ; then s="s"; fi

  if [ ! $hours =  0 ] ; then echo "Completed in $hours hour$h, $minutes minute$m and $seconds second$s"
  elif [ ! $minutes = 0 ] ; then echo "Completed in $minutes minute$m and $seconds second$s"
  else echo "Completed in $seconds second$s"; fi
}

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

docker_build ()
{
  echo "Building Image : " $IMAGENAME
  
  if [ -z "$DOCKER_TAG_LATEST" ]; then
    DOCKER_IMAGE=$DOCKER_IMAGE_NAMEVERSION
    DOCKER_TAG_LATEST_CMD=""
  else
    DOCKER_IMAGE=$DOCKER_TAG_LATEST
    DOCKER_TAG_LATEST_CMD="-t $DOCKER_TAG_LATEST"
  fi

  # Get Build Time  
  BUILDTIME=`date +"%d.%m.%Y %H:%M:%S"`

  case "$PROD_NAME" in
    traveler)
      DOCKER_DESCRIPTION="$COMPANY Traveler"
      ;;

    *)
      echo "Unknown product [$PROD_NAME] - Terminating installation"
      exit 1
      ;;
  esac
  
  # Get build arguments
  DOCKER_IMAGE=$DOCKER_IMAGE_NAME:$DOCKER_IMAGE_VERSION
  
  # Switch to current directory and remember current directory
  pushd .
  CURRENT_DIR=`dirname $SCRIPT_NAME`
  cd $CURRENT_DIR

  DOCKER_IMAGE_BUILD_VERSION=$DOCKER_IMAGE_VERSION

  if [ -z "$DOCKER_NETWORK" ]; then

    if [ ! -z "$DOCKER_NETWORK_NAME" ]; then
      DOCKER_NETWORK="--network=$DOCKER_NETWORK_NAME"
    fi
  fi

  # Finally build the image
  $DOCKER_CMD build --no-cache $DOCKER_NETWORK \
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
    --label TravelerDocker.description="$DOCKER_DESCRIPTION" \
    --label TravelerDocker.version="$DOCKER_IMAGE_VERSION" \
    --label TravelerDocker.buildtime="$BUILDTIME" \
    --build-arg PROD_NAME="$PROD_NAME" \
    --build-arg PROD_VER="$PROD_VER" \
    --build-arg DownloadFrom="$DOWNLOAD_FROM" \
    --build-arg LinuxYumUpdate="$LinuxYumUpdate" \
    --build-arg SPECIAL_WGET_ARGUMENTS="$SPECIAL_WGET_ARGUMENTS" \
    --build-arg SPECIAL_CURL_ARGUMENTS="$SPECIAL_CURL_ARGUMENTS" .

  popd
  echo
  # echo "Completed in" `date -d@$SECONDS -u +%T`
  # echo
  return 0
}

if [ -z "$DOWNLOAD_FROM" ]; then
  echo
  echo "No download location specified!"
  echo

  usage
  exit 0
fi

check_docker_environment
docker_build

echo
print_runtime
echo

exit 0

