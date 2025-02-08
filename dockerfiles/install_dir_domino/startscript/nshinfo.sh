#!/bin/bash

print_delim ()
{
  echo "------------------------------------------------------------------------------------------"
}

get_entry()
{
  if [ -z "$4" ]; then
    DELIM=":"
  else
    DELIM="$4"
  fi
  
  if [ "$5" = "mem" ]; then
    export $1="$(sed -n "/^$3/ {p;q}" $2| cut -d $DELIM -f2 | xargs | cut -d " " -f1)"
  else
    export $1="$(sed -n "/^$3/ {p;q}" $2| cut -d $DELIM -f2 | xargs)"
  fi
}

format_mem()
{
  if [ -z "$3" ]; then
    export $1="$(echo "$2" | awk '{printf "%4.1f GB", $1/1024/1024}' )"
  else
    export $1="$(echo "$2" "$3" | awk '{printf "%4.1f GB  (%4.1f)", $1/1024/1024, $1*100/$2}' )"
  fi
}

domino_uptime()
{
  local LOTUS_BIN_DIR
  local DOMINO_SERVER_PID
  local PARTITION_USER
  local DOMINO_UID

  if [ -z "$DOMINO_USER" ]; then
    PARTITION_USER=notes
  else
    PARTITION_USER=$DOMINO_USER
  fi

  DOMINO_UID=$(id -u notesx 2>/dev/null)

  if [ -z "$DOMINO_UID" ]; then
    return 0
  fi

  if [ -z "$Notes_ExecDirectory" ]; then
    LOTUS_BIN_DIR=/opt/hcl/domino/notes/latest/linux
  else
    LOTUS_BIN_DIR=$Notes_ExecDirectory
  fi

  if [ ! -e "$LOTUS_BIN_DIR" ]; then
    return 0
  fi

  DOMINO_SERVER_PID=$(ps -ef -fu $PARTITION_USER | grep "$LOTUS_BIN_DIR" | grep "server" | grep -v " -jc" | xargs | cut -d " " -f2)
  if [ -n "$DOMINO_SERVER_PID" ]; then
    DOMINO_UPTIME=$(ps -o etimes= -p "$DOMINO_SERVER_PID" | awk '{x=$1/86400;y=($1%86400)/3600;z=($1%3600)/60} {printf("%d day, %d hour %d min\n",x,y,z)}' )
  fi
}

