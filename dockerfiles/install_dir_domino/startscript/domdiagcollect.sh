#!/bin/bash

###########################################################################
# Domino Diagnostic collect script (part of Domino start script)
###########################################################################
#
# 2026 Copyright by Daniel Nashed, feedback domino_unix@nashcom.de
# You may use and distribute the unmodified version of this script.
# Use at your own risk. No implied or specific warranties are given.
# You may change it for your own usage only
#
# Version 0.9.0 11.01.2026
#
###########################################################################

SCRIPT_NAME=$(readlink -f $0)
SCRIPT_DIR=$(dirname $SCRIPT_NAME)


ClearScreen()
{
  if [ "$DISABLE_CLEAR_SCREEN" = "yes" ]; then
    return 0
  fi

  # Clear screen using the escape sequence
  printf "\033[H\033[J"
}


wait_for_key()
{
  local SELECTED=
  echo
  echo "--- Press any key to continue / [Q] for quit  ---"
  echo
  read -n1 -e SELECTED;

  if [ "$SELECTED" = "q" ]; then
    exit 0
  fi
}


log()
{
  echo
  echo "$@"
  echo
}


log_error()
{
  log "Error: $@"
}


remove_file()
{
  if [ -z "$1" ]; then
    return 1
  fi

  if [ ! -e "$1" ]; then
    return 2
  fi

  rm -rf "$1"
  return 0
}


cleanup()
{
  tput cnorm
  stty sane
}


enter_raw()
{
  tput civis
  stty -echo -icanon
}


get_max_hours()
{
  cleanup

  while true; do
    echo
    read -r -p "Log age (hours): [$MAX_HOURS]: " MAX_HOURS
    MAX_HOURS=${MAX_HOURS:-$DEFAULT_MAX_HOURS}

    if [[ "$MAX_HOURS" =~ ^[0-9]+$ ]]; then
      break
    fi
  done

  if [ "$MAX_HOURS" = "0" ]; then
    exit 0
  fi

  enter_raw
}


draw_menu()
{
  local buf="" line
  local i mark cursor

  buf+=" Files modified $START_DATE_TIME ($MAX_HOURS hours) in $SEARCH_PATH"$'\n'
  buf+="──────────────────────────────────────────────────────────────────────────────────────────"$'\n'

  for i in "${!OPTIONS[@]}"; do
    (( MARKED[i] )) && mark="[X] " || mark="[ ] "
    (( i == SELECTED )) && cursor="➤" || cursor=" "

    printf -v line "%s%s %-.*s" \
      "$cursor" "$mark" "$MAX_WIDTH" "${OPTIONS[$i]}"

    buf+="$line"$'\n'
  done

  buf+=$'\n'
  buf+=" ↑ ↓ Move - SPACE/x toggle - ENTER confirm - ECS/q quit - m/h to change max hours"$'\n'

  ClearScreen
  printf "%s" "$buf"
}


