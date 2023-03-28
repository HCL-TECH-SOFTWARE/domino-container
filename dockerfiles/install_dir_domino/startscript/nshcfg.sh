#!/bin/bash

###########################################################################
# Linux configuration JSON based script                                   #
# Version 1.0.0 02.01.2022                                                #
#                                                                         #
# (C) Copyright Daniel Nashed/NashCom 2022                                #
# Feedback domino_unix@nashcom.de                                         #
#                                                                         #
# Licensed under the Apache License, Version 2.0 (the "License");         #
# you may not use this file except in compliance with the License.        #
# You may obtain a copy of the License at                                 #
#                                                                         #
#      http://www.apache.org/licenses/LICENSE-2.0                         #
#                                                                         #
# Unless required by applicable law or agreed to in writing, software     #
# distributed under the License is distributed on an "AS IS" BASIS,       #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.#
# See the License for the specific language governing permissions and     #
# limitations under the License.                                          #
###########################################################################


# This script is mainly designed to deploy Domino One-Touch JSON configurations.
# It is based on a flexible design, it can be also used to deploy other files.
# The script uses a flexible menu structure which is designed to load configurations from https://, http:// and file:/ URLs.
# The menu is explicitly designed to span multiple files e.g. in multiple GitHub repositories.
# It also supports auto detection if no configuration is specified for automated setups.

# Parameters
# ----------

# $1 -> Local target file 
# -----------------------
#
# Local file name to be written.
# Existing files are not overwritten for security reasons.
# In additon the remote site should not be able to specify the file name or directory for security reasons. 


# $2 -> Download URL
# ------------------
#
# The URL can be either https://, http:// or file:/ for a local file
# If no URL is specified, domain name of the current server with the well known URL on HTTPS is assumed

# Example: https://www.acme.com/.well-known/domino.cfg

# $3 -> Index in JSON file 
# ------------------------
#
# Index in JSON file can be optionally configured.
# By default /config is assumed 

# Debug Mode
# nshcfg_debug=yes


# Default config environment file

if [ -z "$DOMINO_AUTO_CFG_DEFAULTS_ENV_FILE" ]; then
  DOMINO_AUTO_CFG_DEFAULTS_ENV_FILE=/local/notesdata/DominoAutoConfigDefault.env
fi


DebugText()
{
  if [ "$nshcfg_debug" = "yes" ]; then
    echo "$(date '+%F %T') Debug:" $@
  fi

  return 0
}

LogError()
{
  echo "ERROR: $@"
}

