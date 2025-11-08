#!/bin/bash
###########################################################################
# Domino OTS Setup Helper Script                                          #
#                                                                         #
# Version 0.9.2  08.01.2025                                               #
# (C) Copyright Daniel Nashed/NashCom 2025                                #
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

# Functionality

# - Provides a web UI to setup a first server
# - Supports to pass a first/additional server Domino OTS JSON file
# - Also supports uploading a OTS with a single POST to /ots
# - Creates a TLS certificate if no certificate is provided
# - Requires OpenSSL command line
# - Supports the "@Base64:" format to provide a server.id via OTS JSON
# - Supports Basic & Bearer authentication

# Example how to post an OTS JSON file

# curl -v -k -X POST https://localhost/ots -H "Content-Type: application/json" --data-binary @ots.json
# curl -v -k -X POST https://localhost/ots -F "file=@ots.json;type=application/json"

DOMSETUP_VERSION="0.9.2"
SCRIPT_NAME=$0
SCRIPT_DIR=$(dirname $SCRIPT_NAME)

# Variables
# -------------------
# DOMSETUP_HOST           Host name to use for setup (default: hostname machine)
# DOMSETUP_HTTPS_PORT     HTTPS port to use for setup (default: 443)
# DOMSETUP_USER           Setup user name (default: admin)
# DOMSETUP_PASSWORD       Password for setup user
# DOMSETUP_BEARER         Setup Bearer token instead of user password
# DOMSETUP_CERT_FILE      TLS Certificate file name (default: /tmp/domsetup-cert.pem)
# DOMSETUP_KEY_FILE       TLS Key file name (default: /tmp/domsetup-key.pem)
# DOMSETUP_KEY_FILE_PWD   TLS Key password file name (default: /tmp/domsetup-password.txt)
# DOMSETUP_CERTMGR_HOST   Domino CertMgr host name to retieve a certificate matching the current key for host name
# DOMSETUP_JSON_FILE      OTS JSON file to write (default: $DOMINO_AUTO_CONFIG_JSON_FILE)
# DOMSETUP_DOMINO_REDIR   Redirect URL after setup (default: /verse)
# DOMSETUP_WEBROOT        Web root to use (default: script directory + /domsetup-webroot)


if [ -z "$DOMSETUP_USER" ]; then
  DOMSETUP_USER=admin
fi


log()
{
  echo "$@" >> "$DOMSETUP_LOGFILE"
}


log_space()
{
  log
  log "$@"
  log
}



log_stderr()
{
  echo "$@" >&2
}


log_space_stderr()
{
  echo >&2
  echo "$@" >&2
  echo >&2
}


log_error()
{
  log_space "ERROR: $@"
}


delim()
{
  log  "------------------------------------------------------------"
}


header()
{
  log
  delim
  log $@
  delim
  log
}


clear_log()
{
  echo -n > "$DOMSETUP_LOGFILE"
}


remove_file()
{
  if [ -z "$1" ]; then
    return 1
  fi

  if [ ! -e "$1" ]; then
    return 2
  fi

  rm -f "$1"
  return 0
}


cleanup_and_terminate()
{
  trap - EXIT

  if [ -z "$OPENSSL_PID" ]; then
    return 0
  fi

  { exec {OPENSSL[0]}>&-; } 2>/dev/null || true
  { exec {OPENSSL[1]}<&-; } 2>/dev/null || true
  
  if [ -n "$OPENSSL_PID" ] && kill -0 "$OPENSSL_PID" 2>/dev/null; then
    log "Terminating OpenSSL PID $OPENSSL_PID ..."
    kill -TERM "$OPENSSL_PID" 2>/dev/null || true
    sleep 1

    if [ -n "$OPENSSL_PID" ]; then
      log "Killing OpenSSL PID [$OPENSSL_PID] ..."
      kill -KILL "$OPENSSL_PID" 2>/dev/null || true
    fi
  fi

  # Remove temporary key & cert
  remove_file "$DOMSETUP_TEMP_KEY"
  remove_file "$DOMSETUP_TEMP_CERT"

  exit 0
}


