#!/bin/bash

############################################################################
# Copyright Nash!Com, Daniel Nashed 2019, 2020 - APACHE 2.0 see LICENSE
# Copyright IBM Corporation 2015, 2019 - APACHE 2.0 see LICENSE
############################################################################

if [ -z "$SOFTWARE_DIR" ]; then
  SOFTWARE_DIR=./software
fi

if [ -z "$DOWNLOAD_FROM" ]; then
  DOWNLOAD_FROM=
fi

# -----------------------

SCRIPT_NAME=$0
SOFTWARE_FILE_NAME=software.txt
SOFTWARE_FILE=$SOFTWARE_DIR/software.txt

# if software file isn't found check standard location (check might lead to the same directory if standard location already)
if [ ! -e "$SOFTWARE_FILE" ]; then
  SOFTWARE_FILE=$PWD/software/$SOFTWARE_FILE_NAME
fi

DOWNLOAD_LINK_FLEXNET="https://hclsoftware.flexnetoperations.com/flexnet/operationsportal/DownloadSearchPage.action?search="
DOWNLOAD_LINK_FLEXNET_OPTIONS="+&resultType=Files&sortBy=eff_date&listButton=Search"

CURL_CMD="curl --fail --connect-timeout 15 --max-time 300 $SPECIAL_CURL_ARGS"

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

check_software ()
{
  CURRENT_NAME=$(echo $1|cut -d'|' -f1)
  CURRENT_VER=$(echo $1|cut -d'|' -f2)
  CURRENT_FILES=$(echo $1|cut -d'|' -f3)
  CURRENT_PARTNO=$(echo $1|cut -d'|' -f4)
  CURRENT_HASH=$(echo $1|cut -d'|' -f5)

  if [ -z "$DOWNLOAD_FROM" ]; then
 
    FOUND=
    DOWNLOAD_1ST_FILE=
 
    for CHECK_FILE in $(echo "$CURRENT_FILES" | tr "," "\n") ; do
      if [ -z "$DOWNLOAD_1ST_FILE" ]; then
        DOWNLOAD_1ST_FILE=$CHECK_FILE
      fi
    	
      if [ -r "$SOFTWARE_DIR/$CHECK_FILE" ]; then
        CURRENT_FILE="$CHECK_FILE"
        FOUND=TRUE
        break
      fi
    done
  	
    if [ "$FOUND" = "TRUE" ]; then
      if [ -z "$CURRENT_HASH" ]; then
        CURRENT_STATUS="NA"
      else
        if [ ! "$CHECK_HASH" = "yes" ]; then
          CURRENT_STATUS="OK"
        else
          HASH=$(sha256sum $SOFTWARE_DIR/$CURRENT_FILE -b | cut -d" " -f1)

          if [ "$CURRENT_HASH" = "$HASH" ]; then
            CURRENT_STATUS="OK"
          else
            CURRENT_STATUS="CR"
          fi
        fi
      fi
    else
      CURRENT_STATUS="NA"
    fi
  else

    FOUND=
    DOWNLOAD_1ST_FILE=
  
    for CHECK_FILE in $(echo "$CURRENT_FILES" | tr "," "\n") ; do

      if [ -z "$DOWNLOAD_1ST_FILE" ]; then
        DOWNLOAD_1ST_FILE=$CHECK_FILE
      fi

      DOWNLOAD_FILE=$DOWNLOAD_FROM/$CHECK_FILE

      CURL_RET=$($CURL_CMD "$DOWNLOAD_FILE" --silent --head 2>&1)
      STATUS_RET=$(echo $CURL_RET | grep 'HTTP/1.1 200 OK')

      if [ -n "$STATUS_RET" ]; then
        CURRENT_FILE="$CHECK_FILE"
        FOUND=TRUE
        break
      fi
    done
  	
    if [ ! "$FOUND" = "TRUE" ]; then
      CURRENT_STATUS="NA"
    else
      if [ -z "$CURRENT_HASH" ]; then
        CURRENT_STATUS="OK"
      else
        if [ ! "$CHECK_HASH" = "yes" ]; then
          CURRENT_STATUS="OK"
        else
          DOWNLOAD_FILE=$DOWNLOAD_FROM/$CHECK_FILE
          HASH=$($CURL_CMD --silent $DOWNLOAD_FILE 2>/dev/null | sha256sum -b | cut -d" " -f1)

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
    domino|traveler|volt)

      if [ -z "$CURRENT_PARTNO" ]; then
        CURRENT_DOWNLOAD_URL="$DOWNLOAD_LINK_FLEXNET$DOWNLOAD_1ST_FILE$DOWNLOAD_LINK_FLEXNET_OPTIONS"
      elif [ "$CURRENT_PARTNO" = "-" ]; then
        CURRENT_DOWNLOAD_URL="$DOWNLOAD_LINK_FLEXNET$DOWNLOAD_1ST_FILE$DOWNLOAD_LINK_FLEXNET_OPTIONS"
      else
        CURRENT_DOWNLOAD_URL="$DOWNLOAD_LINK_FLEXNET$DOWNLOAD_1ST_FILE$DOWNLOAD_LINK_FLEXNET_OPTIONS"
      fi
      ;;

    *)
      CURRENT_DOWNLOAD_URL=""
      ;;
  esac

  count=$(echo $CURRENT_VER | wc -c)
  while [[ $count -lt 20 ]] ;
  do
    CURRENT_VER="$CURRENT_VER "
    count=$((count+1));
  done;

  echo "$CURRENT_VER [$CURRENT_STATUS]  $DOWNLOAD_1ST_FILE  ($CURRENT_PARTNO)"

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
    done < <($CURL_CMD --silent $DOWNLOAD_SOFTWARE_FILE | grep "$SEARCH_STR")
  fi

  if [ -z "$PROD_NAME" ]; then
    echo
  else
    if [ ! "$FOUND" = "TRUE" ]; then

      CURRENT_VER=$2
      count=$(echo $CURRENT_VER | wc -c)
      while [[ $count -lt 20 ]] ;
      do
        CURRENT_VER="$CURRENT_VER "
        count=$((count+1));
      done;

      echo "$CURRENT_VER [NA] Not found in software file!"
      error_count_inc
    fi
  fi
}

