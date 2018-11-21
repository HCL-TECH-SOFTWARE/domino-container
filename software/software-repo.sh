#/bin/bash
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

SCRIPT_NAME=$0
PARAM=$1

usage ()
{
  echo
  echo "Usage: `basename $SCRIPT_NAME` { start | stop | ip | remove | stopremove }"

  return 0
}

repo_start ()
{
    # Check if we already have this container in status exited
    STATUS="$(docker inspect --format '{{ .State.Status }}' ibmsoftware)"
    if [[ -z "$STATUS" ]] ; then
        echo "Creating Docker container: ibmsoftware"
        docker run --name ibmsoftware -p 7777:80 -v $PWD/software:/usr/share/nginx/html:ro -d nginx
    elif [ "$STATUS" = "exited" ] ; then 
        echo "Starting existing Docker container: ibmsoftware"
        docker start ibmsoftware
    fi
    return 0
}

repo_stopremove ()
{
    # Stop and remove SW repository
    docker stop ibmsoftware
    docker container rm ibmsoftware
    return 0
}

repo_stop ()
{
    # Stop SW repository
    docker stop ibmsoftware
    return 0
}

repo_getIP ()
{
    # get IP address of repository
    IP="$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ibmsoftware 2>/dev/null)"
    if [ -z "$IP" ] ; then
        echo "Unable to locate software repository."
        echo "Build process stopped."
    else
        echo "Hosting IBM Software repository on" HTTP://$IP
    fi

    return 0
}

echo

case "$PARAM1" in
	
  start)
    repo_start 
    ;;

  stop)
    repo_stopremove 
    ;;

  ip)
    repo_stopremove 
    ;;

  *)

    if [ -z "$PARAM1" ]; then
      usage 
    else
      echo "Invalid command:" [$PARAM1]
      usage 
    fi
    ;;

esac

echo 
exit 0