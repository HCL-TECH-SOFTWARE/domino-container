#!/bin/bash

print_delim ()
{
  echo "--------------------------------------------------------------------------------"
}

get_entry()
{
  if [ -z "$4" ]; then
    DELIM=":"
  else
    DELIM="$4"
  fi
  
  export $1="$(sed -n "/^$3/ {p;q}" $2| cut -d $DELIM -f2 | xargs)"
}

get_infos ()
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
}


get_infos

printf "\n"
print_delim

printf "Linux OS      :      $LINUX_PRETTY_NAME\n"
printf "Linux Version :      $LINUX_VERSION\n"
printf "Kernel        :      $LINUX_KERNEL\n"

printf "CPU Model     :      $CPU_MODEL\n"
printf "CPU MHz       :      $CPU_MHZ\n"
printf "CPU Cache     :      $CPU_CACHE_SIZE\n"

printf "\n"

printf "Uptime        :      $LINUX_UPTIME\n"
printf "Load Average  :      $LINUX_LOAD_AVG\n"

printf "\n"
print_delim

printf "Hostname      :      $LINUX_HOSTNAME\n"
printf "External Host :      $IPINFO_HOSTNAME\n"
printf "External IP   :      $IPINFO_IP\n"
printf "Organisation  :      $IPINFO_ORG\n"
printf "City          :      $IPINFO_CITY\n"
printf "ZIP           :      $IPINFO_POSTAL\n"
printf "Region        :      $IPINFO_REGION\n"
printf "Timezone      :      $IPINFO_TIMEZONE\n"
printf "Location      :      $IPINFO_LOC\n"

printf "\n"