check_software_status ()
{
  if [ ! -z "$DOWNLOAD_FROM" ]; then

    DOWNLOAD_FILE=$DOWNLOAD_FROM/$SOFTWARE_FILE_NAME

    CURL_RET=$($CURL_CMD "$DOWNLOAD_FILE" --silent --head 2>&1)
    STATUS_RET=$(echo $CURL_RET | grep 'HTTP/1.1 200 OK')
    if [ -n "$STATUS_RET" ]; then

      DOWNLOAD_SOFTWARE_FILE=$DOWNLOAD_FILE
      echo "Checking software via [$DOWNLOAD_SOFTWARE_FILE]"
    fi

  else

    if [ ! -r "$SOFTWARE_FILE" ]; then
      echo "Software [$SOFTWARE_FILE] Not found!"
      ERROR_COUNT=99
      return 1
    else
      echo "Checking software via [$SOFTWARE_FILE]"
    fi
  fi

  if [ -z "$PROD_NAME" ]; then
    check_software_file "domino" 
    check_software_file "traveler"
    check_software_file "volt"

    if [ -n "$VERSE_VERSION" ]; then
      check_software_file "verse" "$VERSE_VERSION"
    fi

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

    if [ -n "$VERSE_VERSION" ]; then
      check_software_file "verse" "$VERSE_VERSION"
    fi

    echo
  fi
}

PROD_NAME=$1
PROD_VER=$(echo "$2" | awk '{print toupper($0)}')
PROD_FP=$(echo "$3" | awk '{print toupper($0)}')
PROD_HF=$(echo "$4" | awk '{print toupper($0)}')

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

