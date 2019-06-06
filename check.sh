#!/bin/bash

#SOFTWARE_DIR=/local/software
#DOWNLOAD_FROM=http://centos-mirror.nashcom.loc/software

# external configuration
CONFIG_FILE=/local/cfg/build_config

# use a config file if present
if [ -e "$CONFIG_FILE" ]; then
  echo "(Using config file $CONFIG_FILE)"
  . $CONFIG_FILE
fi

. ./check_software.sh "$1" "$2" "$3" "$4"

echo "--- Returned install product info ---"

echo "PROD_NAME: [$PROD_NAME]"
echo "PROD_VER : [$PROD_VER]"
echo "PROD_FP  : [$PROD_FP]"
echo "PROD_HF  : [$PROD_HF]"
echo "CHECK_SOFTWARE_STATUS : [$CHECK_SOFTWARE_STATUS]"


