#!/bin/bash

###########################################################################
# Domino One-Touch JSON configuration script                              #
# Version 1.1.0 14.03.2022                                                #
#                                                                         #
# (C) Copyright Daniel Nashed/NashCom 2021-2022                           #
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


# Downloads and edits JSON configuration files.
# Reads a Domino One-Touch JSON file and replaces variables by prompting for input.
# The resulting file is a ready to use JSON One-Touch file.
# Variable names in JSON config match the variables from Domino One-Touch environment setup.
# If variables are already set in your environment, the input prompt will use those variables.
# The behavior can be customized via domCfgJSON_mode below.

# ---------------------------------------------

# Existing variable mode:
# By default existing variables are used in input prompt as a preset value

# Enforce variables already defined and do not prompt
#domCfgJSON_mode=force

# Ignore existing values
#domCfgJSON_mode=ignore

# Debug Mode
#domCfgJSON_debug=yes

# Default config environment file

if [ -z "$DOMINO_AUTO_CFG_DEFAULTS_ENV_FILE" ]; then
  DOMINO_AUTO_CFG_DEFAULTS_ENV_FILE=/local/notesdata/DominoAutoConfigDefault.env
fi

# ---------------------------------------------

DebugText()
{
  if [ "$domCfgJSON_debug" = "yes" ]; then
    echo "$(date '+%F %T') Debug:" $@
  fi

  return 0
}


check_json_file()
{
  local ONE_TOUCH_JSON_SCHEMA=dominoOneTouchSetup.schema.json
  local ONE_TOUCH_JSON_SCHEMA_FULL=
  local VALIDJSON_BIN=

  if [ -z "$1" ]; then
    echo "No OneTouch setup JSON file specified!"
    return 1
  fi

  if [ ! -e "$1" ]; then
    echo "OneTouch setup JSON file does not exist!"
    return 1
  fi

  JQ_VERSION=$(jq --version 2>/dev/null)

  if [ -z "$JQ_VERSION" ]; then
    echo "Warning: No jq tool installed"
  else
    # Don't show JSON but show error log
    cat $1 | jq -e . >/dev/null
    JSON_STATUS=$?

    if [ ! "$JSON_STATUS" = "0" ]; then
      echo
      echo "Error OneTouch setup file Invalid JSON format!"
      return 1
    fi

    SERVER_TYPE=$(cat $1 | jq -r .serverSetup.server.type)

    case $SERVER_TYPE in
      first|additional)
        ;;

      *)
        echo "Invalid server type [$SERVER_TYPE]!"
        return 1
        ;;
    esac
  fi

  # If available use the stand-alone tool, which does not need Domino code installed and no switch to the notes user
  if [ -x "/opt/nashcom/startscript/checkjson" ]; then
    CHECKJSON_BIN="/opt/nashcom/startscript/checkjson"

  elif [ -x "$LOTUS/bin/validjson" ]; then
    VALIDJSON_BIN="$LOTUS/bin/validjson"

  elif [ -x "$Notes_ExecDirectory/validjson" ]; then
    VALIDJSON_BIN="$Notes_ExecDirectory/validjson"

  else
    VALIDJSON_BIN=
  fi

  if [ -n "$CHECKJSON_BIN" ]; then

    echo
    print_delim
    echo "One-Touch Domino Validation (via checkjson)"
    print_delim
    echo

    if [ -e "/opt/hcl/domino/notes/latest/linux/$ONE_TOUCH_JSON_SCHEMA" ]; then
      ONE_TOUCH_JSON_SCHEMA_FULL=/opt/hcl/domino/notes/latest/linux/$ONE_TOUCH_JSON_SCHEMA

    elif [ -e "/opt/nashcom/startscript/OneTouchSetup/$ONE_TOUCH_JSON_SCHEMA" ]; then
      ONE_TOUCH_JSON_SCHEMA_FULL=/opt/nashcom/startscript/OneTouchSetup/$ONE_TOUCH_JSON_SCHEMA
    fi

    $CHECKJSON_BIN "$1" "$ONE_TOUCH_JSON_SCHEMA_FULL"

  elif [ -n "$VALIDJSON_BIN" ]; then

    # The original Domino validjson requires Domino to be setup correctly

    # Save existing lib path
    local SAVED_LD_LIBRARY_PATH="$LD_LIBRARY_PATH"

    # Ensure we can load Notes libs
    export LD_LIBRARY_PATH="$Notes_ExecDirectory"

    # For now copy the schema to data diretory, because validjson expects it in the current directoy

    if [ -e "$Notes_ExecDirectory/$ONE_TOUCH_JSON_SCHEMA" ]; then
      cp -f "$Notes_ExecDirectory/$ONE_TOUCH_JSON_SCHEMA" "$DOMINO_DATA_PATH"
    fi

    local SAVED_PWD="$(pwd)"
    cd "$DOMINO_DATA_PATH"

    echo
    print_delim
    echo "One-Touch Domino Validation"
    print_delim
    echo

    # Always run validation with the Notes user
    if [ "$LOGNAME" = "$DOMINO_USER" ]; then
      $VALIDJSON_BIN $1 -default

    else
      su $DOMINO_USER -c "$VALIDJSON_BIN $1 -default"
    fi

    print_delim

    # Restore existing env
    cd "$SAVED_PWD"
    export LD_LIBRARY_PATH="$SAVED_LD_LIBRARY_PATH"
  fi

  return 0
}


