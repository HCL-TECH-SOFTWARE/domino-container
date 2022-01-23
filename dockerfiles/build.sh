#!/bin/bash

############################################################################
# Copyright Nash!Com, Daniel Nashed 2019, 2022 - APACHE 2.0 see LICENSE
# Copyright IBM Corporation 2015, 2019 - APACHE 2.0 see LICENSE
############################################################################

# Domino Container Build Script
# Called by main build.sh script

# ---------------------------------------------------
# Optional Parameters in the following order
# ---------------------------------------------------
# Product Version
# Product Fixpack
# Product InterimsFix
# (use "" for no Fixpack)
# ---------------------------------------------------

SCRIPT_NAME=$0
DOWNLOAD_FROM=$1


log_error_exit()
{
  echo
  echo $@
  echo

  exit 1
}

# Get product name from file name
if [ -z $PROD_NAME ]; then
  log_error_exit "No product specified"
fi

if [ -z "$DOWNLOAD_FROM" ]; then
  log_error_exit "No download location specified!"
fi

CUSTOM_VER=`echo "$2" | awk '{print toupper($0)}'`
CUSTOM_FP=`echo "$3" | awk '{print toupper($0)}'`
CUSTOM_HF=`echo "$4" | awk '{print toupper($0)}'`

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
    --build-arg DominoMoveInstallData=$DominoMoveInstallData \
    --build-arg GIT_INSTALL="$GIT_INSTALL" \
    --build-arg OPENSSL_INSTALL="$OPENSSL_INSTALL" \
    --build-arg BORG_INSTALL="$BORG_INSTALL" \
    --build-arg VERSE_VERSION="$VERSE_VERSION" \
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

  # Get build arguments
  DOCKER_IMAGE=$DOCKER_IMAGE_NAME:$DOCKER_IMAGE_VERSION
  
  CURRENT_DIR=$(dirname $SCRIPT_NAME)
  cd $CURRENT_DIR

  DOCKER_IMAGE_BUILD_VERSION=$DOCKER_IMAGE_VERSION

  case "$PROD_NAME" in

    domino)

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

docker_build

exit 0
