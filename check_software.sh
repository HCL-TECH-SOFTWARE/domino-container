#!/bin/bash

if [ -z "$SOFTWARE_DIR" ]; then
  SOFTWARE_DIR=/local/software
fi

if [ -z "$DOWNLOAD_FROM" ]; then
  DOWNLOAD_FROM=
  #DOWNLOAD_FROM=http://centos-mirror.nashcom.loc/software
fi

#CHECK_HASH=yes
DOWNLOAD_URLS_SHOW=yes

# -----------------------

SCRIPT_NAME=$0
SOFTWARE_FILE_NAME=software.txt
SOFTWARE_FILE=$SOFTWARE_DIR/software.txt
VERSION_FILE_NAME=current_version.txt
VERSION_FILE=$SOFTWARE_DIR/$VERSION_FILE_NAME

DOWNLOAD_LINK_IBM_PA_PARTNO="https://www.ibm.com/software/howtobuy/passportadvantage/paocustomer/sdma/SDMA?P0=DOWNLOAD_SEARCH_BY_PART_NO&FIELD_SEARCH_TYPE=3&searchVal="
DOWNLOAD_LINK_IBM_PA_SEARCH=https://www.ibm.com/software/howtobuy/passportadvantage/paocustomer/sdma/SDMA?P0=DOWNLOAD_SEARCH_PART_NO_OR_DESCRIPTION
DOWNLOAD_LINK_IBM_CE="https://www.ibm.com/account/reg/us-en/signup?formid=urx-33713"

WGET_COMMAND="wget --connect-timeout=20"

ERROR_COUNT=0

error_count_inc ()
{
  ERROR_COUNT=$((ERROR_COUNT+1));
}

log_debug ()
{
  return 0
  echo "$1" "$2" "$3"
}

get_current_version ()
{
 if [ ! -z "$DOWNLOAD_FROM" ]; then

    DOWNLOAD_FILE=$DOWNLOAD_FROM/$VERSION_FILE_NAME

    WGET_RET_OK=`$WGET_COMMAND -S --spider "$DOWNLOAD_FILE" 2>&1 | grep 'HTTP/1.1 200 OK'`
    if [ ! -z "$WGET_RET_OK" ]; then
      DOWNLOAD_VERSION_FILE=$DOWNLOAD_FILE
      log_debug "Getting software version from [$DOWNLOAD_VERSION_FILE]"
    fi
  fi

  if [ ! -z "$DOWNLOAD_VERSION_FILE" ]; then
    LINE=`$WGET_COMMAND -qO- $DOWNLOAD_VERSION_FILE | grep "^$1|"`
  else
    if [ ! -r $VERSION_FILE ]; then
      echo "No current version file found! [$VERSION_FILE]"
    else
      LINE=`grep "^$1|" $VERSION_FILE`
    fi
  fi

  PROD_VER=`echo $LINE|cut -d'|' -f2` 
  PROD_FP=`echo $LINE|cut -d'|' -f3` 
  PROD_HF=`echo $LINE|cut -d'|' -f4` 

  export PROD_VER
  export PROD_FP
  export PROD_HF

  return 0
}

check_software ()
{
  CURRENT_NAME=`echo $1|cut -d'|' -f1` 
  CURRENT_VER=`echo $1|cut -d'|' -f2` 
  CURRENT_FILE=`echo $1|cut -d'|' -f3` 
  CURRENT_PARTNO=`echo $1|cut -d'|' -f4` 
  CURRENT_HASH=`echo $1|cut -d'|' -f5` 

  if [ -z "$DOWNLOAD_FROM" ]; then
    if [ -r $SOFTWARE_DIR/$CURRENT_FILE ]; then

      if [ -z "$CURRENT_HASH" ]; then
        CURRENT_STATUS="NF"
      else
        if [ -z "$CHECK_HASH" ]; then
          CURRENT_STATUS="OK"
        else
          HASH=`sha256sum $SOFTWARE_DIR/$CURRENT_FILE -b | cut -d" " -f1`

          if [ "$CURRENT_HASH" = "$HASH" ]; then
            CURRENT_STATUS="OK"
          else
            CURRENT_STATUS="CR"
          fi
        fi
      fi
    else
      CURRENT_STATUS="NF"
    fi
  else

    DOWNLOAD_FILE=$DOWNLOAD_FROM/$CURRENT_FILE
    WGET_RET_OK=`$WGET_COMMAND -S --spider "$DOWNLOAD_FILE" 2>&1 | grep 'HTTP/1.1 200 OK'`
    if [ -z "$WGET_RET_OK" ]; then
      CURRENT_STATUS="NA"
    else
      if [ -z "$CURRENT_HASH" ]; then
        CURRENT_STATUS="OK"
      else
        if [ -z "$CHECK_HASH" ]; then
          CURRENT_STATUS="OK"
        else
          HASH=`$WGET_COMMAND -qO- $DOWNLOAD_FILE | sha256sum -b | cut -d" " -f1`
          if [ "$CURRENT_HASH" = "$HASH" ]; then
            CURRENT_STATUS="OK"
          else
            CURRENT_STATUS="CR"
          fi
        fi
      fi
    fi
  fi

  case "$CURRENT_NAME" in
    domino|traveler|appdevpack)

      if [ -z "$CURRENT_PARTNO" ]; then
        CURRENT_DOWNLOAD_URL="$DOWNLOAD_LINK_IBM_PA_SEARCH"
      elif [ "$CURRENT_PARTNO" = "-" ]; then
        CURRENT_DOWNLOAD_URL="$DOWNLOAD_LINK_IBM_PA_SEARCH"
      else
        CURRENT_DOWNLOAD_URL="$DOWNLOAD_LINK_IBM_PA_PARTNO$CURRENT_PARTNO"
      fi
      ;;

    domino-ce)
      CURRENT_DOWNLOAD_URL="$DOWNLOAD_LINK_IBM_CE"
      ;;

    *)
      CURRENT_DOWNLOAD_URL=""
      ;;
  esac

  count=`echo $CURRENT_VER | wc -c`
  while [[ $count -lt 20 ]] ;
  do
    CURRENT_VER="$CURRENT_VER "
    count=$((count+1));
  done;

  echo "$CURRENT_VER [$CURRENT_STATUS]  $CURRENT_FILE  ($CURRENT_PARTNO)"

  if [ ! -z "$DOWNLOAD_URLS_SHOW" ]; then
    echo $CURRENT_DOWNLOAD_URL
  elif [ ! "$CURRENT_STATUS" = "OK" ]; then
    echo $CURRENT_DOWNLOAD_URL
    echo
    error_count_inc
  fi

  return 0
}