GetConfig()
{
  local VAR=
  local DEFAULT=
  local VAR_NAME=$1
  local PROMPT=$(echo $1 |awk -F'SERVERSETUP_' '{print $2}')
  local VAR=
  local DEFAULT=

  if [ -n "$(echo $CHECKED_VAR |grep $VAR_NAME)" ]; then
    return 1
  fi

  DEFAULT=${!VAR_NAME}

  if [ -n "$DEFAULT" ]; then
    if [ "$domCfgJSON_mode" = "ignore" ]; then
      DEFAULT=
    fi

    if [ "$domCfgJSON_mode" = "force" ]; then
      return 1
    fi
  fi

  if [ -z "$PROMPT" ]; then
    PROMPT=$VAR_NAME
  fi

  echo
  read -p "$PROMPT: " -e -i "$DEFAULT" VAR
  CHECKED_VAR=$CHECKED_VAR:$VAR_NAME
  export $1="$VAR"
  return 0
}


ConfigJSON()
{
  # $1 = JSON template file
  # $2 = JSON result file (overwrites existing files)

  local JSON_TEMPLATE=$1
  local JSON_CFG=$2

  if [ -z "$JSON_TEMPLATE" ]; then
    echo "No template file specified!"
    exit 1
  fi

  if [ ! -e "$JSON_TEMPLATE" ]; then
    echo "Template file does not exist: [$JSON_TEMPLATE]"
    exit 1
  fi

  if [ ! -r "$JSON_TEMPLATE" ]; then
    echo "Cannot read template file: [$JSON_TEMPLATE]"
    exit 1
  fi

  # If exists source in environment setup file for defaults
  if [ -n "$DOMINO_AUTO_CFG_DEFAULTS_ENV_FILE" ]; then
    if [ -e "$DOMINO_AUTO_CFG_DEFAULTS_ENV_FILE" ]; then
      . "$DOMINO_AUTO_CFG_DEFAULTS_ENV_FILE"
    fi
  fi

  CHECKED_VAR=
  SETUP_VARS=$(cat "$JSON_TEMPLATE" | sed 's/{{ /${/g;s/{{/${/g;s/ }}/}/g;s/}}/}/g' | grep '${' | awk -F'[$]{' '{print $2}' | awk -F'}' '{print $1}')

  for ARG in $SETUP_VARS; do
    GetConfig "$ARG"
  done

  CHECKED_VAR=

  if [ -z "$JSON_CFG" ]; then
  cat $JSON_TEMPLATE | sed 's/{{ /${/g;s/{{/${/g;s/ }}/}/g;s/}}/}/g' | envsubst
  else
    cat $JSON_TEMPLATE | sed 's/{{ /${/g;s/{{/${/g;s/ }}/}/g;s/}}/}/g' | envsubst > $JSON_CFG
  fi
}


