#!/bin/bash
############################################################################
# Copyright Nash!Com, Daniel Nashed 2025  - APACHE 2.0 see LICENSE
# Copyright IBM Corporation 2015, 2020 - APACHE 2.0 see LICENSE
############################################################################

SCRIPT_NAME=$(readlink -f $0)
SCRIPT_DIR=$(dirname $SCRIPT_NAME)

log_error_exit()
{
  echo
  echo "ERROR: $@"
  echo
  exit 1
}


usage ()
{

  echo
  echo
  echo "Alpine based compile for C/C++ applications"
  echo "-------------------------------------------"
  echo
  echo "Builds statically linked binaries in Alpine Linux which run glibc version independent."
  echo "Supports: OpenSSL, LibCurl and RapidJSON."
  echo
  echo "Usage: $(basename $SCRIPT_NAME) source-dir [Options]"
  echo
  echo Options:
  echo
  echo "clean            clean binaries and objects"
  echo "-clean           run clean before building"
  echo

  return 0
}


for a in "$@"; do

  p=$(echo "$a" | awk '{print tolower($0)}')

  case "$p" in
    clean)
      BUILD_ACTION_CLEAN=1 
      ;;

    -clean)
      BUILD_ACTION_CLEAN=2 
      ;;

    -h|/h|-?|/?|-help|--help|help|usage)
      usage
      exit 0
      ;;

    -*)
      log_error_exit "Invalid parameter [$a]"
      ;;

    *)
      SRC_DIR=$a

  esac
done


if [ -z "$SRC_DIR" ]; then
   log_error_exit "No source directory specified"
fi

if [ -n "$BUILD_ACTION_CLEAN" ]; then

   CURRENT_DIR=$(pwd)
   cd "$SRC_DIR"
   make clean
   cd "$CURRENT_DIR"

   if [ "$BUILD_ACTION_CLEAN" = "1" ]; then
     exit 0
   fi

fi


docker run --rm -v $SRC_DIR:/src -w /src -u 0 nashcom/alpine_build_environment:latest sh -c 'SPECIAL_LINK_OPTIONS=-static make'
