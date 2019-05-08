#!/bin/bash

#SOFTWARE_DIR=/local/software
#DOWNLOAD_FROM=http://centos-mirror.nashcom.loc/software

. ./check_software.sh "$1" "$2"

echo "--- returned install product info ---"

echo "PROD_NAME: [$PROD_NAME]"
echo "PROD_VER : [$PROD_VER]"
echo "PROD_FP  : [$PROD_FP]"
echo "PROD_HF  : [$PROD_HF]"
echo "CHECK_SOFTWARE_STATUS : [$CHECK_SOFTWARE_STATUS]"


