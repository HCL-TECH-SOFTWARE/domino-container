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

# Main Script to build images. This is script also hosts the software repository locally by default
# Usage  : ./build.sh <parameter>
# Example: ./build.sh domino

SCRIPT_NAME=$0
TARGET_IMAGE=$1
PROD_VER=$2
PROD_FP=$3
PROD_HF=$4

TARGET_DIR=`echo $1 | cut -f 1 -d"-"`

# (Default) NIGX is used hosting software from the local "software" directory.
# (Optional) Configure software download location.
# DOWNLOAD_FROM=http://192.168.1.1

# With NGINX container you could chose your own local directory or if variable is empty use the default "software" subdirectory 
#SOFTWARE_DIR=/local/software

usage ()
{
  echo
  echo "Usage: `basename $SCRIPT_NAME` { domino | domino-ce | traveler }"
  echo

  return 0
}

nginx_start ()
{
  # Create a nginx container hosting software download locally

  # Check if we already have this container in status exited
  STATUS="$(docker inspect --format '{{ .State.Status }}' $SOFTWARE_CONTAINER 2>/dev/null)"

  if [ -z "$STATUS" ]; then
    echo "Creating Docker container: $SOFTWARE_CONTAINER hosting [$SOFTWARE_DIR]"
    docker run --name $SOFTWARE_CONTAINER -p $SOFTWARE_PORT:80 -v $SOFTWARE_DIR:/usr/share/nginx/html:ro -d nginx
  elif [ "$STATUS" = "exited" ]; then
    echo "Starting existing Docker container: $SOFTWARE_CONTAINER"
    docker start $SOFTWARE_CONTAINER
  fi

  echo "Starting Docker container: $SOFTWARE_CONTAINER"
  # Start local nginx container to host SW Repository
  SOFTWARE_REPO_IP="$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' $SOFTWARE_CONTAINER 2>/dev/null)"
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
  docker stop $SOFTWARE_CONTAINER
  docker container rm $SOFTWARE_CONTAINER
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

SCRIPT_DIR=`dirname $SCRIPT_NAME`
SOFTWARE_PORT=7777
SOFTWARE_CONTAINER=ibmsoftware

# In case software directory is not set and the well know location is filled with software
if [ -z "$SOFTWARE_DIR" ]; then
  if [ -e /local/software/software.txt ]; then
    SOFTWARE_DIR=/local/software
  fi
fi

if [ -z "$DOWNLOAD_FROM" ]; then
  SOFTWARE_USE_NGINX=1

  if [ -z "$SOFTWARE_DIR" ]; then
    SOFTWARE_DIR=$PWD/software
  fi
fi

echo

if [ "$TARGET_IMAGE" = "" ]; then
  echo "No Taget Image specified! - Terminating"
  usage
  exit 1
fi

BUILD_SCRIPT=dockerfiles/$TARGET_DIR/build_$TARGET_IMAGE.sh

if [ ! -e "$BUILD_SCRIPT" ]; then
  echo "Cannot execute build script for [$TARGET_IMAGE] -- Terminating [$BUILD_SCRIPT]"
  exit 1
fi

if [ "$SOFTWARE_USE_NGINX" = "1" ]; then
  nginx_start
fi

$BUILD_SCRIPT "$DOWNLOAD_FROM" "$PROD_VER" "$PROD_FP" "$PROD_HF"

if [ "$SOFTWARE_USE_NGINX" = "1" ]; then
  nginx_stop
fi

print_runtime

exit 0