build_options()
{
  NOW=$(date +%s)
  CUTOFF=$(( NOW - MAX_HOURS * 3600 ))
  START=$CUTOFF
  START_DATE_TIME="$(date -d "@$START" '+%Y-%m-%d %H:%M:%S')"

  OPTIONS=()
  FILES=()
  MARKED=()
  SELECTED=0

  local line path

  remove_file "$DOMINO_DIAG_TMP_FILE_LIST"

  while IFS='|' read -r ts size path; do
    # store real path
    FILES+=("$path")

    # build human-readable size
    local s="$size" unit="B"
    for unit in B K M G T; do
      (( s < 1024 )) && break
      s=$((s / 1024))
    done

    OPTIONS+=(
      "$(printf "%s  %6s  %s" "$ts" "${s}${unit}" "$path")"
    )
  done < <(
    find . -type f -newermt "@$START" ! -name "domdiag_*" 2>/dev/null \
      -printf '%TY-%Tm-%Td %TH:%TM|%s|%p\n' |
      sort -r
  )

  for ((i=0;i<${#OPTIONS[@]};i++)); do
    MARKED[$i]=$PRESET
  done
}


select_collect_diag()
{
  local CURRENT_DIR=$(pwd)
  local key=
  cd "$SEARCH_PATH"

  build_options

  trap cleanup INT TERM EXIT
  enter_raw

  while true; do
    draw_menu

    read -rsN1 key

    case "$key" in

      $'\x1b')
        # Try to read more bytes quickly
        read -rsN2 -t 0.1 rest

        key+=$rest

        case "$key" in

          $'\x1b[A') # Up arrow
          ((SELECTED--))
          ;;

          $'\x1b[B') # Down arrow
          ((SELECTED++))
          ;;

          $'\x1b') # ESC key
            key=exit
            break
          ;;
        esac

        (( SELECTED < 0 )) && SELECTED=0
        (( SELECTED >= ${#OPTIONS[@]} )) && SELECTED=$((${#OPTIONS[@]} - 1))
        ;;

      $'\n'|$'\r')  # Enter
        break
        ;;

      " "|x|X)
        MARKED[$SELECTED]=$((1 - MARKED[$SELECTED]))
        ;;

      m|h)
        get_max_hours
        build_options
        ;;

      q)
        key=exit
        break
        ;;
    esac
  done

  cleanup

  if [ "$key" = "exit" ]; then
    ClearScreen
    log "Terminated without collecting logs"
    exit 0
  fi

  for i in "${!MARKED[@]}"; do
    (( MARKED[i] )) && printf '%s\n' "${FILES[$i]}" >> "$DOMINO_DIAG_TMP_FILE_LIST"
  done

  ClearScreen

  if [ -e "$DOMINO_DIAG_TMP_FILE_LIST" ]; then

    if [ "$SEVENZIP_ENABLED" = "yes" ] || [ "$SEVENZIP_ENABLED" = "1" ]; then

      if command -v 7z >/dev/null 2>&1; then
        DOMINO_DIAG_ARCHIVE_FILE=${DOMINO_DIAG_ARCHIVE_FILE%.*}.7z

        local SEVENZ_OPTS=()

        case "$SEVENZIP_PASSWORD" in
          "")
            # no encryption
            ;;

          "@")
            # interactive prompt
            SEVENZ_OPTS+=(-p -mhe=on)
            ;;

          "#")
            # random password
            SEVENZIP_RANDOM_PASSWORD=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)
            SEVENZ_OPTS+=(-p"$SEVENZIP_RANDOM_PASSWORD" -mhe=on)
            ;;

          *)
            # password provided
            SEVENZ_OPTS+=(-p"$SEVENZIP_PASSWORD" -mhe=on)
             ;;
        esac

        7z a "$DOMINO_DIAG_ARCHIVE_FILE" "@$DOMINO_DIAG_TMP_FILE_LIST" "${SEVENZ_OPTS[@]}"

        log "--------------------"

      else
        log_error "7Zip is not installed!"
        remove_file "$DOMINO_DIAG_TMP_FILE_LIST"
        exit 1
      fi

    else
      tar --warning=no-file-changed --ignore-failed-read -T "$DOMINO_DIAG_TMP_FILE_LIST" -czf "$DOMINO_DIAG_ARCHIVE_FILE"
    fi

    remove_file "$DOMINO_DIAG_TMP_FILE_LIST"

  else
    log "No select file found"
  fi

  cd "$CURRENT_DIR"
}


log_upload_result()
{
  echo
  log "$@"

  if [ -n "$SEVENZIP_RANDOM_PASSWORD" ]; then
    log "One-time password ->  $SEVENZIP_RANDOM_PASSWORD"
  fi
}


input_diag_recipient()
{

  while [ 1 ];
  do
    ClearScreen
    echo
    read -n40 -e -p "Diagnostics recipient? " DIAG_RCPT;

    case "$DIAG_RCPT" in

      *@*.*)
        return 0
        ;;

      "")
        return 0
        ;;

      *)
        echo
        echo " Invalid recipient!"
        sleep 2
        ;;
    esac

  done
}


