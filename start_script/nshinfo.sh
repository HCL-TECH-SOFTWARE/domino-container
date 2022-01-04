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

print_infos()
{
  if [ -r  /etc/os-release ]; then
    get_entry LINUX_VERSION /etc/os-release "VERSION_ID=" "="
    get_entry LINUX_PRETTY_NAME /etc/os-release "PRETTY_NAME=" "="
    get_entry LINUX_ID /etc/os-release "ID=" "="
  fi

  LINUX_KERNEL=$(uname -r)
  LINUX_ARCH==$(uname -m)
  LINUX_UPTIME=$( awk '{x=$1/86400;y=($1%86400)/3600;z=($1%3600)/60} {printf("%d day, %d hour %d min\n",x,y,z)}' /proc/uptime )
  LINUX_LOAD_AVG=$(awk -F " " '{printf $1 "  " $2 "  " $3}' /proc/loadavg)

  LINUX_HOSTNAME=$(cat /proc/sys/kernel/hostname)

  get_entry CPU_MODEL /proc/cpuinfo "model name"
  get_entry CPU_MHZ /proc/cpuinfo "cpu MHz"
  get_entry CPU_CACHE_SIZE /proc/cpuinfo "cache size"

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


  local CONTAINER_STR=

  if [ -x /usr/bin/podman ]; then
    CONTAINER_STR=$(podman version)
    PODMAN_RUNTIME_VERSION=$(echo $CONTAINER_STR | cut -d" " -f2)
    printf "Podman        :      $PODMAN_RUNTIME_VERSION\n"
  fi

  if [ -x "/usr/bin/docker" ]; then
    # only check if docker is a binary and not a podman script
    if [ -n "$(file /usr/bin/docker | grep ELF)" ]; then
      CONTAINER_STR=$(docker -v)
      DOCKER_RUNTIME_VERSION=$(echo $CONTAINER_STR | cut -d" " -f3|cut -d"," -f1)
      printf "Docker        :      $DOCKER_RUNTIME_VERSION\n"
    fi
  fi

  printf "\n"

  printf "CPU Model     :      $CPU_MODEL\n"
  printf "CPU MHz       :      $CPU_MHZ\n"
  printf "CPU Cache     :      $CPU_CACHE_SIZE\n"

  printf "\n"

  printf "Uptime        :      $LINUX_UPTIME\n"
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

  if [ ! -x /usr/bin/jq ]; then
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

