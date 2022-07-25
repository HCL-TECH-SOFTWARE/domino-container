
###########################################################################
# Automation Test Script Lib                                              #
# --------------------------                                              #
# Version 1.0.0 25.07.2022                                                #
#                                                                         #
# This script implements automation helper functionality                  #
#                                                                         #
# (C) Copyright Daniel Nashed/NashCom 2022                                #
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

log()
{
  echo "$@"
}

log_debug()
{
  if [ -z "$AUTO_TEST_DEBUG" ]; then
    return 0
  fi

  echo "$@"
}

# The following JSON routines are not intened for general purpose use.
# They are implemented for the limited scope used for JSON testing output.

jsonOut()
{

  if [ -z "$RESULT_FILE_JSON" ]; then
    printf "$@"
  else
    printf "$@" >> "$RESULT_FILE_JSON"
  fi
}

log_json()
{
  if [ -n "$JSON_HAS_ELEMENT" ]; then
    jsonOut ","
  fi

  jsonOut "\"$1\":\""
  jsonOut "$2" | sed 's/\\/\\\\/g;s/\t/\\t/g;s/"/\\"/g'
  jsonOut "\""

  JSON_HAS_ELEMENT=1
}

log_json_nq()
{
  jsonOut "\"$1\":$2$3"
}

log_json_begin()
{
  if [ -n "$JSON_HAS_ELEMENT" ]; then
    jsonOut ","
  fi

  if [ -n "$1" ]; then 
    jsonOut "\"$1\" :"
  fi
  jsonOut "{"

  JSON_HAS_ELEMENT=
}

log_json_end()
{
  jsonOut "}"
}

log_json_begin_array()
{
  if [ -n "$JSON_HAS_ELEMENT" ]; then
    jsonOut ","
  fi

  if [ -n "$1" ]; then 
    jsonOut "\"$1\" :"
  fi
  jsonOut "["

  JSON_HAS_ELEMENT=
  JSON_HAS_ARRAY_ELEMENT=
}

log_json_end_array()
{
  jsonOut "]"
}

log_json_begin_array_element()
{
  if [ -n "$JSON_HAS_ARRAY_ELEMENT" ]; then
    jsonOut ","
  fi

  jsonOut "{"

  JSON_HAS_ELEMENT=
  JSON_HAS_ARRAY_ELEMENT=1
}

log_json_end_array_element()
{
  jsonOut "}"
}

reset_results()
{
  count_success=0
  count_error=0
  count_total=0

  printf "" > $RESULT_FILE_JSON
  printf "" > $RESULT_FILE_CSV
}

test_result()
{
  local STATUS=$3

  # If no status is set, derive status from error text (no error test = SUCCESS)

  if [ -z "$STATUS" ]; then
    if [ -z "$4" ]; then
      STATUS="SUCCESS"
    else
      STATUS="ERROR"
    fi
  fi

  log_json_begin_array_element
  log_json name "$1"
  log_json description "$2"
  log_json executionResult "$STATUS"
  log_json errorText "$4"
  log_json_end_array_element

  if [ -n "$RESULT_FILE_CSV" ];then
    printf "$1|$2|$STATUS|$4\n" >> "$RESULT_FILE_CSV"
  fi

   if [ "$STATUS" = "SUCCESS" ]; then
     count_success=$(expr $count_success + 1)
   else
     count_error=$(expr $count_error + 1)
   fi

  count_total=$(expr $count_total + 1)

}

show_results()
{
  header "Test Results JSON"
  cat $RESULT_FILE_JSON | jq

  header "Test Results"

  while IFS= read -r LINE
  do
    NAME=$(echo "$LINE" | cut -d"|" -f 1)
    DESCRIPTION=$(echo "$LINE" | cut -d"|" -f 2)
    RESULT=$(echo "$LINE" | cut -d"|" -f 3)
    ERROR_TEXT=$(echo "$LINE" | cut -d"|" -f 4)

    printf "[ %-7s ]  %s\n" "$RESULT" "$NAME"

  done < $RESULT_FILE_CSV

  printf "\n"
  print_delim
  printf "\n"

  printf "Success : %3d\n" $count_success
  printf "Error   : %3d\n" $count_error
  printf "Total   : %3d\n" $count_total
  printf "\n\n"

  if [ "$count_error" != "0" ]; then
    exit 1
  fi
}