upload_file()
{
  if [ ! -e "$DOMINO_DIAG_ARCHIVE_FILE" ]; then
    log "File does not exist: $DOMINO_DIAG_ARCHIVE_FILE"
    exit 1
  fi

  if [ ! -r "$DOMINO_DIAG_ARCHIVE_FILE" ]; then
    log "Cannot read file: $DOMINO_DIAG_ARCHIVE_FILE"
    exit 1
  fi

  FILE_NAME=$(basename "$DOMINO_DIAG_ARCHIVE_FILE")

  # WebDav Upload to OwnCloud publish share if configured

  if [ -n "$WEBDAV_URL" ]; then

    if [ -z "$WEBDAV_PASSWORD" ]; then
      log_error "No 'WEBDAV_PASSWORD' configured"
      exit 1
    fi

    if [ -z "$WEBDAV_PUBLIC_SHARE" ]; then
      log_error "No 'WEBDAV_PUBLIC_SHARE' configured"
      exit 1
    fi

    log "FileUpload  $FILE_NAME -> $WEBDAV_URL"
    echo
    read -p "Confirm (yes/no) ? " QUESTION
    if [ "$QUESTION" = "yes" ] || [ "$QUESTION" = "y" ]; then
      TARGET="$WEBDAV_URL"
    else
      log_upload_result "Check collected log file: $DOMINO_DIAG_ARCHIVE_FILE"
      exit 1
    fi

    CURL_RESULT=$(curl -s -S --fail -u "$WEBDAV_PUBLIC_SHARE:$WEBDAV_PASSWORD" -T "$DOMINO_DIAG_ARCHIVE_FILE" "$WEBDAV_URL/$FILE_NAME" 2>&1)
    rc=$?

    if [ $rc -eq 0 ] && [ -z "$CURL_RESULT" ]; then
      echo
      log_upload_result "Upload successful: $DOMINO_DIAG_ARCHIVE_FILE"

      remove_file "$DOMINO_DIAG_ARCHIVE_FILE"

    else
      log_upload_result "WebDav upload failed: $DOMINO_DIAG_ARCHIVE_FILE"
      echo "$CURL_RESULT"
      echo
    fi

  elif [ -n "$SCP_TARGET" ]; then

    log "SFTP Transfer:  $FILE_NAME -> $SCP_TARGET"
    echo
    read -p "Confirm (yes/no) ? " QUESTION
    if [ "$QUESTION" = "yes" ] || [ "$QUESTION" = "y" ]; then
      TARGET="$SCP_TARGET"
    else
      log_upload_result "Check collected log file: $DOMINO_DIAG_ARCHIVE_FILE"
      exit 1
    fi

    set -- scp

    if [ -n "$SCP_KEY" ]; then
      set -- "$@" -i "$SCP_KEY"
    fi

    if [ -n "$SCP_PORT" ]; then
      set -- "$@" -P "$SCP_PORT"
    fi

    set -- "$@" "$DOMINO_DIAG_ARCHIVE_FILE" "$SCP_TARGET/"

    echo
    if "$@"; then
      echo
      log_upload_result "Upload successful: $DOMINO_DIAG_ARCHIVE_FILE"
      remove_file "$DOMINO_DIAG_ARCHIVE_FILE"

    else
      echo
      log_upload_result "SCP upload failed: $DOMINO_DIAG_ARCHIVE_FILE"
    fi

  elif command -v nshmailx >/dev/null 2>&1; then

    if [ -z "$DIAG_FROM" ]; then
      DIAG_FROM=$(cat "$NOTESINI" | grep -i "^DominoDiagFrom=" | head -1 | cut -d'=' -f2)
    fi

    if [ -z "$DIAG_FROM" ]; then
      DIAG_FROM="$DIAG_HOSTNAME"
    fi

    if [ -z "$DIAG_RCPT" ]; then
      DIAG_RCPT=$(cat "$NOTESINI" | grep -i "^DominoDiagRcpt=" | head -1 | cut -d'=' -f2)
    fi

    if [ -z "$DIAG_RCPT" ]; then
        input_diag_recipient
    fi

    if [ -z "$DIAG_RCPT" ]; then
      log_upload_result "No upload recipient configured: $DOMINO_DIAG_ARCHIVE_FILE"
      exit 1
    fi

    log "Send SMTP mail:  $FILE_NAME -> $DIAG_RCPT"
    echo
    read -p "Confirm (yes/no) ? " QUESTION
    if [ "$QUESTION" = "yes" ] || [ "$QUESTION" = "y" ]; then
      TARGET="$DIAG_RCPT"
    else
      log_upload_result "Check collected log file: $DOMINO_DIAG_ARCHIVE_FILE"
      exit 1
    fi

    nshmailx "$DIAG_RCPT" -name "$DIAG_FULL_SERVER_NAME" -from "$DIAG_FROM" -subject "Domino Diag [$DIAG_FULL_SERVER_NAME]" -att "$DOMINO_DIAG_ARCHIVE_FILE"

  else
    echo
    log_upload_result "No upload target configured: $DOMINO_DIAG_ARCHIVE_FILE"
  fi
}