check_software_file ()
{
  FOUND=""

  if [ -z "$PROD_NAME" ]; then
    echo
    echo "--- $1 ---"
    echo
  fi

  if [ -z "$2" ]; then
    SEARCH_STR="^$1|"
  else
    SEARCH_STR="^$1|$2|"
  fi

  if [ -z "$DOWNLOAD_SOFTWARE_FILE" ]; then

    while read LINE  
    do  
      check_software $LINE  
      FOUND="TRUE"
    done < <(grep "$SEARCH_STR" $SOFTWARE_FILE)
  else
    while read LINE
    do
      check_software $LINE
      FOUND="TRUE"
    done < <($WGET_COMMAND -qO- $DOWNLOAD_SOFTWARE_FILE | grep "$SEARCH_STR")
  fi

  if [ -z "$PROD_NAME" ]; then
    echo
  else
    if [ ! "$FOUND" = "TRUE" ]; then

      CURRENT_VER=$2
      count=`echo $CURRENT_VER | wc -c`
      while [[ $count -lt 20 ]] ;
      do
        CURRENT_VER="$CURRENT_VER "
        count=$((count+1));
      done;

      echo "$CURRENT_VER [NF]  Not found in download file!"
      error_count_inc
    fi
  fi

}

check_software_status ()
{
  if [ ! -z "$DOWNLOAD_FROM" ]; then

    DOWNLOAD_FILE=$DOWNLOAD_FROM/$SOFTWARE_FILE_NAME

    WGET_RET_OK=`$WGET_COMMAND -S --spider "$DOWNLOAD_FILE" 2>&1 | grep 'HTTP/1.1 200 OK'`
    if [ ! -z "$WGET_RET_OK" ]; then
      DOWNLOAD_SOFTWARE_FILE=$DOWNLOAD_FILE
      log_debug "Checking software via [$DOWNLOAD_SOFTWARE_FILE]"
    fi

  else

    if [ ! -r "$SOFTWARE_FILE" ]; then
      echo "Software [$SOFTWARE_FILE] Not found!"
      ERROR_COUNT=99
      return 1
     else
      log_debug "Checking software via [$SOFTWARE_FILE]"
    fi
  fi

  if [ -z "$PROD_NAME" ]; then
    check_software_file "domino" 
    check_software_file "domino-ce"
    check_software_file "traveler"
  else
    echo

    if [ -z "$PROD_VER" ]; then
      check_software_file "$PROD_NAME"
    else
      check_software_file "$PROD_NAME" "$PROD_VER"

      if [ ! -z "$PROD_FP" ]; then
        check_software_file "$PROD_NAME" "$PROD_VER$PROD_FP"
      fi

      if [ ! -z "$PROD_HF" ]; then
        check_software_file "$PROD_NAME" "$PROD_VER$PROD_FP$PROD_HF"
      fi
    fi
    echo
  fi
}

PROD_NAME=$1
PROD_VER=`echo "$2" | awk '{print toupper($0)}'`
PROD_FP=`echo "$3" | awk '{print toupper($0)}'`
PROD_HF=`echo "$4" | awk '{print toupper($0)}'`

if [ "$PROD_VER" = "." ]; then 
  get_current_version "$PROD_NAME"
  echo
  echo "Current Version: $PROD_NAME $PROD_VER$PROD_FP$PROD_HF"
fi

if [ "$ERROR_COUNT" = "0" ]; then
  check_software_status
fi

if [ ! "$ERROR_COUNT" = "0" ]; then
  echo "Correct Software Download Error(s) before building image [$ERROR_COUNT]"

  if [ -z "$DOWNLOAD_FROM" ]; then
    if [ -z $SOFTWARE_DIR ]; then
      echo "No download location or software directory specified!"
      ERROR_COUNT=99
    else
      echo "Copy files to [$SOFTWARE_DIR]"
    fi
  else
    echo "Upload files to [$DOWNLOAD_FROM]"
  fi     

  echo
fi

export CHECK_SOFTWARE_STATUS=$ERROR_COUNT