show_cert()
{
  if [ -z "$1" ]; then
    return 0
  fi

  if [ ! -e "$1" ]; then
    return 0
  fi

  local SAN=$(openssl x509 -in "$1" -noout -ext subjectAltName | grep "DNS:" | xargs )
  local SUBJECT=$(openssl x509 -in "$1" -noout -subject | cut -d '=' -f 2- )
  local ISSUER=$(openssl x509 -in "$1" -noout -issuer | cut -d '=' -f 2- )
  local EXPIRATION=$(openssl x509 -in "$1" -noout -enddate | cut -d '=' -f 2- )
  local FINGERPRINT=$(openssl x509 -in "$1" -noout -fingerprint | cut -d '=' -f 2- )
  local SERIAL=$(openssl x509 -in "$1" -noout -serial | cut -d '=' -f 2- )

  header "Certificate [$1]"
  log "SAN         : $SAN"
  log "Subject     : $SUBJECT"
  log "Issuer      : $ISSUER"
  log "Expiration  : $EXPIRATION"
  log "Fingerprint : $FINGERPRINT"
  log "Serial      : $SERIAL"
  log
}


get_json_value()
{
  echo "$1" | sed -n "s/.*\"$2\": *\"\([^\"]*\)\".*/\1/p"
}


replace_str()
{
  echo "$1" | sed "s|$2|$3|g"
}


get_value_after_prefix()
{
  echo "$1" | awk -F"$2" 'NF > 1 { print $2 }'
}


ots_read_replace_server_id_base64()
{
  local SERVER_ID_FILEPATH="$DOMINO_DATA_PATH/server.id"
  local ELEMENT_VALUE=$(get_json_value "$1" "IDFilePath")

  if [ -z "$ELEMENT_VALUE" ]; then
    echo "$1"
    return 0
  fi

  local BASE64DATA=$(get_value_after_prefix "$ELEMENT_VALUE" "@Base64:")

  if [ -z "$BASE64DATA" ]; then
    echo "$1"
    return 0
  fi

  echo "$BASE64DATA" | base64 -d > "$SERVER_ID_FILEPATH"
  replace_str "$1" "$ELEMENT_VALUE" "$SERVER_ID_FILEPATH"

  log_space "Retrieved server.id from OTS JSON: $SERVER_ID_FILEPATH"
  return 1
}


send_http_response()
{
  local HTTP_STATUS="$1"
  local REASON="$2"
  local CONTENT_TYPE="$3"
  local BODY="$4"
  local CONTENT_LEN=${#BODY}

  if [ -z "$CONTENT_TYPE" ]; then
    CONTENT_TYPE="text/plain"
  fi

  printf 'HTTP/1.1 %s %s\r\nServer: domsetup\r\nContent-Type: %s\r\nContent-Length: %s\r\nConnection: close\r\n\r\n' "$HTTP_STATUS" "$REASON" "$CONTENT_TYPE" "$CONTENT_LEN" >&${OPENSSL[1]}
  if [ -n "$BODY" ]; then
    printf '%s' "$BODY" >&${OPENSSL[1]}
  fi
}


send_http_unauthorized()
{
  local HTTP_STATUS=401
  local REASON="Unauthorized"
  local CONTENT_TYPE="text/plain"
  local BODY="Unauthorized"
  local CONTENT_LEN=${#BODY}
  local REALM=$1

  if [ -z "$REALM" ]; then
    REALM="Domino Setup"
  fi

  printf 'HTTP/1.1 %s %s\r\nServer: domsetup\r\nContent-Type: %s\r\nWWW-Authenticate: Basic realm=\"$REALM\"\r\nContent-Length: %s\r\nConnection: close\r\n\r\n' "$HTTP_STATUS" "$REASON" "$CONTENT_TYPE" "$CONTENT_LEN" >&${OPENSSL[1]}
  if [ -n "$BODY" ]; then
    printf '%s' "$BODY" >&${OPENSSL[1]}
  fi
}


send_http_redirect()
{
  local LOCATION=$1
  local HTTP_STATUS=$2
  local REASON="Found"
  local CONTENT_LEN=0

  if [ -z "$HTTP_STATUS" ]; then
    HTTP_STATUS=302
  fi

  case "$HTTP_STATUS" in
    302) REASON="Found" ;;
    303) REASON="See Other" ;;
    307) REASON="Temporary Redirect" ;;
    308) REASON="Permanent Redirect" ;;
  esac

  log "Sending redirect [$HTTP_STATUS] [$REASON] -> [$LOCATION]"
  printf 'HTTP/1.1 %s %s\r\nServer: domsetup\r\nLocation: %s\r\nContent-Length: %s\r\nConnection: close\r\n\r\n' "$HTTP_STATUS" "$REASON" "$LOCATION" "$CONTENT_LEN" >&${OPENSSL[1]}
}


