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

# Domino Docker Build Script
# Usage  : ./build.sh <URL for download repository>
# Example: ./build-image.sh http://192.168.1.1

SCRIPT_NAME=$0
DOWNLOAD_FROM=$1

DOCKER_IMAGE_NAME=ibmcom/domino
DOCKER_IMAGE_VERSION=10.0.0
DOCKER_FILE=dockerfile_domino.txt
DominoBasePackage=DOMINO_SERVER_V10.0_64_BIT_LINUX_.tar

usage ()
{
  echo
  echo "Usage: `basename $SCRIPT_NAME` { domino }"
  echo
  return 0
}

docker_build ()
{
  echo "Building Image : " $IMAGENAME
  
  # Get build arguments
  DOCKER_IMAGE=$DOCKER_IMAGE_NAME:$DOCKER_IMAGE_VERSION
  BUILD_ARG_DOMINO_BASE_PACKAGE="--build-arg DominoBasePackage=$DominoBasePackage"
  BUILD_ARG_DOWNLOAD_FROM="--build-arg DownloadFrom=$DOWNLOAD_FROM $BUILD_ARG"

  # Switch to current directory and remember current directory
  pushd .
  CURRENT_DIR=`dirname $SCRIPT_NAME`
  cd $CURRENT_DIR

  # Finally build the image
  docker build -t $DOCKER_IMAGE_NAME:$DOCKER_IMAGE_VERSION $DOCKER_TAG_LATEST_CMD -f $DOCKER_FILE $BUILD_ARG_DOWNLOAD_FROM $BUILD_ARG_DOMINO_BASE_PACKAGE .

  popd
  echo

  echo "Completed in" `date -d@$SECONDS -u +%T`
  echo
  return 0
}

if [ "$DOWNLOAD_FROM" = "" ]; then
	echo
	echo "No download location specified!"
	echo
	usage
  exit 0
fi

docker_build
exit 0

