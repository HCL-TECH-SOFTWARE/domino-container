#!/bin/bash
#
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
#
# usage:
# 	./build.sh <parameter>
#
# example:
#	./build.sh domino
SECONDS=0
if [ "$1" = "" ] ; then
    echo "Usage:" 
    echo "  ./docker-build-image.sh domino"
else
    echo "Building IBM Domino Image : " $1

    # Check if we already have this container in status exited
    STATUS="$(docker inspect --format '{{ .State.Status }}' ibmsoftware)"
    if [[ -z "$STATUS" ]] ; then
        echo "Creating Docker container: ibmsoftware"
        docker run --name ibmsoftware -p 7777:80 -v $PWD/software:/usr/share/nginx/html:ro -d nginx
    elif [ "$STATUS" = "exited" ] ; then 
        echo "Starting existing Docker container: ibmsoftware"
        docker start ibmsoftware
    fi

    # Start local nginx container to host SW Repository 
    IP="$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ibmsoftware)"
    if [[ -z "$IP" ]] ; then
        echo "Unable to locate software repository."
        echo "Built stopped."
    else
        echo "Hosting IBM Software repository on" HTTP://$IP
        # build 
        cd dockerfile/domino
        docker build -t ibmcom/domino:10.0.0 -f Dockerfile-domino-centos.txt . --build-arg downloadfrom=HTTP://$IP/domino10
        cd ..
    fi
fi
docker stop ibmsoftware

if (( $SECONDS > 3600 )) ; then
    let "hours=SECONDS/3600"
    let "minutes=(SECONDS%3600)/60"
    let "seconds=(SECONDS%3600)%60"
    echo "Completed in $hours hour(s), $minutes minute(s) and $seconds second(s)" 
elif (( $SECONDS > 60 )) ; then
    let "minutes=(SECONDS%3600)/60"
    let "seconds=(SECONDS%3600)%60"
    echo "Completed in $minutes minute(s) and $seconds second(s)"
else
    echo "Completed in $SECONDS seconds"
fi