process_get_request()
{
  local HTTP_STATUS=200
  local REASON=OK
  local CONTENT_TYPE=text/plain
  local CONTENT_LEN=0
  local FILE_NAME=

  log "GET: [$1]"

  if [ "/" = "$1" ]; then
    FILE_NAME="$DOMSETUP_WEBROOT/index.html"
  else
    FILE_NAME="$DOMSETUP_WEBROOT$(echo $1 | cut -f1 -d'?')"
  fi

  # Always allow to check if setup is available
  if [ "/status" = "$1" ]; then
    log "Status request received"

    if [ "$DOMSETUP_NOGUI" = "1" ]; then
      send_http_response 202 "Ready.POST" "" "Ready for receiving OTS file via POST request"
    else
      send_http_response 202 "Ready.GUI" "" "Ready for GUI Setup"
    fi
    return 0
  fi

  if [ "$DOMSETUP_NOGUI" = "1" ]; then
    log "GUI mode disabled: [$FILE_NAME]"
    send_http_response 404 "Not Found"
    return 0
  fi

  if [ ! -f "$FILE_NAME" ]; then
    log "File not found: [$FILE_NAME]"
    send_http_response 404 "Not Found"
    return 0
  fi

  local CANON_ROOT=$(realpath -m "$DOMSETUP_WEBROOT")
  local CANON_FILE=$(realpath -m "$FILE_NAME")

  case "$CANON_FILE" in
    "$CANON_ROOT"/*) ;;
    "$CANON_ROOT") ;;

    *)
      HTTP_STATUS=403
      REASON="Forbidden"
      log "Access outside webroot blocked: $CANON_FILE"
      respond_error
      return
      ;;
  esac

  CONTENT_LEN=$(stat -c %s -- "$FILE_NAME")

  if [ "$CONTENT_LEN" = "0" ]; then
    log "File is empty: [$FILE_NAME]"
    send_http_response 404 "Not Found"
    return 0
  fi

  case "${FILE_NAME,,}" in
    *.html|*.htm)  CONTENT_TYPE="text/html" ;;
    *.txt|*.log)   CONTENT_TYPE="text/plain" ;;
    *.css)         CONTENT_TYPE="text/css" ;;
    *.js)          CONTENT_TYPE="application/javascript" ;;
    *.json)        CONTENT_TYPE="application/json" ;;
    *.xml)         CONTENT_TYPE="application/xml" ;;
    *.png)         CONTENT_TYPE="image/png" ;;
    *.jpg|*.jpeg)  CONTENT_TYPE="image/jpeg" ;;
    *.gif)         CONTENT_TYPE="image/gif" ;;
    *.svg)         CONTENT_TYPE="image/svg+xml" ;;
    *.mp3)         CONTENT_TYPE="audio/mpeg" ;;
    *.ogg)         CONTENT_TYPE="audio/ogg" ;;
    *.wav)         CONTENT_TYPE="audio/wav" ;;
    *.mp4|*.m4v)   CONTENT_YPE="video/mp4" ;;
    *.mov)         CONTENT_TYPE="video/quicktime" ;;
    *.pdf)         CONTENT_TYPE="application/pdf" ;;
    *)             CONTENT_TYPE="application/octet-stream" ;;
  esac

  log "Sending file: [$FILE_NAME] Bytes: $CONTENT_LEN"

  printf 'HTTP/1.1 %s %s\r\nServer: domsetup\r\nContent-Type: %s\r\nContent-Length: %s\r\nConnection: close\r\n\r\n' "$HTTP_STATUS" "$REASON" "$CONTENT_TYPE" "$CONTENT_LEN" >&${OPENSSL[1]}
  cat "$FILE_NAME" >&${OPENSSL[1]}
}


process_post_request()
{
  POST_DATA=
  log "POST received [$1] Content-Length: $CONTENT_LEN"

  if [ "$CONTENT_LEN" = "0" ]; then
    log "No post data received"
    send_http_response 400 "Bad Request" "" "No post data received"
    return
  fi

  log "Reading $CONTENT_LEN bytes postdata"

  if read -N $CONTENT_LEN -r -u ${OPENSSL[0]} POST_DATA; then

    if [ "$1" = "/upload" ]; then
      send_http_redirect "$DOMSETUP_COMPLETED_REDIR" 303

    elif [ "$1" = "/domino-ots-setup" ]; then
      send_http_redirect "$DOMSETUP_COMPLETED_REDIR" 303

    else
      send_http_response 200 "OK" "" "Domino OTS data received"
    fi

  else
    log "Cannot read from OpenSSL process"
    send_http_response 400 "Bad Request" "" "No post data received"
    return
  fi
}


process_ots_json_postdata()
{
  # Remove post data headers and boundaries for multipart/form-data

  case "$RECEIVED_CONTENT_TYPE" in
    *multipart/form-data*)
      local BOUNDARY=$(echo "$RECEIVED_CONTENT_TYPE" | awk -F"boundary=" '{print $2}')
      if [ -n "$BOUNDARY" ]; then
        POST_DATA=$(echo "$POST_DATA" | tr -d '\r' | awk 'NF==0{p=1; next} p' | awk -F"--$BOUNDARY" '{print $1}')
      fi
      ;;
  esac

  if [ -z "$DOMSETUP_JSON_FILE" ]; then
    ots_read_replace_server_id_base64 "$POST_DATA"
  else
    ots_read_replace_server_id_base64 "$POST_DATA" > "$DOMSETUP_JSON_FILE"
    log_space  "Created OTS Domino file -> $DOMSETUP_JSON_FILE"
    log_space_stderr "Created OTS Domino file -> $DOMSETUP_JSON_FILE"
  fi
}


process_ots_form_data()
{
  IFS='&' read -ra PAIRS <<< "$POST_DATA"

  for pair in "${PAIRS[@]}"; do
    export "SERVERSETUP_$pair"
  done

  # Ensure user.id is set
  if [ -z "$SERVERSETUP_ADMIN_IDFILEPATH" ]; then
    SERVERSETUP_ADMIN_IDFILEPATH="$DOMINO_DATA_PATH/user.id"
  fi

  # Only dump sensitive setup data if requested for debug
  if [ "$DOMSETUP_DEBUG" = "yes" ]; then
    header "OTS form data"
    env | grep "^SERVERSETUP_" >> $DOMSETUP_LOGFILE
    log
  fi

  if [ ! -f "$DOMINO_AUTO_CONFIG_TEMPLATE_JSON_FILE" ]; then
    log_error "OTS File [$DOMINO_AUTO_CONFIG_TEMPLATE_JSON_FILE] does not exist"
    return 0
  fi

  if [ -z "$DOMSETUP_JSON_FILE" ]; then
    cat "$DOMINO_AUTO_CONFIG_TEMPLATE_JSON_FILE" | sed 's/{{ /${/g;s/{{/${/g;s/ }}/}/g;s/}}/}/g' | envsubst
  else
    cat "$DOMINO_AUTO_CONFIG_TEMPLATE_JSON_FILE" | sed 's/{{ /${/g;s/{{/${/g;s/ }}/}/g;s/}}/}/g' | envsubst > "$DOMSETUP_JSON_FILE"
    log "Created OTS Domino file -> $DOMSETUP_JSON_FILE"
    log_space_stderr "Created OTS Domino file -> $DOMSETUP_JSON_FILE"
  fi
}


check_authorization()
{
  local DOMSETUP_BASIC_AUTH=
  local DOMSETUP_BEARER_AUTH=

  if [ -n "$DOMSETUP_USER" ] && [ -n "$DOMSETUP_PASSWORD" ]; then
    DOMSETUP_BASIC_AUTH="Basic $(echo -n "$DOMSETUP_USER:$DOMSETUP_PASSWORD" | base64)"
  fi

  if [ -n "$DOMSETUP_BEARER" ]; then
    DOMSETUP_BEARER_AUTH="Bearer $DOMSETUP_BEARER"
  fi

  # No authorization required
  if [ -z "$DOMSETUP_BASIC_AUTH" ] && [ -z "$DOMSETUP_BEARER_AUTH" ]; then
    return 0
  fi

  # No authorization provided but required
  if [ -z "$AUTHORIZATION_HEADER" ]; then
    log_space "Authorization: Not provided"
    return 401
  fi

  if [ "$DOMSETUP_BASIC_AUTH" = "$AUTHORIZATION_HEADER" ]; then
    return 0
  fi

  if [ "$DOMSETUP_BEARER_AUTH" = "$AUTHORIZATION_HEADER" ]; then
    return 0
  fi

  log_space "Authorization: Failed"
  return 401
}


certmgr_cert_download()
{

  # Certificate already available
  if [ -s "$DOMSETUP_CERT_FILE" ]; then
    log_space "Info: Certificate already present: $DOMSETUP_CERT_FILE"
    return 0
  fi

  # No CertMgr Host specified
  if [ -z "$DOMSETUP_CERTMGR_HOST" ]; then
    log_space "Info: No CertMgr specified"
    return 1
  fi

  if [ ! -e "$DOMSETUP_KEY_FILE" ]; then
    log_error "No key found when checking CertMgr server"
    return 2
  fi

  # Check for new certificate on CertMgr server
  openssl s_client -servername $DOMSETUP_HOST -showcerts $DOMSETUP_CERTMGR_HOST:443 </dev/null 2>/dev/null | sed -ne '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' > "$DOMSETUP_CERT_FILE"

  if [ ! "$?" = "0" ]; then
    log_error "Cannot retrieve certificate from CertMgr server [$DOMSETUP_CERTMGR_HOST]"
    return 3
  fi

  if [ ! -s "$DOMSETUP_CERT_FILE" ]; then
    log_error "No certificate returned by CertMgr server"
    return 4
  fi

  local PUB_KEY_HASH=$(openssl x509 -in "$DOMSETUP_CERT_FILE" -noout -pubkey | openssl sha1 | cut -d ' ' -f 2)

  if [ -e "$DOMSETUP_KEY_FILE_PWD" ]; then
    local PUB_PKEY_HASH=$(openssl pkey -in "$DOMSETUP_KEY_FILE" -passin "file:$DOMSETUP_KEY_FILE_PWD" -pubout | openssl sha1 | cut -d ' ' -f 2)
  else
    local PUB_PKEY_HASH=$(openssl pkey -in "$DOMSETUP_KEY_FILE" -pubout | openssl sha1 | cut -d ' ' -f 2)
  fi

  if [ "$PUB_KEY_HASH" = "$PUB_PKEY_HASH" ]; then
    log_space "Certificate successfully downloaded from Domino CertMgr: $DOMSETUP_CERTMGR_HOST"
    return 0
  else
    log_error "Invalid certificate found"
    remove_file "$DOMSETUP_CERT_FILE"
    return 5
  fi
}


# --- Main logic ---

# Get environment variables and set defaults

if [ -z "$DOMSETUP_HOST" ]; then
  if [ -e /usr/bin/hostname ]; then
    DOMSETUP_HOST=$(/usr/bin/hostname -f)
  else
    DOMSETUP_HOST=localhost
  fi
fi

DOMINO_DATA_PATH=${DOMINO_DATA_PATH:-/local/notesdata}
DOMSETUP_HTTPS_PORT=${DOMSETUP_HTTPS_PORT:-443}
DOMSETUP_DNS_SAN=${DOMSETUP_DNS_SAN:-$DOMSETUP_HOST}
DOMSETUP_SUBJECT=${DOMSETUP_SUBJECT:-$DOMSETUP_HOST}
DOMSETUP_IP_SAN=${DOMSETUP_IP_SAN:-127.0.0.1}
DOMSETUP_DOMINO_REDIR=${DOMSETUP_DOMINO_REDIR:-/verse}
DOMSETUP_COMPLETED_REDIR=${DOMSETUP_COMPLETED_REDIR:-/completed.html?redirect=$DOMSETUP_DOMINO_REDIR}
DOMSETUP_OPNSSL_PID=
DOMSETUP_DONE=

if [ -z "$DOMSETUP_CERT_FILE" ]; then
  DOMSETUP_CERT_FILE=/tmp/domsetup-cert.pem
fi

if [ -z "$DOMSETUP_KEY_FILE" ]; then
  DOMSETUP_KEY_FILE=/tmp/domsetup-key.pem
fi

if [ -z "$DOMSETUP_KEY_FILE_PWD" ]; then
  DOMSETUP_KEY_FILE_PWD=/tmp/domsetup-password.txt
fi

if [ -z "$DOMSETUP_WEBROOT" ]; then
  DOMSETUP_WEBROOT=$SCRIPT_DIR/domsetup-webroot
fi

if [ -z "$DOMSETUP_LOGFILE" ]; then
  DOMSETUP_LOGFILE=/tmp/domsetup.log
fi

log_stderr
log_stderr "Domino OTS Setup $DOMSETUP_VERSION"
log_stderr "------------------------------------"
log_space_stderr "Log file: $DOMSETUP_LOGFILE"

# Clear the log first
clear_log

header "Domino OTS Setup $DOMSETUP_VERSION"
log_space "Started $(date)"

# Trap cleanup
trap cleanup_and_terminate INT TERM HUP QUIT EXIT

header "Environment"
env >> "$DOMSETUP_LOGFILE"
log

if [ ! -e /usr/bin/openssl ]; then
  log_space "OpenSSL is not installed"
  exit 1
fi


# Try to download certificate if key exists and CertMgr server is specified
certmgr_cert_download

# Create key & certificate via OpenSSL if not present

if [ ! -e "$DOMSETUP_KEY_FILE" ]; then
  header "Creating private key via OpenSSL"
  openssl ecparam -name prime256v1 -genkey -noout -out "$DOMSETUP_KEY_FILE" > /dev/null 2>> "$DOMSETUP_LOGFILE"
  DOMSETUP_TEMP_KEY="$DOMSETUP_KEY_FILE"
fi

if [ ! -e "$DOMSETUP_KEY_FILE" ]; then
  log_error "Cannot create key: $DOMSETUP_KEY_FILE"
  exit 1
fi

if [ ! -e "$DOMSETUP_CERT_FILE" ]; then
  header "Generating self-signed certificate via OpenSSL ..."
  openssl req -x509 -key "$DOMSETUP_KEY_FILE" -nodes -days 1 -subj "/CN=$DOMSETUP_SUBJECT" -addext "subjectAltName=DNS:$DOMSETUP_DNS_SAN,IP:$DOMSETUP_IP_SAN" -out "$DOMSETUP_CERT_FILE" 2>> "$DOMSETUP_LOGFILE"
  DOMSETUP_TEMP_CERT="$DOMSETUP_CERT_FILE"
fi

if [ ! -e "$DOMSETUP_CERT_FILE" ]; then
  log_error "Cannot create certificate: $DOMSETUP_CERT_FILE"
  exit 1
fi

show_cert "$DOMSETUP_CERT_FILE"

DOMSETUP_PARENT_PROCESS=$(ps -o comm= -p $(ps -o ppid= -p $$))

log "Parent Process: [$DOMSETUP_PARENT_PROCESS]"

if [ -z "$DOMINO_AUTO_CONFIG_TEMPLATE_JSON_FILE" ]; then

  if [ -e "$SCRIPT_DIR/first_server.json" ]; then
    DOMINO_AUTO_CONFIG_TEMPLATE_JSON_FILE="$SCRIPT_DIR/first_server.json"
  else
    DOMINO_AUTO_CONFIG_TEMPLATE_JSON_FILE="/opt/nashcom/startscript/OneTouchSetup/first_server.json"
  fi
fi

if [ -z "$DOMINO_AUTO_CONFIG_JSON_FILE" ]; then
  DOMINO_AUTO_CONFIG_JSON_FILE=/local/notesdata/DominoAutoConfig.json
fi

# Don't use output file if started from Domino server
if [ -z "$DOMSETUP_JSON_FILE" ]; then

  case "$DOMSETUP_PARENT_PROCESS" in
    */server)
      DOMSETUP_JSON_FILE=
      ;;

    *)
      DOMSETUP_JSON_FILE=$DOMINO_AUTO_CONFIG_JSON_FILE
      ;;
  esac
