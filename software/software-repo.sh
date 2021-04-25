#/bin/bash

############################################################################
# Copyright Nash!Com, Daniel Nashed 2019, 2021 - APACHE 2.0 see LICENSE
# Copyright IBM Corporation 2015, 2019 - APACHE 2.0 see LICENSE
############################################################################

SCRIPT_NAME=$0
PARAM1=$1
SOFTWARE_CONTAINER=hclsoftware

usage ()
{
  echo
  echo "Usage: `basename $SCRIPT_NAME` { start | stop | ip | stopremove }"

  return 0
}

repo_start ()
{
  # Check if we already have this container in status exited
  STATUS="$(docker inspect --format '{{ .State.Status }}' $SOFTWARE_CONTAINER)"
  if [[ -z "$STATUS" ]] ; then
    echo "Creating Docker container: $SOFTWARE_CONTAINER"
    docker run --name $SOFTWARE_CONTAINER -p 7777:80 -v $PWD:/usr/share/nginx/html:ro -d nginx
  elif [ "$STATUS" = "exited" ] ; then 
    echo "Starting existing Docker container: $SOFTWARE_CONTAINER"
    docker start $SOFTWARE_CONTAINER
  fi
  return 0
}

repo_stopremove ()
{
  # Stop and remove SW repository
  docker stop $SOFTWARE_CONTAINER
  docker container rm $SOFTWARE_CONTAINER
  return 0
}

repo_bash ()
{
  # Stop and remove SW repository
  docker exec -it $SOFTWARE_CONTAINER /bin/bash
  return 0
}

repo_stop ()
{
  # Stop SW repository
  docker stop $SOFTWARE_CONTAINER
  return 0
}

repo_getIP ()
{
  # get IP address of repository
  IP="$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' $SOFTWARE_CONTAINER 2>/dev/null)"
  if [ -z "$IP" ] ; then
    echo "Unable to locate software repository."
  else
    echo "Hosting Software repository on" HTTP://$IP
  fi

  return 0
}

echo

case "$PARAM1" in
	
  start)
    repo_start 
    ;;

  stop)
    repo_stop
    ;;

 bash)
    repo_bash
    ;;

  stopremove)
    repo_stopremove 
    ;;

  ip)
    repo_getIP
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
