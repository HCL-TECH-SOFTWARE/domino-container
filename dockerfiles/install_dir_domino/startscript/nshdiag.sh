#!/bin/bash

SCRIPT_NAME=$(readlink -f $0)
SCRIPT_DIR=$(dirname $SCRIPT_NAME)


print_delim()
{
  echo "--------------------------------------------------------------------------------"
}


header()
{
  echo
  print_delim
  echo "$1"
  print_delim
  echo
}


log_space()
{
  echo
  echo "$@"
  echo
}


log_error()
{
  echo
  echo "$@"
  echo
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


ClearScreen()
{
  if [ "$DISABLE_CLEAR_SCREEN" = "yes" ]; then
    return 0
  fi

  clear
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


human_time()
{
    local seconds="$1"
    local unit=""
    local value=0

    if (( seconds >= 86400 )); then
        unit="days"
        value=$(( (seconds * 10) / 86400 ))
    elif (( seconds >= 3600 )); then
        unit="hours"
        value=$(( (seconds * 10) / 3600 ))
    elif (( seconds >= 60 )); then
        unit="minutes"
        value=$(( (seconds * 10) / 60 ))
    else
        unit="seconds"
        value=$(( seconds * 10 ))
    fi

    # Format: integer division and remainder to get .X
    int=$((value / 10))
    dec=$((value % 10))
    echo "${int}.${dec} ${unit}"
}


log_file ()
{
  echo "$@" >> "$DOMINO_DIAG_LOG"
}


print_file()
{
  if [ ! -e "$1" ]; then
    echo "File does not exist"
    return 0
  fi

  local now=$(date +%s)
  local modified=$(stat -c %Y "$1")
  local age=$((now - modified))

  log_file "$1 ($(human_time $age))"
}


showfile()
{
  print_file "$1" "$2"
}


list_files()
{
  if [ -z "$1" ]; then
    return 0
  fi

  local CURRENT_DIR=$(pwd)
  local pattern=

  if [ -z "$2" ]; then
    pattern="*.log"
  else
    pattern="$2"
  fi

  local max_days=30

  if [ -n "$3" ]; then
    max_days="$3"
  fi

  cd "$1"

  find . -type f -name "$pattern" -mtime -$max_days -printf '%T@ %P\n' | sort -nr | awk '{print $2}' | while IFS= read -r file; do
    showfile "$file"
  done

  cd "$CURRENT_DIR"
}


tar_files()
{

  if [ -z "$1" ]; then
    return 0
  fi

  local CURRENT_DIR=$(pwd)
  local pattern=

  if [ -z "$2" ]; then
    pattern="*.log"
  else
    pattern="$2"
  fi

  local max_days=30

  if [ -n "$3" ]; then
    max_days="$3"
  fi

  cd "$1"
  find . -type f -name "$pattern" -mtime -$max_days -printf '%P\n' | tar -czf "$DOMINO_DIAG_TAR" --files-from=-

  cd "$CURRENT_DIR"
  echo "Created $DOMINO_DIAG_TAR ($(du -sh "$DOMINO_DIAG_TAR" | cut -f1))"
}


collect_diag()
{

  if [ -n "$DOMINO_DIAG_TAR" ]; then
    return 1
  fi

  DOMINO_DIAG_TAR="$DIAG_DIRECTORY/domdiag_${DIAG_SERVER_NAME}_${DATE_STR}.taz"

  log_file "Servername : $DIAG_FULL_SERVER_NAME"
  log_file "Hostname   : $DIAG_HOSTNAME"
  log_file "Diag Dir   : $DIAG_DIRECTORY"

  if [ -n "$SEMDEBUG_FILE" ]; then
    log_file "SEM Debug  : $SEMDEBUG_FILE"
  fi

  if [ -n "$LAST_NSD" ]; then
    log_file "Latest NSD : $LAST_NSD"
  fi

  if [ "$DIAG_DAYS" = "1" ]; then
    UNIT=day
  else
    UNIT=days
  fi

  log_file
  log_file "Latest Diagnostic files ($DIAG_DAYS $UNIT)"
  log_file "----------------------------------------"
  log_file

  list_files "$DIAG_DIRECTORY" "*" "$DIAG_DAYS"
  cat "$DOMINO_DIAG_LOG"

  echo

  header "Collecting files"

  tar_files "$DIAG_DIRECTORY" "*" "$DIAG_DAYS"

  echo
}


collect_files()
{
  header "Collecting files"
  tar_files "$DIAG_DIRECTORY" "*" "$DIAG_DAYS"
  echo
}


send_diag()
{

  if [ -z "$DIAG_RCPT" ]; then
    log_error "Cannot send mail. No recipient specified"
    wait_for_key
    return 0
  fi

  if [ ! -x "$NSHMAILX_BIN" ] ; then
    log_ernor "Cannot send mail. No nshmailx command available"
    wait_for_key
    return 0
  fi

  header "Sending diagnostics to $DIAG_RCPT"

  "$NSHMAILX_BIN" "$DIAG_RCPT" -name "$DIAG_FULL_SERVER_NAME" -from "$DIAG_FROM" -file "$DOMINO_DIAG_LOG" -subject "Domino Diag [$DIAG_FULL_SERVER_NAME]" -att "$DOMINO_DIAG_TAR"
  remove_file "$DOMINO_DIAG_TAR"
  DOMINO_DIAG_TAR=
  echo
}


send_nsd()
{

  if [ -z "$LAST_NSD" ]; then
    log_error "No NSD found"
    wait_for_key
    return 0
  fi

  if [ ! -e "$LAST_NSD" ] ; then
    log_error "Cannot send file. $LAST_NSD does not exist."
    wait_for_key
    return 0
  fi

  if [ -z "$DIAG_RCPT" ]; then
    log_error "Cannot send mail. No recipient specified"
    wait_for_key
    return 0
  fi

  if [ ! -x "$NSHMAILX_BIN" ] ; then
    log_error "Cannot send mail. No nshmailx command available"
    wait_for_key
    return 0
  fi

  local NSD_FILENAME=$(basename "$LAST_NSD")

  header "Sending $NSD_FILENAME -> $DIAG_RCPT"

  tar -cz "$LAST_NSD" | "$NSHMAILX_BIN" "$DIAG_RCPT" -name "$DIAG_FULL_SERVER_NAME" -from "$DIAG_FROM"  -subject "Domino NSD [$DIAG_FULL_SERVER_NAME]" -att - -attname "${NSD_FILENAME}.taz"
  echo
}


edit_nsd()
{
  if [ -z "$LAST_NSD" ]; then
    log_error "No NSD found"
    return 0
  fi

  "$EDIT_COMMAND" "$LAST_NSD"
}


display_diag()
{

  ClearScreen
  header "Domino Diagnostics"

  echo "Server     :  $DIAG_FULL_SERVER_NAME"
  echo "Hostname   :  $DIAG_HOSTNAME"
  echo "Diag Dir   :  $DIAG_DIRECTORY"

  if [ -n "$SEMDEBUG_FILE" ]; then
    echo "SEM Debug  :  $SEMDEBUG_FILE"
  fi

  if [ -n "$LAST_NSD" ]; then
    echo "Latest NSD :  $LAST_NSD"
  fi

  echo
}


usage()
{
  echo
  echo "Usage: $(basename $SCRIPT_NAME)"
  echo
  echo "collect          Collect diagnostic file into a compressed tar"
  echo "send|mail        Send collected diagnostics by mail"
  echo "nsd              Run a full NSD"
  echo "sendnsd          Send latest NSD"
  echo "last             Open latest NSD"
  echo "-mail|-rcpt <x>  Set mail recipient (default: notes.ini DominoDiagRcpt)"
  echo
}


menu_help()
{
  echo "Domino Diagnostic Menu Help"
  echo "---------------------------"
  echo
  echo "The Domino Diagnostic Menu offers diagnostics commands."
  echo "It is intended to provide easy diagnostics."
  echo
}


input_diag_recipient()
{

  while [ 1 ];
  do
    ClearScreen
    echo
    read -n40 -e -p " Diagnostics recipient? " DIAG_RCPT;

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

menu()
{
  local SELECTED=

  while [ 1 ];
  do
    ClearScreen
    echo
    echo "HCL Domino Diagnostics"
    echo "----------------------"
    echo

    echo " Server     :  $DIAG_FULL_SERVER_NAME"
    echo " Hostname   :  $DIAG_HOSTNAME"
    echo " Diag RCPT  :  $DIAG_RCPT"
    echo
    echo " Diag Dir   :  $DIAG_DIRECTORY"

    if [ -n "$SEMDEBUG_FILE" ]; then
      echo " SEM Debug  :  $SEMDEBUG_FILE"
    fi

    if [ -n "$LAST_NSD" ]; then
      echo " Latest NSD :  $LAST_NSD"
    fi

    if [ -n "$DOMINO_DIAG_TAR" ]; then
      echo " Diag file  :  $DOMINO_DIAG_TAR ($(du -sh "$DOMINO_DIAG_TAR" | cut -f1))"
    fi

    echo
    echo
    echo " (N)   Run NSD"
    echo " (L)   Open latest NSD"
    echo " (C)   Collect logs"

    if [ -x "$NSHMAILX_BIN" ] ; then
      echo " (D)   Send diagnostics"
      if [ -n "$LAST_NSD" ]; then
        echo " (S)   Send latest NSD"
      fi
      echo " (R)   Set recipient"

    else
      echo " (!)   No nshmailx found!"
    fi

    echo
    echo " (H)   Help"
    echo
    echo
    read -n1 -e -p " Select command,  [Q] to cancel? " SELECTED;

    ClearScreen

    case $(echo "$SELECTED" | awk '{print tolower($0)}') in

      "")
        ;;

      0|q)
        ClearScreen
        echo
        exit 0
        ;;

      n)
        domino nsd
        ;;

      l)
        edit_nsd
        ;;

      c)
        collect_diag
        remove_file "$DOMINO_DIAG_LOG"
        ;;

      d)
        if [ -z "$DIAG_RCPT" ]; then
          input_diag_recipient
        fi

        echo
        read -p " Confirm sending diagnostic ZIP to $DIAG_RCPT: (yes/no) ? " QUESTION

        if [ "$QUESTION" = "yes" ] || [ "$QUESTION" = "y" ]; then

          collect_diag
          send_diag
          remove_file "$DOMINO_DIAG_LOG"
          sleep 2
        else
          echo
          echo " Not sending diagnostic data"
          sleep 3
        fi
        ;;

      s)
        if [ -z "$DIAG_RCPT" ]; then
          input_diag_recipient
        fi

        echo
        read -p " Confirm sending latest NSD to $DIAG_RCPT: (yes/no) ? " QUESTION

        if [ "$QUESTION" = "yes" ] || [ "$QUESTION" = "y" ]; then

          send_nsd
          sleep 2
        else
          echo
          echo " Not sending NSD data"
          sleep 3
        fi
        ;;

      r)
        ClearScreen
        input_diag_recipient
        ;;

      h)
        menu_help
        usage
        wait_for_key
        ;;

      *)
        echo
        echo
        echo " Invalid option selected: $SELECTED"
        echo -n " "
        sleep 2
        ;;
    esac

  done
}


