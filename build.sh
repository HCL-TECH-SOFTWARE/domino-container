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

# Configure your own software share instead of launching a local repository via NGINX.
# By default NGINX is used
#DOWNLOAD_FROM=http://192.168.1.1

# With NGINX container you could chose your own local directory or use the default "software" directory
SOFTWARE_DIR=/local/software

usage ()
{
  echo
  echo "Usage: `basename $SCRIPT_NAME` { domino }"
  echo

  return 0
}

# (Default) NIGX is used hosting software from the local "software" directory.
# (Optional) Configure software download location.

# You can either use your own software repository remotely.
#DOWNLOAD_FROM=http://192.168.1.1

# Or use a local software image hosted via NGINX temporary image.
#SOFTWARE_DIR=/local/software

SCRIPT_DIR=`dirname $SCRIPT_NAME`
SOFTWARE_PORT=7777
SOFTWARE_CONTAINER=ibmsoftware

if [ -z "$DOWNLOAD_FROM" ]; then
  SOFTWARE_USE_NGINX=1
  
  if [ -z "$SOFTWARE_DIR" ]; then
    SOFTWARE_DIR=$SCRIPT_DIR/software
  fi
fi
  
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

echo

if [ "$TARGET_IMAGE" = "" ]; then
	echo "No Taget Image specified! - Terminating"
	usage
  exit 1
fi

BUILD_SCRIPT=dockerfiles/$TARGET_IMAGE/build_$TARGET_IMAGE.sh

if [ ! -e "$BUILD_SCRIPT" ]; then
	echo "Cannot execute build script for [$TARGET_IMAGE] -- Terminating [$BUILD_SCRIPT]"
  exit 1
fi

if [ "$SOFTWARE_USE_NGINX" = "1" ]; then
  nginx_start
fi

$BUILD_SCRIPT $DOWNLOAD_FROM

if [ "$SOFTWARE_USE_NGINX" = "1" ]; then
  nginx_stop
fi

echo
echo "Total elapsed time: " `date -d@$SECONDS -u +%T`
echo

exit 0