usage()
{
  echo
  echo "Usage: $(basename $SCRIPT_NAME) [Filename/Directory] [Options]"
  echo
  echo "<file/directory>  file/directory to upload. if not specified use IBM_TECHNICAL_SUPPORT"
  echo
  echo "cfg               Open configuration"
  echo "-7z|-7Zip         Use 7Zip even Tar is configured"
  echo "-tar              Use Tar even 7Zip is configured"
  echo "-pwd              Generate a random password when using 7Zip"
  echo "-pwd=<password>   Use the specified password for 7Zip"
  echo
  echo
}


edit_config()
{
  if [ ! -e "$DOM_DIAG_COLLECT_CFG" ]; then

    echo >> "$DOM_DIAG_COLLECT_CFG"
    echo "# --- WebDav config ---" >> "$DOM_DIAG_COLLECT_CFG"
    echo >> "$DOM_DIAG_COLLECT_CFG"
    echo "#WEBDAV_URL=https://webdav.example.com/public.php/webdav" >> "$DOM_DIAG_COLLECT_CFG"
    echo "#WEBDAV_PASSWORD=password" >> "$DOM_DIAG_COLLECT_CFG"
    echo "#WEBDAV_PUBLIC_SHARE=xyz" >> "$DOM_DIAG_COLLECT_CFG"

    echo >> "$DOM_DIAG_COLLECT_CFG"
    echo "# --- SCP config ---" >> "$DOM_DIAG_COLLECT_CFG"
    echo >> "$DOM_DIAG_COLLECT_CFG"
    echo "#SCP_TARGET=notes@domino.example.com:/local/nshdiag" >> "$DOM_DIAG_COLLECT_CFG"
    echo "#SCP_PORT=22" >> "$DOM_DIAG_COLLECT_CFG"
    echo >> "$DOM_DIAG_COLLECT_CFG"

    echo "# --- 7Zip config ---" >> "$DOM_DIAG_COLLECT_CFG"
    echo >> "$DOM_DIAG_COLLECT_CFG"
    echo "#SEVENZIP_ENABLED=yes" >> "$DOM_DIAG_COLLECT_CFG"
    echo "#SEVENZIP_PASSWORD=@" >> "$DOM_DIAG_COLLECT_CFG"
    echo >> "$DOM_DIAG_COLLECT_CFG"
    echo "# --- Mail config ---" >> "$DOM_DIAG_COLLECT_CFG"
    echo >> "$DOM_DIAG_COLLECT_CFG"
    echo "#DIAG_RCPT=admin@example.com" >> "$DOM_DIAG_COLLECT_CFG"
    echo "#DIAG_FROM" >> "$DOM_DIAG_COLLECT_CFG"
    echo >> "$DOM_DIAG_COLLECT_CFG"

  fi

  "$EDIT_COMMAND" "$DOM_DIAG_COLLECT_CFG"
}


# ---------- Main Logic ----------

if [ -z "$DOMINO_DATA_PATH" ]; then
  DOMINO_DATA_PATH=/local/notesdata
fi

NOTESINI="$DOMINO_DATA_PATH/notes.ini"

if [ ! -e "$NOTESINI" ]; then
  log "Cannot find notes.ini"
  exit 1
fi

DOM_DIAG_COLLECT_CFG="$DOMINO_DATA_PATH/.domdiagcollect.cfg"
SEARCH_PATH="$DOMINO_DATA_PATH/IBM_TECHNICAL_SUPPORT"
DEFAULT_MAX_HOURS=24
MAX_WIDTH=110
PRESET=1

DOMINO_DIAG_TMP_FILE_LIST=/tmp/domdiag_file_list.tmp

# Check configuration file first
if [ -e "$DOM_DIAG_COLLECT_CFG" ]; then
  . "$DOM_DIAG_COLLECT_CFG"

