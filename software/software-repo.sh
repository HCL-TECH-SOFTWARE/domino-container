#/bin/bash

############################################################################
# Copyright Nash!Com, Daniel Nashed 2019, 2022 - APACHE 2.0 see LICENSE
# Copyright IBM Corporation 2015, 2019 - APACHE 2.0 see LICENSE
############################################################################

SCRIPT_NAME=$0
PARAM1=$1
SOFTWARE_CONTAINER=hclsoftware

usage ()
{
  echo
  echo "Usage: $(basename $SCRIPT_NAME) { start | stop | ip | stopremove }"

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

repo_start ()
{
  # Check if we already have this container in status exited
  STATUS="$($CONTAINER_CMD inspect --format '{{ .State.Status }}' $SOFTWARE_CONTAINER 2>/dev/null)"
  if [[ -z "$STATUS" ]] ; then
    echo "Creating Docker container: $SOFTWARE_CONTAINER"
    $CONTAINER_CMD run --name $SOFTWARE_CONTAINER -p 7777:80 -v $PWD:/usr/share/nginx/html:Z -d nginx
  elif [ "$STATUS" = "exited" ] ; then 
    echo "Starting existing Docker container: $SOFTWARE_CONTAINER"
    $CONTAINER_CMD start $SOFTWARE_CONTAINER
  fi
  return 0
}

repo_stopremove ()
{
  # Stop and remove SW repository
  $CONTAINER_CMD stop $SOFTWARE_CONTAINER
  $CONTAINER_CMD container rm $SOFTWARE_CONTAINER
  return 0
}

repo_bash ()
{
  # Stop and remove SW repository
  $CONTAINER_CMD exec -it $SOFTWARE_CONTAINER /bin/bash
  return 0
}

repo_stop ()
{
  # Stop SW repository
  $CONTAINER_CMD stop $SOFTWARE_CONTAINER
  return 0
}

repo_getIP ()
{
  # get IP address of repository
  IP="$($CONTAINER_CMD inspect --format '{{ .NetworkSettings.IPAddress }}' $SOFTWARE_CONTAINER 2>/dev/null)"
  if [ -z "$IP" ] ; then
    echo "Unable to locate software repository."
  else
    echo "Hosting Software repository on" HTTP://$IP
  fi

  return 0
}

get_container_environment

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
