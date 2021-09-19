

check_json_file()
{
  local ONE-TOUCH_JSON_SCHEMA=/opt/hcl/domino/notes/latest/linux/dominoOneTouchSetup.schema.json


  if [ ! -e /usr/bin/jq ]; then
    echo "warning: No jq tool installed"
    return 0
  fi

  if [ -z "$1" ]; then
    echo "No JSON file specified"
    return 1
  fi

  if [ ! -e "$1" ]; then
    echo "JSON file does not exist!"
    return 1
  fi

  cat $1 | jq -e . >/dev/null 2>&1 
  JSON_STATUS=$?

  if [ ! "$JSON_STATUS" = "0" ]; then
    echo "Invalid JSON format!"
    return 1
  fi
  
  SERVER_TYPE=$(cat $1 | jq .serverSetup.server.type)
  echo "$SERVER_TYPE"

  return 0
}

check_json_file additional_server.json
