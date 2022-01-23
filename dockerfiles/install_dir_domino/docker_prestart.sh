#!/bin/bash

############################################################################
# Copyright Nash!Com, Daniel Nashed 2019, 2022 - APACHE 2.0 see LICENSE
# Copyright IBM Corporation 2015, 2019 - APACHE 2.0 see LICENSE
############################################################################

if [ "$DOMDOCK_DEBUG_SHELL" = "yes" ]; then
  echo "--- Enable shell debugging ---"
  set -x
fi

export LOTUS=/opt/hcl/domino

# ServerName variable or Auto Config is the configuration trigger
if [ -z "$SetupAutoConfigure" ]; then
  echo "No Setup Environment Configuration -- Skipping setup"
  exit 0
fi

# Write setup log into volume
if [ ! -e "$DOMINO_DATA_PATH/IBM_TECHNICAL_SUPPORT" ]; then
  mkdir -p $DOMINO_DATA_PATH/IBM_TECHNICAL_SUPPORT
fi 

LOG_FILE=$DOMINO_DATA_PATH/IBM_TECHNICAL_SUPPORT/domino_server_setup.log

CURL_CMD="curl --silent --location --fail --connect-timeout 15 --max-time 300 $SPECIAL_CURL_ARGS"

log()
{
  echo "$@" >> $LOG_FILE
}

log_space()
{
  echo  >> $LOG_FILE
  echo "$@" >> $LOG_FILE
  echo  >> $LOG_FILE
}

print_delim()
{
  echo "--------------------------------------------------------------------------------" >> $LOG_FILE
}

header()
{
  echo >> $LOG_FILE
  print_delim
  echo "$@" >> $LOG_FILE
  print_delim
  echo >> $LOG_FILE
}

log_debug()
{
  if [ "$DOMDOCK_DEBUG" = "yes" ]; then
    echo "$(date '+%F %T') debug: $@"
  fi
}

secure_move_file()
{
  # Routine to move a file with proper error checks and warnings

  # Check if source file is present
  if [ ! -e "$1" ]; then
    log "Cannot rename [$1] - file does not exist"
    return 1
  fi

  # Check if target already exist and try to remove first
  if [ -e "$2" ]; then

    rm -f "$2" > /dev/null 2>&1

    if [ -e "$2" ]; then
      log "Cannot rename [$1] to [$2]  - target cannot be removed"
      return 1
    else
      log "Replacing file [$2] with [$1]"
    fi

  else
    log "Renaming file [$1] to [$2]"
  fi

  # Now copy file
  cp -f "$1" "$2" > /dev/null 2>&1

  if [ -e "$2" ]; then

    # Try to remove source file after copy
    rm -f "$1" > /dev/null 2>&1

    if [ -e "$1" ]; then
      log "Warning: cannot remove source file [$1]"
    fi

    return 0

  else
    log "Error copying file [$1] to [$2]"
    return 1
  fi
}

download_file ()
{
  local DOWNLOAD_URL=$1
  local DOWNLOAD_FILE=$2
  local HEADER=

  if [ -n "$3" ]; then
    HEADER="$3: "
  fi

  if [ -z "$DOWNLOAD_FILE" ]; then
    log "Error: No download file specified!"
    exit 1
  fi

  $CURL_CMD -o /dev/null --head "$DOWNLOAD_URL"
  if [ ! "$?" = "0" ]; then
    log "Error: Download file does not exist [$DOWNLOAD_FILE]"
    exit 1
  fi

  log "[download:$DOWNLOAD_FILE]"
  if [ -e "$DOWNLOAD_FILE" ]; then
    log "Replacing existing file [$DOWNLOAD_FILE]"
    rm -f "$DOWNLOAD_FILE"
  fi

  $CURL_CMD "$DOWNLOAD_URL" -o $DOWNLOAD_FILE

  if [ "$?" = "0" ]; then
    log "${HEADER}Successfully downloaded: [$DOWNLOAD_FILE]"
    return 0
  else
    log "${HEADER}File [$DOWNLOAD_FILE] not downloaded correctly from [$DOWNLOAD_URL]"
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
    log "Error: Cannot download [$2]" 
    exit 1 
  fi 

  export $1=$($CURL_CMD "$DOWNLOAD_URL")
}

get_secret_via_file()
{
  local SECRET_FILE=$(echo $2|cut -d":" -f2)
  if [ ! -r "$SECRET_FILE" ]; then
    log "File not found [$SECRET_FILE]"
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
  get_secret_var AdminPassword
  get_secret_var ServerPassword
  get_secret_var OrganizationPassword
  get_secret_var OrgUnitPassword
}

check_download_file_links()
{
  # Donwload ID files if they start with http(s):

  download_file_link OrganizationIDFile
  download_file_link OrgUnitIDFile
  download_file_link ServerIDFile
  download_file_link AdminIDFile
  download_file_link SafeIDFile
  download_file_link DominoTrialKeyFile

  download_file_link SetupAutoConfigureParams
  download_file_link DominoPemFile

  return 0
}


# --- Main Logic ---

NOW=$(date)
header "$NOW"

# Switch to data directory for downloads
cd $DOMINO_DATA_PATH 

# If CustomNotesdataZip file downlaod URL defined, download from remote location and unzip 
download_file_link CustomNotesdataZip

# Expand & delete ZIP

if [ -n "$CustomNotesdataZip" ]; then
  if [ -r "$CustomNotesdataZip" ]; then
    log "Extracting custom notesdata file [$CustomNotesdataZip]"

    log "---------------------------------------"
    unzip -o "$CustomNotesdataZip"
    rm -f "$CustomNotesdataZip"
    log "---------------------------------------"
  else
    log "Custom notesdata [$CustomNotesdataZip] not found!"
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

# Ensure trial key is named "trial_account.txt"
if [ -e "$DominoTrialKeyFile" ]; then
  if [ ! "$DominoTrialKeyFile" = "trial_account.txt" ]; then
    secure_move_file "$DominoTrialKeyFile" "trial_account.txt"
  fi
fi

if [ -z "$HostName" ]; then
  if [ -x /usr/bin/hostname ]; then
    export HostName=$(hostname)
  else
    export HostName=$(cat /proc/sys/kernel/hostname)
  fi
fi

# Add notes.ini variables if requested
if [ -n "$Notesini" ]; then
  echo $Notesini >> $DOMINO_DATA_PATH/notes.ini
  
  header "Adding notes.ini Settings"
  echo $Notesini >> $LOG_FILE
  log
fi

log  "SetupAutoConfigureParams: [$SetupAutoConfigureParams]"
echo "SetupAutoConfigureParams: [$SetupAutoConfigureParams]"

cd $DOMINO_DATA_PATH
header "Server start will run Domino Server Auto Setup"

header "Prestart script - Done"