fi

log_space "OTS Output File: [$DOMSETUP_JSON_FILE]"

# Start OpenSSL as a mini web server

header "Starting OpenSSL"

if [ -n "$DOMSETUP_KEY_FILE_PWD" ] && [ -e "$DOMSETUP_KEY_FILE_PWD" ]; then
  coproc OPENSSL (openssl s_server -quiet -accept "$DOMSETUP_HTTPS_PORT" -cert "$DOMSETUP_CERT_FILE" -key "$DOMSETUP_KEY_FILE" -pass "file:$DOMSETUP_KEY_FILE_PWD" 2>> "$DOMSETUP_LOGFILE")
else
  coproc OPENSSL (openssl s_server -quiet -accept "$DOMSETUP_HTTPS_PORT" -cert "$DOMSETUP_CERT_FILE" -key "$DOMSETUP_KEY_FILE" 2>> "$DOMSETUP_LOGFILE")
fi

DOMSETUP_OPNSSL_PID="$!"
log "OpenSSL PID: $DOMSETUP_OPNSSL_PID"

# Wait a second to see if OpenSSL is really started
sleep 1

if [ -n "$DOMSETUP_OPNSSL_PID" ] && kill -0 "$DOMSETUP_OPNSSL_PID" 2>/dev/null; then
  log "OpenSSL is listening on port $DOMSETUP_HTTPS_PORT ..."
  echo "OpenSSL is listening on port $DOMSETUP_HTTPS_PORT ..."
