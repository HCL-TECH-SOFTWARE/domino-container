#!/bin/bash

log ()
{
  return 0
  echo "$1" "$2" "$3" "$4"
}

nginx_transfer_stop ()
{
  docker stop "$TRANSFER_CONTAINER"
  docker container rm "$TRANSFER_CONTAINER"
  echo "Stopped & Removed Transfer Container"
  echo
}

nginx_transfer_start ()
{
  # Create a nginx container hosting transfer directory download locally

  # Stop and Remove existing container if needed
  STATUS="$(docker inspect --format "{{ .State.Status }}" $TRANSFER_CONTAINER 2>/dev/null)"

  if [ ! -z "$STATUS" ]; then
    nginx_transfer_stop
  fi

  echo "Starting Docker container [$TRANSFER_CONTAINER]"
  docker run --name $TRANSFER_CONTAINER --network="bridge" -v $TRANSFER_DIR:/usr/share/nginx/html:ro -d nginx 2>/dev/null

  TRANSFER_CONTAINER_IP="$(docker inspect --format "{{ .NetworkSettings.IPAddress }}" $TRANSFER_CONTAINER 2>/dev/null)"
  if [ -z "$TRANSFER_CONTAINER_IP" ]; then
    echo "Unable to locate transfer container IP"
    return 1
  fi

  echo
  echo "Hosting Transfer Container on [$TRANSFER_CONTAINER_IP]"
  echo
}

TransferToContainer ()
{
  TRANSFER_FILE="$1"
  TRANSFER_RECEIVE_COMMAND="$2"

  TRANSFER_PORT=7777
  TRANSFER_CONTAINER=DockerDominoTransfer
  TRANSFER_RAND=`openssl rand -hex 32`
  TRANSFER_DIR="$PWD/transfer"
  TRANSFER_OUTFILE="$TRANSFER_RAND/container.bin"

  TRANSFER_PW=`openssl rand -base64 32`
  CONTAINER_ID="$(docker inspect --format "{{ .Id }}" $DOCKER_CONTAINER 2>/dev/null)"

  if [ -z "$CONTAINER_ID" ]; then
    log "Container [$DOCKER_CONTAINER] not found"
    return 1
  fi

  # Create transfer dir including random sub dir
  mkdir -p "$TRANSFER_DIR/$TRANSFER_RAND"  
  openssl aes-256-cbc -e -k $TRANSFER_PW$CONTAINER_ID -salt -in "$TRANSFER_FILE" -out $TRANSFER_DIR/$TRANSFER_OUTFILE -md sha256

  nginx_transfer_start

  TRANSFER_DOWNLOAD_URL="http://$TRANSFER_CONTAINER_IP/$TRANSFER_OUTFILE"

  log
  log "Container-ID : [$CONTAINER_ID]"
  log "Transfer-Dir : [$TRANSFER_DIR]"
  log "Transfer-File: [$TRANSFER_OUTFILE]"
  log
  log "Download-URL : [$TRANSFER_DOWNLOAD_URL]"
  # log "PWD          : [$TRANSFER_PW]"
  log

  docker exec -it $CONTAINER_ID $TRANSFER_RECEIVE_COMMAND $TRANSFER_DOWNLOAD_URL $TRANSFER_PW > "$TRANSFER_LOG"

  nginx_transfer_stop
  rm -rf "$TRANSFER_DIR"

  return 0
}

ReceiveFromDockerHost()
{
  TRANSFER_DOWNLOAD_URL=$1
  TRANSFER_PW=$2

  CONTAINER_ID=`grep "memory:/" < /proc/self/cgroup | sed 's|.*/||'`
  wget $TRANSFER_DOWNLOAD_URL 
  openssl aes-256-cbc -d -k $TRANSFER_PW$CONTAINER_ID -salt -in container.bin -out container.tar -md sha256
}

TransferCertsToContainer()
{
  DOCKER_CONTAINER=acme-domino-ce
  CERT_FILE=container.tar

  tar -cf "$CERT_FILE" *.txt
  TransferToContainer $CERT_FILE /receive_from_docker_host.sh
  rm -r $CERT_FILE

  echo "------------------------------"
  cat transfer.log
  echo "------------------------------"
  echo
}

TransferCertsToContainer

exit 0