print_infos()
{

  if [ "$(uname)" = "Darwin" ]; then
    echo "No OS infos for MacOS"
  fi

  if [ -r  /etc/os-release ]; then
    get_entry LINUX_VERSION /etc/os-release "VERSION_ID=" "="
    get_entry LINUX_PRETTY_NAME /etc/os-release "PRETTY_NAME=" "="
    get_entry LINUX_ID /etc/os-release "ID=" "="
  fi

  LINUX_KERNEL=$(uname -r)
  LINUX_GLIBC_VERSION=$(ldd --version| head -1 | rev | cut -f1 -d' ' | rev 2> /dev/null)
  LINUX_ARCH==$(uname -m)
  LINUX_UPTIME=$( awk '{x=$1/86400;y=($1%86400)/3600;z=($1%3600)/60} {printf("%d day, %d hour %d min\n",x,y,z)}' /proc/uptime )
  LINUX_LOAD_AVG=$(awk -F " " '{printf $1 "  " $2 "  " $3}' /proc/loadavg)

  LINUX_HOSTNAME=$(cat /proc/sys/kernel/hostname)

  if [ -x /usr/bin/systemd-detect-virt ]; then
    LINUX_VIRT=$(/usr/bin/systemd-detect-virt -v)
    CONTAINER_VIRT=$(/usr/bin/systemd-detect-virt -c)

    if [ "$CONTAINER_VIRT" = "none" ]; then
      CONTAINER_VIRT=
    else
      CONTAINER_UPTIME=$(ps -o etimes= -p 1 | awk '{x=$1/86400;y=($1%86400)/3600;z=($1%3600)/60} {printf("%d day, %d hour %d min\n",x,y,z)}' )
    fi
  fi

  domino_uptime

  get_entry CPU_MODEL /proc/cpuinfo "model name"
  get_entry CPU_MHZ /proc/cpuinfo "cpu MHz"
  get_entry CPU_CACHE_SIZE /proc/cpuinfo "cache size"

  CPU_COUNT=$(grep "^model name" /proc/cpuinfo | wc -l)
  CPU_INFO=$(grep "^model name"  /proc/cpuinfo | cut -f2 -d":" | sort | uniq -c | xargs)

  get_entry MEM_TOTAL  /proc/meminfo "MemTotal"     ":" mem
  get_entry MEM_AVAIL  /proc/meminfo "MemAvailable" ":" mem
  get_entry MEM_CACHED /proc/meminfo "Cached"       ":" mem
  get_entry MEM_FREE   /proc/meminfo "MemFree"      ":" mem

  format_mem MEM_TOTAL_INFO   $MEM_TOTAL
  format_mem MEM_AVAIL_INFO   $MEM_AVAIL  $MEM_TOTAL
  format_mem MEM_CACHED_INFO  $MEM_CACHED $MEM_TOTAL
  format_mem MEM_FREE_INFO    $MEM_FREE   $MEM_TOTAL

  printf "\n"
  print_delim

  printf "Hostname      :      $LINUX_HOSTNAME\n"
  printf "Linux OS      :      $LINUX_PRETTY_NAME\n"
  printf "Linux Version :      $LINUX_VERSION\n"
  printf "Kernel        :      $LINUX_KERNEL\n"
  printf "GNU libc      :      $LINUX_GLIBC_VERSION\n"
  printf "Timezone      :      $(date +"%Z %z")\n"


  if [ -n "$LINUX_VIRT" ]; then
    printf "Virt          :      $LINUX_VIRT\n"
  fi

  if [ -n "$CONTAINER_VIRT" ]; then
    printf "Container     :      $CONTAINER_VIRT\n"
  fi

  local CONTAINER_STR=

  CONTAINER_STR=$(podman -v 2> /dev/null | head -1)

  if [ -n "$CONTAINER_STR" ]; then
    CONTAINER_STR=$(podman -v 2> /dev/null | head -1)
    PODMAN_RUNTIME_VERSION=$(echo $CONTAINER_STR | awk -F'version ' '{print $2 }')
    printf "Podman        :      $PODMAN_RUNTIME_VERSION\n"
  fi

  if [ -x "/usr/bin/docker" ]; then
    # only check if docker is a binary and not a podman script
    if [ -n "$(file /usr/bin/docker 2> /dev/null | grep ELF)" ]; then
      CONTAINER_STR=$(docker -v | head -1)
      DOCKER_RUNTIME_VERSION=$(echo $CONTAINER_STR | awk -F'version ' '{print $2 }'|cut -d"," -f1)
      printf "Docker        :      $DOCKER_RUNTIME_VERSION\n"
    fi
  fi

  CONTAINER_STR=$(nerdctl -v 2> /dev/null | head -1)

  if [ -n "$CONTAINER_STR" ]; then
      DOCKER_RUNTIME_VERSION=$(echo $CONTAINER_STR | awk -F'version ' '{print $2 }'|cut -d"," -f1)
      printf "Nerdctl       :      $DOCKER_RUNTIME_VERSION\n"
  fi

  DOMINO_DOWNLOAD_VER=$(domdownload --version 2> /dev/null)

  if [ -n "$DOMINO_DOWNLOAD_VER" ]; then
      printf "DomDownload   :      $DOMINO_DOWNLOAD_VER\n"
  else
      printf "DomDownload   :      [not installed]\n"
  fi

  printf "\n"

  printf "CPU Info      :      $CPU_INFO\n"
  printf "CPU MHz       :      $CPU_MHZ\n"
  printf "CPU Cache     :      $CPU_CACHE_SIZE\n"

  printf "\n"

  if [ -n "$CONTAINER_UPTIME" ]; then
    printf "Host Uptime   :      $LINUX_UPTIME\n"
    printf "CTR  Uptime   :      $CONTAINER_UPTIME\n"
  else
    printf "Linux Uptime  :      $LINUX_UPTIME\n"
  fi

  if [ -n "$DOMINO_UPTIME" ]; then
    printf "Domino Uptime :      $DOMINO_UPTIME\n"
  fi

  printf "Load Average  :      $LINUX_LOAD_AVG\n"

  printf "\n"

  printf "MemTotal      :      $MEM_TOTAL_INFO\n"
  printf "MemAvailable  :      $MEM_AVAIL_INFO\n"
  printf "MemCached     :      $MEM_CACHED_INFO\n"
  printf "MemFree       :      $MEM_FREE_INFO\n"
  print_delim
  printf "\n"

  if [ ! "$1" = "ipinfo" ]; then
    return
  fi


  JQ_VERSION=$(jq --version 2>/dev/null)

  if [ -z "$JQ_VERSION" ]; then
    return
  fi

  if [ ! -x /usr/bin/curl ]; then
    return
  fi

  JQ="jq -r"

  IPINFO_JSON=$(curl -s ipinfo.io/json)
  IPINFO_ORG=$(echo $IPINFO_JSON | $JQ .org)
  IPINFO_CITY=$(echo $IPINFO_JSON | $JQ .city)
  IPINFO_COUNTRY=$(echo $IPINFO_JSON | $JQ .country)
  IPINFO_REGION=$(echo $IPINFO_JSON | $JQ .region)
  IPINFO_LOC=$(echo $IPINFO_JSON | $JQ .loc)
  IPINFO_POSTAL=$(echo $IPINFO_JSON | $JQ .postal)
  IPINFO_TIMEZONE=$(echo $IPINFO_JSON | $JQ .timezone)
  IPINFO_IP=$(echo $IPINFO_JSON | $JQ .ip)
  IPINFO_HOSTNAME=$(echo $IPINFO_JSON | $JQ .hostname)

  printf "External Host :      $IPINFO_HOSTNAME\n"
  printf "External IP   :      $IPINFO_IP\n"
  printf "Organisation  :      $IPINFO_ORG\n"
  printf "City          :      $IPINFO_CITY\n"
  printf "ZIP           :      $IPINFO_POSTAL\n"
  printf "Region        :      $IPINFO_REGION\n"
  printf "Timezone      :      $IPINFO_TIMEZONE\n"
  printf "Location      :      $IPINFO_LOC\n"

  print_delim
  printf "\n"
}

print_infos $@