if [ -z "$DOMINO_DATA_PATH" ]; then
  DOMINO_DATA_PATH=/local/notesdata
fi

NOTESINI="$DOMINO_DATA_PATH/notes.ini"

if [ ! -e "$NOTESINI" ]; then
  log_space "Cannot find notes.ini"
  exit 1
fi

NSD_INDEX_FILE="$DOMINO_DATA_PATH/nsdindex.nbf"
DIAG_INDEX_FILE="$DOMINO_DATA_PATH/diagindex.nbf"

LAST_NSD=$(head -1 "$NSD_INDEX_FILE")
DIAG_DIRECTORY=$(head -1 "$DIAG_INDEX_FILE")
SEMDEBUG_FILE="$DIAG_DIRECTORY/SEMDEBUG.TXT"
DATE_STR=$(LANG=C date +"%Y_%m_%d@%H_%M_%S")
DOMINO_DIAG_LOG="$DOMINO_DATA_PATH/diag_${DATE_STR}.log"


if [ -z "$EDIT_COMMAND" ]; then
  EDIT_COMMAND="vi"
fi

if [ ! -e "$SEMDEBUG_FILE" ]; then
  SEMDEBUG_FILE=
fi

if [ ! -e "$LAST_NSD" ]; then
  LAST_NSD=