log_error()
{
  echo
  echo "$@"
  echo
}

print_delim ()
{
  echo "--------------------------------------------------------------------------------"
}

header()
{
  echo
  print_delim
  echo " $@"
  print_delim
  echo
}

remove_file()
{
  if [ -z "$1" ]; then
    return 0
  fi 

  if [ -e "$1" ]; then

    if [ -d "$1" ]; then
      echo "Error - requested file delete on folder!"
      return 1
    fi
    rm -f "$1"
  fi
}

remove_dir()
{
  if [ -z "$1" ]; then
    return 0
  fi

  if [ -d "$1" ]; then
    rm -rf "$1"
    return 0
  fi

  if [ -e "$1" ]; then
    echo "Error - requested folder delete on file!"
    return 1
  fi
}

wait_for_string()
{
  local MAX_SECONDS=
  local FOUND=
  local COUNT=$4
  local seconds=0

  if [ -z "$1" ]; then
    return 0
  fi

  if [ -z "$2" ]; then
    return 0
  fi

  if [ -z "$3" ]; then
    MAX_SECONDS=10
  else
    MAX_SECONDS=$3
  fi
  
  if [ -z "$4" ]; then
    COUNT=1
  fi 

  log
  log "Waiting for [$2] in [$1] (max: $MAX_SECONDS sec)"

  while [ "$seconds" -lt "$MAX_SECONDS" ]; do

    FOUND=`grep -e "$2" "$1" 2>/dev/null | wc -l`

    if [ "$FOUND" -ge "$COUNT" ]; then
      return 1
    fi
  
    sleep 2 
    seconds=`expr $seconds + 2`
    if [ `expr $seconds % 10` -eq 0 ]; then
      echo " ... waiting $seconds seconds"
    fi

  done

  return 0
}

container_cmd()
{
  log 
  log "Container Command: $@"
  $CONTAINER_CMD exec -w /local/notesdata $CONTAINER_NAME bash -c "$@"
}

container_cmd_root()
{
  log 
  log "Container Command: $@"
  $CONTAINER_CMD exec -w /local/notesdata $CONTAINER_NAME -u 0 bash -c "$@"
}

server_console_cmd()
{
  log
  log "Server Command: $@"
  $CONTAINER_CMD exec -w /local/notesdata $CONTAINER_NAME sh -c "/opt/hcl/domino/bin/server -c '$@'"
}

startscript_cmd()
{
  log
  log "Server Command: $@"
  $CONTAINER_CMD exec -w /local/notesdata $CONTAINER_NAME sh -c "domino $@"
}

startscript_cmd_it()
{
  log
  log "Server Command: $@"
  $CONTAINER_CMD exec -it -w /local/notesdata $CONTAINER_NAME sh -c "domino '$@'"
}

print_runtime()
{
  hours=$((SECONDS / 3600))
  seconds=$((SECONDS % 3600))
  minutes=$((seconds / 60))
  seconds=$((seconds % 60))
  h=""; m=""; s=""
  if [ ! $hours = "1" ] ; then h="s"; fi
  if [ ! $minutes = "1" ] ; then m="s"; fi
  if [ ! $seconds = "1" ] ; then s="s"; fi
  if [ ! $hours = 0 ] ; then echo "Completed in $hours hour$h, $minutes minute$m and $seconds second$s"
  elif [ ! $minutes = 0 ] ; then echo "Completed in $minutes minute$m and $seconds second$s"
  else echo "Completed in $seconds second$s"; fi
}

create_dir()
{
  if [ -z "$1" ]; then
    return 0
  fi

  if [ -e "$1" ]; then
    return 0
  else
    mkdir -p "$1"
    if [ -w "$1" ]; then

      # set permissions if requested
      if [ -n "$2" ]; then
        chmod -R "$2" "$1"
      fi

      echo "Successfully created ($1)"
      return 0
    else
      echo "Error creating ($1)"
      return 1
    fi
  fi

  return 0
}

