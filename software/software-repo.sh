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


repo_start ()
{
  # Check if we already have this container in status exited
  STATUS="$($DOCKER_CMD inspect --format '{{ .State.Status }}' $SOFTWARE_CONTAINER)"
  if [[ -z "$STATUS" ]] ; then
    echo "Creating Docker container: $SOFTWARE_CONTAINER"
    $DOCKER_CMD run --name $SOFTWARE_CONTAINER -p 7777:80 -v $PWD:/usr/share/nginx/html:ro -d nginx
  elif [ "$STATUS" = "exited" ] ; then 
    echo "Starting existing Docker container: $SOFTWARE_CONTAINER"
    $DOCKER_CMD start $SOFTWARE_CONTAINER
  fi
  return 0
}

repo_stopremove ()
{
  # Stop and remove SW repository
  $DOCKER_CMD stop $SOFTWARE_CONTAINER
  $DOCKER_CMD container rm $SOFTWARE_CONTAINER
  return 0
}

repo_bash ()
{
  # Stop and remove SW repository
  $DOCKER_CMD exec -it $SOFTWARE_CONTAINER /bin/bash
  return 0
}

repo_stop ()
{
  # Stop SW repository
  $DOCKER_CMD stop $SOFTWARE_CONTAINER
  return 0
}

repo_getIP ()
{
  # get IP address of repository
  IP="$($DOCKER_CMD inspect --format '{{ .NetworkSettings.IPAddress }}' $SOFTWARE_CONTAINER 2>/dev/null)"
  if [ -z "$IP" ] ; then
    echo "Unable to locate software repository."
  else
    echo "Hosting Software repository on" HTTP://$IP
  fi

  return 0
}


check_docker_environment

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