# If not found check notes.ini
else
  WEBDAV_URL=$(cat "$NOTESINI" | grep -i "^DOMDIAG_WEBDAV_URL=" | head -1 | cut -d'=' -f2)

  WEBDAV_PUBLIC_SHARE=$(cat "$NOTESINI" | grep -i "^DOMDIAG_PUBLIC_SHARE=" | head -1 | cut -d'=' -f2)
  WEBDAV_PASSWORD=$(cat "$NOTESINI" | grep -i "^DOMDIAG_WEBDAV_PASSWORD=" | head -1 | cut -d'=' -f2)

  SCP_TARGET=$(cat "$NOTESINI" | grep -i "^DOMDIAG_SCP_TARGET=" | head -1 | cut -d'=' -f2)
  SCP_PORT=$(cat "$NOTESINI" | grep -i "^DOMDIAG_SCP_PORT=" | head -1 | cut -d'=' -f2)

fi

if [ -z "$EDIT_COMMAND" ]; then
  if [ -n "$EDITOR" ]; then
    EDIT_COMMAND="$EDITOR"
  else
    EDIT_COMMAND="vi"
  fi
fi

# Get parameters

for a in "$@"; do

  p=$(echo "$a" | awk '{print tolower($0)}')

  case "$p" in

    cfg|-cfg)
      edit_config
      exit 0
      ;;

    -h|/h|-?|/?|-help|--help|help|usage)
      usage
      exit 0
      ;;

    -password|-pwd)
      SEVENZIP_PASSWORD=#
      ;;

    -password=*|-pwd=*)
      SEVENZIP_PASSWORD=$(echo "$a" | cut -f2 -d= -s)
      ;;

    -7z|-7zip|-zip)
      SEVENZIP_ENABLED=yes
      ;;

    -tar)
      SEVENZIP_ENABLED=no
      ;;

    -*)
      log_error "Invalid parameter [$a]"
      exit 1
      ;;

    "")
      # Ignore empty commands (can happen if invoked from outside
      ;;

    *)
      DIAG_TARGET="$a"
      ;;

  esac
done


if [ -n "$SEVENZIP_PASSWORD" ]; then
  if [ "$SEVENZIP_ENABLED" != "yes" ] && [ "$SEVENZIP_ENABLED" != "1" ]; then
    log_error "Encryption is only supported with 7Zip"
    exit 1
  fi
fi

# State
declare -a OPTIONS
declare -a FILES
declare -a MARKED

if [ -z "$MAX_HOURS" ]; then
  MAX_HOURS="$DEFAULT_MAX_HOURS"
fi

DIAG_INDEX_FILE="$DOMINO_DATA_PATH/diagindex.nbf"
DIAG_DIRECTORY=$(head -1 "$DIAG_INDEX_FILE")

DIAG_FULL_SERVER_NAME=$(cat "$NOTESINI" | grep -i "^ServerName=" | head -1 | cut -d'=' -f2)

if [ -z "$DIAG_HOSTNAME" ]; then
  DIAG_HOSTNAME=$(hostname -f 2> /dev/null)

  if [ -z "$DIAG_HOSTNAME" ]; then
    DIAG_HOSTNAME=$(hostname 2> /dev/null)
  fi
fi

if [ -z "$DIAG_FULL_SERVER_NAME" ]; then
  DIAG_FULL_SERVER_NAME=$(echo "$DIAG_HOSTNAME" | tr ' ' '_' | tr '.' '_')
fi

DIAG_SERVER_NAME=$(echo "$DIAG_FULL_SERVER_NAME" | cut -d '/' -f1 | tr ' ' '_' | tr '.' '_')

DATE_STR=$(LANG=C date +"%Y_%m_%d@%H_%M_%S")
DOMINO_DIAG_ARCHIVE_FILE="$DIAG_DIRECTORY/domdiag_${DIAG_SERVER_NAME}_${DATE_STR}.taz"

if [ -z "$DIAG_TARGET" ]; then
  select_collect_diag
else

  if [ ! -e "$DIAG_TARGET" ]; then
    log "File or folder not found: $DIAG_TARGET"
    exit 0
  fi

  if [ -f "$DIAG_TARGET" ]; then
    tar -czf "$DOMINO_DIAG_ARCHIVE_FILE" "$DIAG_TARGET"

  elif [ -d "$DIAG_TARGET" ]; then
    SEARCH_PATH="$DIAG_TARGET"
    select_collect_diag

  else
    log "Invalid file type: $DIAG_TARGET"
    exit 0
  fi

fi

echo
upload_file