fi

if [ -z "$DIAG_HOSTNAME" ]; then
  DIAG_HOSTNAME=$(hostname -f)
fi

if [ -z "$DIAG_DAYS" ]; then
  DIAG_DAYS=1
fi

NSHMAILX_BIN=/usr/bin/nshmailx

DIAG_FULL_SERVER_NAME=$(cat "$NOTESINI" | grep -i "^ServerName=" | head -1 | cut -d'=' -f2)

if [ -z "$DIAG_FULL_SERVER_NAME" ]; then
  DIAG_FULL_SERVER_NAME=$(echo "$DIAG_HOSTNAME" | tr ' ' '_' | tr '.' '_')
fi

DIAG_SERVER_NAME=$(echo "$DIAG_FULL_SERVER_NAME" | cut -d '/' -f1 | tr ' ' '_' | tr '.' '_')

if [ -z "$DIAG_FROM" ]; then
  DIAG_FROM="$DIAG_HOSTNAME"
fi

if [ -z "$DIAG_RCPT" ]; then
  DIAG_RCPT=$(cat "$NOTESINI" | grep -i "^DominoDiagRcpt=" | head -1 | cut -d'=' -f2)
fi

display_diag

for a in "$@"; do

  p=$(echo "$a" | awk '{print tolower($0)}')

  case "$p" in
    menu)
      ACTION=menu
      ;;

    collect)
      ACTION=collect
      ;;

    mail|send)
      ACTION=mail
      ;;

    nsd)
      ACTION=nsd
      ;;

    last)
      ACTION=last
      ;;

    sendnsd)
      ACTION=sendnsd
      ;;

    -mail=*|-rcpt=*)
      DIAG_RCPT=$(echo "$a" | cut -f2 -d= -s)
      ;;

    -h|/h|-?|/?|-help|--help|help|usage)
      usage
      exit 0
      ;;

    *)
      log_error "Invalid parameter [$a]"
      exit 1
      ;;
  esac
done


if [ -z "$ACTION" ]; then
  ACTION=menu
fi

if [ "$ACTION" = "menu" ]; then

  menu

elif [ "$ACTION" = "sendnsd" ]; then

  send_nsd

elif [ "$ACTION" = "last" ]; then

  edit_nsd

elif [ "$ACTION" = "nsd" ]; then

  edit_nsd

elif [ "$ACTION" = "mail" ]; then

  collect_diag
  send_diag
  remove_file "$DOMINO_DIAG_LOG"

elif [ "$ACTION" = "collect" ]; then

  collect_diag
  remove_file "$DOMINO_DIAG_LOG"
fi