DownloadFile()
{
  local URL=$1
  local TARGET_FILE=$2

  if [ -z "$URL" ]; then
    LogError "No download URL specified!"
    return 1
  fi

  if [ -z "$TARGET_FILE" ]; then
    TARGET_FILE="$TARGET_CFG_FILE"
  fi

  if [ -z "$TARGET_FILE" ]; then
    LogError "No download target file specified!"
    return 1
  fi

  case $URL in
    /*)
      if [ ! -e "$URL" ]; then
        LogError "Cannot copy file. Local source file does not exist!"
        return 1
      fi

      cp "$URL" "$TARGET_FILE"
      ;;

  esac

  curl -sL "$URL" -o "$TARGET_FILE"
  DebugText "DownloadFile [$URL] -> [$TARGET_FILE]"

  return 0
}

GetConfig()
{
  local N=0
  local KEY=
  local CFG=
  local LINE=
  local INDEX=
  local URL=
  local ONE_TOUCH_ENV=
  local ONE_TOUCH_JSON=
  local DXL=
  local SELECTED=

  if [ -z "$1" ]; then
    return 1
  fi

  JQ_VERSION=$(jq --version 2>/dev/null)

  if [ -z "$JQ_VERSION" ]; then
    LogError "Setup requires JQ!"
    return 1
  fi

  case $1 in
    /*)
      if [ -e "$1" ]; then
        JSON=$(cat $1)
      fi
      ;;

    *)
      JSON=$(curl -sL $1)
      ;;
  esac

  if [ -z "$JSON" ]; then
    LogError "No JSON returned from [$1]!"
    return 1
  fi 

  KEY=$(echo $2 | tr [/] [.])
  CFG=$(echo $JSON | jq $KEY.index.cfg 2>/dev/null) 

  if [ "null" = "$CFG" ]; then
    CFG=$(echo $JSON | jq $KEY.cfg) 

    if [ "null" = "$CFG" ]; then
      LogError "No configruation found!"
      return 1
    fi
  fi

  if [ -z "$CFG" ]; then
    LogError "No configuration or invalid JSON! [$1]"
    return 1
  fi

  SELECT=$(echo $CFG | jq -r ' . | map (.name) | join("\n")')

  echo
  N=0
  while IFS= read -r LINE 
  do
    if [ -n "$LINE" ]; then
      N=$(($N + 1))
      # Don't print lines with one dot only
      if [ "." != "$LINE" ]; then
        echo "[$N] $LINE"
      fi
    fi
  done <<< "$SELECT"

  if [ "$N" = "0" ]; then
    LogError "No configuration found!"
    return 1
  fi

  # Set to one to automatically select if only one entry is in list
  if [ "$N" = "1" ]; then
    SELECTED=1
  else
    echo 
    read -p "Select [1-$N] 0 to cancel? " SELECTED 
    echo 

    if [ "$SELECTED" = "0" ]; then
      return 0
    fi
  fi

  N=0
  while IFS= read -r LINE 
  do
    if [ -n "$LINE" ]; then
      N=$(($N + 1))
      if [ "$N" = "$SELECTED" ]; then
        KEY=$LINE
      fi
    fi
  done <<< "$SELECT"

  # Get config
  URL=$(echo $CFG | jq --arg key "$KEY" -r '.[] | select(.name==$key) | .URL')
  INDEX=$(echo $CFG | jq --arg key "$KEY" -r '.[] | select(.name==$key) | .index')
  ONE_TOUCH_ENV=$(echo $CFG | jq --arg key "$KEY" -r '.[] | select(.name==$key) | .oneTouchENV')
  ONE_TOUCH_JSON=$(echo $CFG | jq --arg key "$KEY" -r '.[] | select(.name==$key) | .oneTouchJSON')
  DXL=$(echo $CFG | jq --arg key "$KEY" -r '.[] | select(.name==$key) | .DXL')

  # Process setup index config
  if [ "null" != "$URL" ] || [ "null" != "$INDEX" ]; then

    if [ "null" = "$URL" ]; then
      URL=
    fi

    if [ "null" = "$INDEX" ]; then
      INDEX=
    fi

    if [ -z "$URL" ]; then
      URL=$1
    fi

    # Ensure to clear previous selection before jumping to sub "menu"
    SELECTED=
    GetConfig "$URL" "$INDEX"
    return 0
  fi

  if [ "null" = "$ONE_TOUCH_JSON" ] ; then
    ONE_TOUCH_JSON=
  fi

  if [ "null" = "$ONE_TOUCH_ENV" ]; then
    ONE_TOUCH_ENV=
  fi

  if [ "null" = "$DXL" ]; then
    DXL=
  fi

  # Allow to download multiple files and only log errors if none is found

  local FOUND=

  if [ -n "$ONE_TOUCH_JSON" ] ; then
    DownloadFile "$ONE_TOUCH_JSON"
    FOUND=1
  fi

  if [ -n "$ONE_TOUCH_ENV" ]; then

    # In case a JSON was already found, an environment file is a defaults file with a fixed name
    if [ -z "$FOUND" ]; then
      DownloadFile "$ONE_TOUCH_ENV"
      FOUND=1
    else
      DownloadFile "$ONE_TOUCH_ENV" "$DOMINO_AUTO_CFG_DEFAULTS_ENV_FILE"
    fi
  fi

  if [ -n "$DXL" ]; then
    DownloadFile "$DXL"
    FOUND=1
  fi

  if [ -z "$FOUND" ]; then
    LogError "No configuration option found [$SELECTED]"
    return 1
  fi

  return 0
}

DownloadConfig()
{
  TARGET_CFG_FILE=$1

  local URL=$2
  local INDEX=$3
  local DOMAIN=

  # For security reasons a target file cannot be assumed!
  if [ -z "$TARGET_CFG_FILE" ]; then
    LogError "No target file specified!"
    return 1
  fi

  # For security reasons, never overwrite files!
  if [ -e "$TARGET_CFG_FILE" ]; then
    LogError "Target file already exists! [$TARGET_CFG_FILE]"
    return 1
  fi

  # Dot is a placeholder for an empty hostname
  if [ "." = "$URL" ]; then
    URL=
  fi

  # Use server's domain for target URL, if not specified
  if [ -z "$URL" ]; then
    DOMAIN=$(hostname -d)
    if [ -n "$DOMAIN" ]; then
      URL=https://$DOMAIN/.well-known/domino.cfg
    fi
  fi

  if [ -z "$URL" ]; then
    LogError "No URL specified!"
    return 1
  fi

  # Assume well known config if no known file extension is specified
  case $URL in
    *.cfg)
      ;;

    *.json)
      ;;

    *.txt)
      ;;

    *)
      URL=$URL/.well-known/domino.cfg 
      ;;
  esac

  # Set protocol to https:// if not specified
  case $URL in
    http://*)
      ;;

    https://*)
      ;;

    file:/*)
      ;;

    /*)
      ;;

    *)
      URL=https://$URL
      ;;
  esac

  # Set index to /index if not specified
  if [ -n "$INDEX" ]; then
    case $INDEX in
      /*)
        ;;
      *)
       INDEX=/$INDEX 
       ;;
    esac
  fi

  echo "Getting configuration from $URL $INDEX"

  GetConfig "$URL" "$INDEX" 
}

DownloadConfig "$@"