else
  log_error "Cannot start OpenSSL in listening mode"
  exit 1
fi

while true; do

  POST_REQ=
  GET_REQ=
  CONTENT_LEN=0
  RECEIVED_CONTENT_TYPE=
  AUTHORIZATION_HEADER=
  HEADER_COUNT=0

  while true; do

    if read -r -u ${OPENSSL[0]} LINE; then
      # Replace via bash
      LINE="${LINE%$'\r'}"
    else
      log "Cannot read from OpenSSL process"
      exit 1
    fi

    if [ -z "$LINE" ]; then
      break
    fi

    log "Recv[$HEADER_COUNT] [$LINE]"

    if [ "$HEADER_COUNT" = "0" ]; then
      case "$LINE" in

        POST*)
            POST_REQ="$(echo $LINE | cut -f2 -d' ')"
            ;;

        GET*)
            GET_REQ="$(echo $LINE | cut -f2 -d' ')"
            ;;
      esac

    else
      # Compare headers case-insensitive by lowercasing it
      case ${LINE,,} in

        content-length:*)
          CONTENT_LEN=$(echo "$LINE"| cut -f2 -d":" | xargs)
          ;;

        content-type:*)
          RECEIVED_CONTENT_TYPE=$(echo "$LINE"| cut -f2 -d":" | xargs)
          ;;

        authorization:*)
          AUTHORIZATION_HEADER=$(echo "$LINE"| cut -f2 -d":" | xargs)
          ;;
      esac
    fi

    HEADER_COUNT=$((HEADER_COUNT + 1))
  done

  check_authorization
  AUTH_STATUS="$?"

  if [ "$AUTH_STATUS" != "0" ]; then
    send_http_unauthorized

  elif [ -n "$GET_REQ" ]; then

    # Terminate if hit the final redirect URL and return 404 to let the browser try again

    if [ -n "$DOMSETUP_DONE" ]; then
      if [ "$GET_REQ" = "$DOMSETUP_DOMINO_REDIR" ]; then
        send_http_response 404 "Not Found"
        log "Domino final redirect URL requests -> terminating"
        break
      fi
    fi

    process_get_request "$GET_REQ"

  elif [ -n "$POST_REQ" ]; then
    process_post_request "$POST_REQ"

    if [ "$POST_REQ" = "/ots" ]; then
      process_ots_json_postdata
      break
    fi

    if [ "$POST_REQ" = "/upload" ]; then
      log "OTS Upload completed"
      process_ots_json_postdata
      DOMSETUP_DONE=1
    fi

    if [ "$POST_REQ" = "/domino-ots-setup" ]; then
      process_ots_form_data
      DOMSETUP_DONE=1
    fi

  else
    send_http_response 400 "Bad Request" "" "Invalid request"
  fi

done;

# Make sure the OpenSSL back-end process terminates
cleanup_and_terminate
