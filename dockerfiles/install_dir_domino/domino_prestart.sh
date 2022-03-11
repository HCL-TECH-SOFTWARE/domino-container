#!/bin/bash

############################################################################
# Copyright Nash!Com, Daniel Nashed 2019, 2022 - APACHE 2.0 see LICENSE
# Copyright IBM Corporation 2015, 2019 - APACHE 2.0 see LICENSE
############################################################################

if [ "$DOMDOCK_DEBUG_SHELL" = "yes" ]; then
  echo "--- Enable shell debugging ---"
  set -x
fi

# Include helper functions & defines
. /domino-container/scripts/script_lib.sh

# Write setup log -> ensure directory is created
if [ ! -e "$DOMINO_DATA_PATH/IBM_TECHNICAL_SUPPORT" ]; then
  mkdir -p $DOMINO_DATA_PATH/IBM_TECHNICAL_SUPPORT
fi

LOG_FILE=$DOMINO_DATA_PATH/IBM_TECHNICAL_SUPPORT/domino_server_setup.log


download_file()
{
  local DOWNLOAD_URL=$1
  local DOWNLOAD_FILE=$2
  local HEADER=

  if [ -n "$3" ]; then
    HEADER="$3: "
  fi

  if [ -z "$DOWNLOAD_FILE" ]; then
    log_file "Error: No download file specified!"
    exit 1
  fi

  $CURL_CMD -o /dev/null --head "$DOWNLOAD_URL"
  if [ ! "$?" = "0" ]; then
    log_file "Error: Download file does not exist [$DOWNLOAD_FILE]"
    exit 1
  fi

  log_file "[download:$DOWNLOAD_FILE]"
  if [ -e "$DOWNLOAD_FILE" ]; then
    log_file "Replacing existing file [$DOWNLOAD_FILE]"
    rm -f "$DOWNLOAD_FILE"
  fi

  $CURL_CMD "$DOWNLOAD_URL" -o $DOWNLOAD_FILE

  if [ "$?" = "0" ]; then
    log_file "${HEADER}Successfully downloaded: [$DOWNLOAD_FILE]"
    return 0
  else
    log_file "${HEADER}File [$DOWNLOAD_FILE] not downloaded correctly from [$DOWNLOAD_URL]"
    return 1
  fi
}

download_file_link()
{
  local S1=$1
  local S2=${!1}

  case "$S2" in

    http:*|https:*)
      local FILE_NAME=$(basename $S2)
      export $1=$FILE_NAME
      download_file "$S2" "$FILE_NAME"

      if [ $? -eq 1 ]; then
        export $1=
      fi
      ;;

    *)
      export $1=$S2
      ;;
  esac
}

get_secret_via_http()
{
  local DOWNLOAD_URL=$2

  $CURL_CMD -o /dev/null --head "$DOWNLOAD_URL"
  if [ ! "$?" = "0" ]; then
    log_file "Error: Cannot download [$2]"
    exit 1
  fi

  export $1=$($CURL_CMD "$DOWNLOAD_URL")
}

get_secret_via_file()
{
  local SECRET_FILE=$(echo $2|cut -d":" -f2)
  if [ ! -r "$SECRET_FILE" ]; then
    log_file "File not found [$SECRET_FILE]"
    exit 1
  fi

  export $1=$(cat $SECRET_FILE)
}

get_secret_var()
{
  local S1=$1
  local S2=${!1}

  if [ -z "$S1" ]; then return 0; fi
  if [ -z "$S2" ]; then return 0; fi

  case "$S2" in
    http:*|https:*)
      get_secret_via_http "$S1" "$S2"
      ;;

    file:*)
      get_secret_via_file "$S1" "$S2"
      ;;
    *)
      export $1=$S2
      ;;
  esac
}

replace_secret_vars()
{
  # Domino One-Touch Password variables

  get_secret_var SERVERSETUP_ADMIN_PASSWORD
  get_secret_var SERVERSETUP_SERVER_PASSWORD
  get_secret_var SERVERSETUP_ORG_CERTIFIERPASSWORD
  get_secret_var SERVERSETUP_ORG_ORGUNITPASSWORD
  get_secret_var SERVERSETUP_SECURITY_TLSSETUP_IMPORTFILEPASSWORD
  get_secret_var SERVERSETUP_SECURITY_TLSSETUP_EXPORTPASSWORD
}

check_download_file_links()
{
  # Domino One-Touch ID file variables

  # Donwload ID files if they start with http(s):
  download_file_link SERVERSETUP_ORG_CERTIFIERIDFILEPATH
  download_file_link SERVERSETUP_ORG_ORGUNITIDFILEPATH
  download_file_link SERVERSETUP_SERVER_IDFILEPATH
  download_file_link SERVERSETUP_ADMIN_IDFILEPATH
  download_file_link SERVERSETUP_SECURITY_TLSSETUP_IMPORTFILEPATH

  download_file_link SetupAutoConfigureParams

  # Additional Community image paramters
  download_file_link SafeIDFile

  return 0
}


# --- Main Logic ---

NOW=$(date)
log_file_header "$NOW"

# Switch to data directory for downloads
cd $DOMINO_DATA_PATH

# If CustomNotesdataZip file downlaod URL defined, download from remote location and unzip
download_file_link CustomNotesdataZip

# Expand & delete ZIP

if [ -n "$CustomNotesdataZip" ]; then
  if [ -r "$CustomNotesdataZip" ]; then
    log_file_header "Extracting custom notesdata file [$CustomNotesdataZip]"

    unzip -o "$CustomNotesdataZip" >> $LOG_FILE 2>&1
    rm -f "$CustomNotesdataZip"

  else
    log_file "Custom notesdata [$CustomNotesdataZip] not found!"
  fi
fi

# Replace secret variables with file content or http download
replace_secret_vars

# Download ID files if http download specified
check_download_file_links

# Ensure server.id name is always default name and rename if needed
if [ -e "$ServerIDFile" ]; then
  if [ ! "$ServerIDFile" = "server.id" ]; then
    secure_move_file "$ServerIDFile" "server.id"
  fi
fi

# Ensure it is set, even not specified
ServerIDFile=server.id

# Domino One-Touch needs the hostname. Try to determine it, if not specified.

if [ -z "$SERVERSETUP_NETWORK_HOSTNAME" ]; then
  if [ -x /usr/bin/hostname ]; then
    export SERVERSETUP_NETWORK_HOSTNAME=$(hostname)
  else
    export SERVERSETUP_NETWORK_HOSTNAME=$(cat /proc/sys/kernel/hostname)
  fi
fi

log_file "SetupAutoConfigureParams: [$SetupAutoConfigureParams]"

cd $DOMINO_DATA_PATH

log_file "Server start will run Domino Server Auto Setup"

log_file "Prestart script - Done"

