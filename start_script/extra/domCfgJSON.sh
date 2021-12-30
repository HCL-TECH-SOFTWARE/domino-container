#!/bin/bash

###########################################################################
# Domino One-Touch JSON configuration script                              #
# Version 1.0.0 30.12.2021                                                #
#                                                                         #
# (C) Copyright Daniel Nashed/NashCom 2021                                #
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


# Reads a Domino One-Touch JSON file and replaces variables by prompting for input.
# The resulting file is a ready to use JSON One-Touch file.
# Variable names in JSON config match the variables from Domino One-Touch environment setup.
# If variables are already set in your environment, the input prompt will use those variables.
# The behavior can be customized via domCfgJSON_mode below.

# $1 = JSON template file
# $2 = JSON result file (overwrites existing files)

# ---------------------------------------------

# Existing variable mode:
# By default existing variables are used in input prompt as a preset value

# Enforce variables already defined and do not prompt
#domCfgJSON_mode=force

# Ignore existing values
#domCfgJSON_mode=ignore

# ---------------------------------------------

JSON_TEMPLATE=$1
JSON_CFG=$2

get_config()
{
  local VAR=
  local PROMPT=$(echo $1 |awk -F'SERVERSETUP_' '{print $2}')
  local DEFAULT=${!1}

  if [ -n "$(echo $CHECKED_VAR |grep $1)" ]; then
    return 1
  fi

  if [ -n "$DEFAULT" ]; then
    if [ "$domCfgJSON_mode" = "ignore" ]; then
      DEFAULT=
    fi

    if [ "$domCfgJSON_mode" = "force" ]; then
      return 1
    fi
  fi

  if [ -z "$PROMPT" ]; then
    PROMPT=$1
  fi

  echo
  read -p "$PROMPT: " -e -i "$DEFAULT" VAR
  export $1="$VAR"
  CHECKED_VAR=$CHECKED_VAR:$1
  return 0
}

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

CHECKED_VAR=
SETUP_VARS=$(cat "$JSON_TEMPLATE" | sed 's/{{ /${/g;s/{{/${/g;s/ }}/}/g;s/}}/}/g' | grep '${' | awk -F'[$]{' '{print $2}' | awk -F'}' '{print $1}' | uniq)
for ARG in $SETUP_VARS; do
  get_config "$ARG"
done
CHECKED_VAR=

if [ -z "$JSON_CFG" ]; then
  cat $JSON_TEMPLATE | sed 's/{{ /${/g;s/{{/${/g;s/ }}/}/g;s/}}/}/g' | envsubst
else
  cat $JSON_TEMPLATE | sed 's/{{ /${/g;s/{{/${/g;s/ }}/}/g;s/}}/}/g' | envsubst > $JSON_CFG
fi