EditOneTouchSetup()
{
  local CFG_FILE=
  local CFG_TEMPLATE=
  local TEMPLATE_DIR=/opt/nashcom/startscript/OneTouchSetup

  if [ -z "$DOMINO_AUTO_CONFIG_ENV_FILE" ]; then
     DOMINO_AUTO_CONFIG_ENV_FILE=$DOMINO_DATA_PATH/DominoAutoConfig.env
  fi

  if [ -z "$DOMINO_AUTO_CONFIG_JSON_FILE" ]; then
    DOMINO_AUTO_CONFIG_JSON_FILE=$DOMINO_DATA_PATH/DominoAutoConfig.json
  fi

  if [ "$1" = "log" ]; then

     local ONE_TOUCH_LOG=$DOMINO_DATA_PATH/IBM_TECHNICAL_SUPPORT/autoconfigure.log

     if [ ! -e "$ONE_TOUCH_LOG" ]; then
       echo "No One Touch setup log found [$ONE_TOUCH_LOG]"
       return 0
     fi

    if [ "$2" = "edit" ]; then
      $EDIT_COMMAND $ONE_TOUCH_LOG
    else
      echo "---------- autoconfigure.log ----------"
      cat $ONE_TOUCH_LOG
      echo "---------- autoconfigure.log ----------"
    fi

    return 0
  fi

  # Template name will be only set when creating or overwriting configuration

  if [ "$1" = "env" ]; then
     CFG_FILE=$DOMINO_AUTO_CONFIG_ENV_FILE

     if [ "$2" = "1" ]; then
       CFG_TEMPLATE=$TEMPLATE_DIR/first_server.env

     elif [ "$2" = "2" ]; then
       CFG_TEMPLATE=$TEMPLATE_DIR/additional_server.env

     else
       if [ ! -e "$CFG_FILE" ]; then
         CFG_TEMPLATE=$TEMPLATE_DIR/first_server.env
       fi
     fi

    # Remove JSON file when switching to ENV config
    if [ -n "$CFG_TEMPLATE" ]; then
      remove_file "$DOMINO_AUTO_CONFIG_JSON_FILE"
    fi

  fi

  if [ "$1" = "json" ]; then
    CFG_FILE=$DOMINO_AUTO_CONFIG_JSON_FILE

    if [ "$2" = "1" ]; then
      CFG_TEMPLATE=$TEMPLATE_DIR/first_server.json
    elif [ "$2" = "2" ]; then
      CFG_TEMPLATE=$TEMPLATE_DIR/additional_server.json
    else
      if [ ! -e "$CFG_FILE" ]; then
        CFG_TEMPLATE=$TEMPLATE_DIR/first_server.json
      fi
    fi

    # Remove ENV file when switching to JSON config
    if [ -n "$CFG_TEMPLATE" ]; then
      remove_file "$DOMINO_AUTO_CONFIG_ENV_FILE"
    fi

  fi

  # Check for remote configuration options
  local CFG_URL=
  local CFG_INDEX=
  local OPTION=$1

  if [ -z "$OPTION" ]; then
    if [ ! -e "$DOMINO_AUTO_CONFIG_JSON_FILE" ]; then
      OPTION=local
    fi
  fi

  case $OPTION in
    http://*)
      CFG_URL=$1
      CFG_INDEX=$2
      ;;

    https://*)
      CFG_URL=$1
      CFG_INDEX=$2
      ;;

    file:/*)
      CFG_URL=$1
      CFG_INDEX=$2
      ;;

    /*)
      CFG_URL=$1
      CFG_INDEX=$2
      ;;

    auto|remote)
      CFG_URL=$2
      CFG_INDEX=$3
      if [ -z "$CFG_URL" ]; then
        CFG_URL=.
      fi
      ;;

    local)
      if [ -e /etc/sysconfig/domino.cfg ]; then
        CFG_URL=/etc/sysconfig/domino.cfg
        CFG_INDEX=$2
      fi
      ;;

    github)
      CFG_URL=https://raw.githubusercontent.com/nashcom/domino-startscript/main/domino.cfg
      CFG_INDEX=$2
      ;;

  esac

  # Automatic setup checking for remote configurations
  if [ -n "$CFG_URL" ]; then
    CFG_FILE=$DOMINO_AUTO_CONFIG_JSON_FILE
    CFG_TEMPLATE=$CFG_FILE.template

    # Remove existing template first
    if [ -e "$CFG_TEMPLATE" ]; then
      rm -f "$CFG_TEMPLATE"
    fi

    # For JSON files use direct download
    case "$CFG_URL" in

      *.json)
        DebugText "JSON direct download: [$CFG_URL] -> [$CFG_TEMPLATE]"
        curl -sL "$CFG_URL" -o "$CFG_TEMPLATE"
        ;;

      *)
        DebugText "nshcfg.sh [$CFG_URL/$CFG_INDEX] -> [$CFG_TEMPLATE]"
        $SCRIPT_DIR_NAME/nshcfg.sh "$CFG_TEMPLATE" "$CFG_URL" "$CFG_INDEX"
        ;;

    esac

    # If template found, convert template to config
    if [ -e "$CFG_TEMPLATE" ]; then

      ConfigJSON "$CFG_TEMPLATE" "$CFG_FILE"
      rm -f "$CFG_TEMPLATE"
    fi

    # Finally we have to have a config file
    if [ ! -e "$CFG_FILE" ]; then
      echo "No JSON configuration found"
      return 1
    fi

    check_json_file "$CFG_FILE"

    return 0
  fi

  # Edit existing file or create a new first server env
  if [ -z "$1" ]; then
    if [ -e "$DOMINO_AUTO_CONFIG_JSON_FILE" ]; then
      CFG_FILE=$DOMINO_AUTO_CONFIG_JSON_FILE

    elif [ -e "$DOMINO_AUTO_CONFIG_ENV_FILE" ]; then
      CFG_FILE=$DOMINO_AUTO_CONFIG_ENV_FILE

    else
      CFG_FILE=$DOMINO_AUTO_CONFIG_JSON_FILE
      CFG_TEMPLATE=$TEMPLATE_DIR/first_server.json
    fi
  fi

  if [ -z "$CFG_FILE" ]; then
    echo "Invalid setup option specified"
    return 1
  fi

  # Create config file from template if requested
  if [ -n "$CFG_TEMPLATE" ]; then

    case "$CFG_FILE" in
      *.json|*.JSON)
       ConfigJSON "$CFG_TEMPLATE" "$CFG_FILE"
        check_json_file "$CFG_FILE"
        return 0
        ;;

      *)
        echo "Creating [$CFG_FILE] from [$CFG_TEMPLATE]"
        cp -f "$CFG_TEMPLATE" "$CFG_FILE"
        ;;
    esac
  fi

  # Finally edit existing or new file
  $EDIT_COMMAND "$CFG_FILE"

  case "$CFG_FILE" in
    *.json|*.JSON)
      check_json_file "$CFG_FILE"
      ;;
  esac
}


# Edit command
if [ -z "$EDIT_COMMAND" ]; then
  export EDIT_COMMAND="vi"
fi

# Ensure Domino Data path is set
if [ -z "$DOMINO_DATA_PATH" ]; then
  export DOMINO_DATA_PATH="/local/notesdata"
fi

# Ensure Domino binary path is set
if [ -z "$LOTUS" ]; then
  export LOTUS="/opt/hcl/domino"
  export Notes_ExecDirectory="$LOTUS/notes/latest/linux"
fi

# Ensure Domino user is set
if [ -z "$DOMINO_USER" ]; then
  export DOMINO_USER=notes
fi

EditOneTouchSetup "$@"
