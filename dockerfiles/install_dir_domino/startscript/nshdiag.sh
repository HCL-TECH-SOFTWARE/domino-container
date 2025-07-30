#!/bin/bash

###########################################################################
# Domino Diagnostic script (part of Domino start script)
###########################################################################
# 2025 Copyright by Daniel Nashed, feedback domino_unix@nashcom.de
# You may use and distribute the unmodified version of this script.
# Use at your own risk. No implied or specific warranties are given.
# You may change it for your own usage only
# Version 4.0.6 30.07.2025
###########################################################################


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


log_delay()
{
  log_space "$@"
  sleep 3
}


print_line()
{
  local input="$1"
  local len=${#input}
  printf '%*s\n' "$len" '' | tr ' ' '-'
  printf "\n"
}


enable_raw()
{
  stty -echo -icanon time 0 min 1
  tput civis
}


disable_raw()
{
  stty sane
  tput cnorm
}


cleanup_session()
{
  disable_raw
  echo

  if [ -z "$1" ]; then
    exit
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


get_file_age()
{
  if [ ! -e "$1" ]; then
    echo ""
  fi

  local now=$(date +%s)
  local modified=$(stat -c %Y "$1")
  local age=$((now - modified))

  echo "$(human_time $age)"
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


get_semdebug_infos()
{
  SEMDEBUG_DISPLAY=
  SEMDEBUG_LINES=

  if [ -z "$SEMDEBUG_FILE" ]; then
    return 0
  fi

  if [ ! -e "$SEMDEBUG_FILE" ]; then
    return 0
  fi

  SEMDEBUG_LINES=$(wc -l "$SEMDEBUG_FILE" | awk '{ print $1 }')

  case "$SEMDEBUG_LINES" in
    0)
      SEMDEBUG_DISPLAY="empty"
      ;;
    1)
      SEMDEBUG_DISPLAY="empty"
      ;;
    *)
      SEMDEBUG_DISPLAY="$SEMDEBUG_LINES lines"
      ;;
  esac
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

  get_semdebug_infos
  if [ -n "$SEMDEBUG_DISPLAY" ]; then
    log_file "SEM Debug  : $SEMDEBUG_FILE  [ $SEMDEBUG_DISPLAY ]"
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


send_trace_file()
{

 if [ -z "$DOMINO_DIAG_TRACE_FILE" ]; then
    log_error "No trace file found"
    wait_for_key
    return 0
  fi

  if [ ! -e "$DOMINO_DIAG_TRACE_FILE" ] ; then
    log_error "Cannot send file. $DOMINO_DIAG_TRACE_FILE does not exist."
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

  local BASE_FILENAME=$(basename "$DOMINO_DIAG_TRACE_FILE")

  header "Sending $BASE_FILENAME -> $DIAG_RCPT"

  tar -cz "$DOMINO_DIAG_TRACE_FILE" | "$NSHMAILX_BIN" "$DIAG_RCPT" -name "$DIAG_FULL_SERVER_NAME" -from "$DIAG_FROM"  -subject "Domino Tracefile [$DIAG_FULL_SERVER_NAME]" -att - -attname "${BASE_FILENAME}.taz"
  echo

}


edit_nsd()
{
  if [ -z "$LAST_NSD" ]; then
    log_error "No NSD found"
    wait_for_key
    return 0
  fi

  if [ ! -e "$LAST_NSD" ]; then
    log_error "NSD not found: $LAST_NSD"
    wait_for_key
    return 0
  fi

  "$EDIT_COMMAND" "$LAST_NSD"
}


edit_semdebug()
{
  if [ -z "$SEMDEBUG_FILE" ]; then
    log_error "No semdebug.txt found"
    wait_for_key
    return 0
  fi

  if [ ! -e "$SEMDEBUG_FILE" ]; then
    log_error "semdebug.txt not found: $SEMDEBUG_FILE"
    wait_for_key
    return 0
  fi

  "$EDIT_COMMAND" "$SEMDEBUG_FILE"
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


draw_process_explorer_menu()
{
  ClearScreen
  echo
  echo "HCL Domino process explorer"
  echo "---------------------------"
  echo
  echo "Use ↑↓ to navigate,  ESC to exit:"
  echo
  echo " [s] process stacks"
  if [ -x "/usr/bin/perf" ] || [ -x "/usr/local/bin/perf" ]; then
    echo " [p] process profiling"
  fi
  echo
  echo

  for i in "${!options[@]}"; do
    if [ "$i" -eq "$selected" ]; then
      printf "\e[7m%s\e[0m\n" "${options[$i]}"
    else
      printf "%s\n" "${options[$i]}"
    fi
  done
}


dom_process_explor_cleanup_and_bye()
{
  ClearScreen
  echo
  echo "HCL Domino process explorer"
  echo "---------------------------"
  echo
  echo Bye
  cleanup_session x
}


edit_log_file()
{
   if [ -z "$LOG_FILE" ]; then
     log_delay " Info: No log file"
     return 0
   fi

   if [ ! -e "$LOG_FILE" ]; then
     log_delay " Info: Logfile does not exist: $LOG_FILE"
     return 0
   fi

  "$EDIT_COMMAND" "$LOG_FILE"
}


dump_process_environment()
{

  if [ -z "$1" ]; then
    return 0
  fi

  if [ ! -e "/proc/$1/environ" ]; then
    return 0
  fi

  local CMD_LINE=$(tr '\0' ' ' < "/proc/$1/cmdline")
  # Remove trailing space
  CMD_LINE=${CMD_LINE%" "}

  printf "\n"
  local TITLE="Environment $CMD_LINE"
  printf "%s\n" "$TITLE"
  print_line "$TITLE"

  tr '\0' '\n' < "/proc/$1/environ"
  printf "\n"

  wait_for_key
}


process_explorer_menu()
{
  trap cleanup_session INT TERM EXIT

  mapfile -t options < <(grep "^1" /local/notesdata/pid.nbf | grep -v -e "nsd.sh" | awk '{ printf "%6s  %s  \n", $2, $4 }')

  selected=0

  # Disable cursor and enable raw input
  tput civis
  stty -echo -icanon time 0 min 1

  key=
  while true; do

    draw_process_explorer_menu
    read -rsn1 key

    case "$key" in

      $'\x1b')
        # Try to read more bytes quickly
        read -rsn2 -t 0.1 rest

        key+=$rest

        case "$key" in

          $'\x1b[A') # Up arrow
          ((selected--))
          ;;

          $'\x1b[B') # Down arrow
          ((selected++))
          ;;

          $'\x1b') # ESC key
            dom_process_explor_cleanup_and_bye
	    key=exit
          ;;

        esac
        ;;

      "")  # Enter key
        break
        ;;

      p)
        break
        ;;

      s)
        break
        ;;

      e)
        break
        ;;

      h)
        break
        ;;

      l)
        edit_log_file
        ;;

      q)
        dom_process_explor_cleanup_and_bye
	key=exit
        ;;
    esac

    # Clamp selection
    ((selected < 0)) && selected=0
    ((selected >= ${#options[@]})) && selected=$((${#options[@]} - 1))

   if [ "$key" = "exit" ]; then
      break;
    fi

  done

  LINE="${options[$selected]}"

  disable_raw
  ClearScreen

  PID=$(echo "$LINE" | awk '{ print $1 }')
}


get_gdb_thread_id()
{
  GDB_TID=

  if [ -z "$PID" ]; then
    return 0
  fi

  if [ -z "$TID" ]; then
    return 0
  fi

  if [ ! -e "/proc/$PID" ]; then
    log_delay "Process $PID does not exist"
    return 0
  fi

  GDB_TID=$(gdb -batch -ex "info threads" --pid "$PID" 2>/dev/null | grep "(LWP $TID)" | awk '{ print $1 }')
}


get_thread_id_gdb()
{
  TID=

  if [ -z "$PID" ]; then
    return 0
  fi

  if [ ! -e "/proc/$PID" ]; then
    log_delay "Process $PID does not exist"
    return 0
  fi

  if [ -z "$GDB_TID" ]; then
    return 0
  fi

  TID=$(gdb -batch -nx -ex "thread apply all bt" --pid=$PID 2>/dev/null | grep "Thread $GDB_TID" | awk -F'LWP' '{split($2, a, ")"); print a[1]}' | xargs)
}


select_gdb_thread()
{
  GDB_TID=
  TID=

  ClearScreen
  echo
  echo -n "Enter GDB Thread ID (TID): "

  read GDB_TID

  if [ "$GDB_TID" = "0" ]; then
    GDB_TID=
  fi

  if [ -z "$GDB_TID" ]; then
    return 0
  fi

  get_thread_id_gdb
}


select_thread()
{
  GDB_TID=
  TID=

  ClearScreen
  echo
  echo -n "Enter Thread ID (TID): "

  read TID

  if [ "$TID" = "0" ]; then
    TID=
    return 0
  fi

  if [ -z "$TID" ]; then
    return 0
  fi

  get_gdb_thread_id

  if [ -z "$GDB_TID" ]; then
    log_delay "Thread ID $TID not found for process $PID"
    return 0
  fi
}


run_htop()
{
  local HTOP_BIN=

  if [ -e /usr/bin/htop ]; then
    HTOP_BIN=/usr/bin/htop
  fi

  if [ -e /usr/local/bin/htop ]; then
    HTOP_BIN=/usr/local/bin/htop
  fi

  if [ -z "$HTOP_BIN" ]; then
    log_delay "HTOP not installed"
    return 0
  fi

  if [ -z "$1" ]; then
    $HTOP_BIN
  else
    $HTOP_BIN -p "$1"
  fi
}

enable_disable_logfile()
{
  if [ -z "$LOG_FILE" ]; then
    LOG_FILE="$DOMINO_DIAG_TRACE_FILE"
    printf "<@@ Domino Diagnostics (%s) @@>\n" "$(date)" > "$LOG_FILE"
    ClearScreen
    log_delay "Log file enabled --> $LOG_FILE"

  else
    ClearScreen
    log_delay "Log disabled ($LOG_FILE)"
    LOG_FILE=
  fi
}


dom_process_explor_check_for_key()
{
  local key=
  local k1=
  local k2=

  if [ -z "$1" ]; then
    read -rsn1 key
  else
    read -rsn1 -t "$1" key
  fi

  if [ "$key" = $'\x1b' ]; then

    read -rsn1 -t 0.1 k1
    read -rsn1 -t 0.1 k2
    full_key="$key$k1$k2"

  else
    full_key=$key
  fi

  case "$full_key" in
    [1-9])
      READ_TIMEOUT=$full_key
      ;;

    0)
      READ_TIMEOUT=
      ;;

    t)
      select_thread
      ;;

    g)
      select_gdb_thread
      ;;

    h)
      run_htop "$PID"
      ;;

    n)
      NO_CLEAR_SCRREN=1
      ;;

    c)
      NO_CLEAR_SCRREN=
      ;;

    l)
      enable_disable_logfile
      ;;

    $'\x1b')
      return 1
      ;;
    q)
      return 1
      ;;
  esac

  return 0
}


process_dump()
{
  if [ -z "$PID" ]; then
    return 0
  fi

  if [ ! -e "/proc/$PID" ]; then
    log_delay "Process $PID does not exist"
    return 0
  fi

  get_gdb_thread_id

  CMD_LINE=$(tr '\0' ' ' < "/proc/$PID/cmdline")

  while true; do

    if [ -z "$NO_CLEAR_SCRREN" ]; then
      ClearScreen
    fi

    echo

    if [ -z "$GDB_TID" ]; then
     if [ -z "$LOG_FILE" ]; then
        printf "\n<@@ Process $PID  $CMD_LINE @@>\n\n"
      else
    printf "\n<@@ Process %s  %s  (%s) @@>\n\n" "$PID" "$CMD_LINE" "$(date)" | tee -a "$LOG_FILE"
      fi

    else
      if [ -z "$TID" ]; then
        DSP_THREAD="$PID/gdb$GDB_TID"
      else
        DSP_THREAD="$PID/$TID"
      fi

      if [ -z "$LOG_FILE" ]; then
        printf "\n<@@ Thread $DSP_THREAD  $CMD_LINE @@>\n\n"
      else
    printf "\n<@@ Thread %s  %s  (%s) @@>\n\n" "$DSP_THREAD" "$CMD_LINE" "$(date)" | tee -a "$LOG_FILE"
      fi
    fi
    echo

    if [ -z "$GDB_TID" ]; then
      if [ -z "$LOG_FILE" ]; then
        gdb -batch -nx -ex "thread apply all bt" --pid=$PID 2>/dev/null| grep -v -e "^\[New LWP"
      else
        gdb -batch -nx -ex "thread apply all bt" --pid=$PID 2>/dev/null| grep -v -e "^\[New LWP" | tee -a "$LOG_FILE"
      fi
    else
      if [ -z "$LOG_FILE" ]; then
        gdb -batch -nx -ex "thread $GDB_TID" -ex "bt" --pid=$PID 2>/dev/null| grep -v -e "^\[New LWP"
      else
        gdb -batch -nx -ex "thread $GDB_TID" -ex "bt" --pid=$PID 2>/dev/null| grep -v -e "^\[New LWP" | tee -a "$LOG_FILE"
      fi
    fi

    dom_process_explor_check_for_key "$READ_TIMEOUT"
    if [ $? -eq 1 ]; then
      return 0
    fi

  done;
}


dom_process_explor_perform_action()
{
  READ_TIMEOUT=
  TID=
  GDB_TID=
  NO_CLEAR_SCREN=

  case "$key" in

    s)
      process_dump
      ;;

    p)
      perf top -p $PID
      ;;

    e)
      dump_process_environment $PID
      ;;

    h)
      run_htop $PID
      ;;

    "")
      process_dump
      ;;

    *)
      echo "Invalid option $key"
      ;;

  esac
}


domino_process_explorer()
{
  if [ -n "$1" ]; then
    SELECT_PID=$1
  fi

  if [ -n "$2" ]; then
    SELECT_TID=$2
  fi

  if [ -n "$SELECT_PID" ]; then
    PID="$SELECT_PID"
    TID="$SELECT_TID"
    process_dump
    exit 0
  fi

  while true; do
    process_explorer_menu

    if [ "$key" = "exit" ]; then
      break;
    fi

    dom_process_explor_perform_action
  done;
}


menu()
{
  local SELECTED=

  while [ 1 ];
  do

    LAST_NSD=$(head -1 "$NSD_INDEX_FILE")

    ClearScreen
    echo
    echo "HCL Domino Diagnostics"
    echo "----------------------"
    echo

    echo " Server     :  $DIAG_FULL_SERVER_NAME"
    echo " Hostname   :  $DIAG_HOSTNAME"
    echo " Diag RCPT  :  $DIAG_RCPT"
    echo

    if [ -n "$DOMINO_DIAG_TRACE_FILE" ] && [ -e "$DOMINO_DIAG_TRACE_FILE" ]; then
      echo " Trace file :  $DOMINO_DIAG_TRACE_FILE ($(du -sh "$DOMINO_DIAG_TRACE_FILE" | cut -f1))"
    fi

    if  [ -z "$LAST_NSD" ] && [ -z "$SEMDEBUG_FILE" ]; then
      echo " Diag Dir   :  $DIAG_DIRECTORY"
    fi

    get_semdebug_infos

    if [ -n "$SEMDEBUG_DISPLAY" ]; then
      echo " SEM Debug  :  $SEMDEBUG_FILE  [ $SEMDEBUG_DISPLAY ]"
    fi

    if [ -n "$LAST_NSD" ] && [ -e "$LAST_NSD" ]; then
      echo " Latest NSD :  $LAST_NSD"
      echo " NSD age    :  $(get_file_age "$LAST_NSD")"
    fi

    if [ -n "$DOMINO_DIAG_TAR" ]; then
      echo " Diag file  :  $DOMINO_DIAG_TAR ($(du -sh "$DOMINO_DIAG_TAR" | cut -f1))"
    fi

    echo
    echo
    echo " (N)   Run NSD"
    echo " (L)   Open latest NSD"
    echo " (X)   Explor Domino processes"

    if [ -n "$SEMDEBUG_DISPLAY" ]; then
      echo " (B)   Open semdebug.txt"
    fi

    echo " (C)   Collect logs"

    if [ -x "$NSHMAILX_BIN" ] ; then
      echo " (D)   Send diagnostics"
      if [ -n "$LAST_NSD" ]; then
        echo " (S)   Send latest NSD"
      fi

      if [ -n "$DOMINO_DIAG_TRACE_FILE" ] && [ -e "$DOMINO_DIAG_TRACE_FILE" ]; then
        echo " (T)   Send trace file"
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

      b)
        edit_semdebug
        ;;

      c)
        collect_diag
	wait_for_key
        ;;

      d)
        if [ -z "$DIAG_RCPT" ]; then
          input_diag_recipient
        fi

        echo
        read -p " Confirm sending diagnostic TAR to $DIAG_RCPT: (yes/no) ? " QUESTION

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

      t)
        if [ -z "$DIAG_RCPT" ]; then
          input_diag_recipient
        fi

        send_trace_file
        ;;

      r)
        ClearScreen
        input_diag_recipient
        ;;

      x)
	domino_process_explorer
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

# --- Main script logic ---

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
DOMINO_DIAG_LOG="$DIAG_DIRECTORY/domdiag_${DATE_STR}.log"
DOMINO_DIAG_TRACE_FILE="$DIAG_DIRECTORY/domdiag_trace_${DATE_STR}.log"


if [ -z "$EDIT_COMMAND" ]; then
  if [ -n "$EDITOR" ]; then
    EDIT_COMMAND="$EDITOR"
  else
    EDIT_COMMAND="vi"
  fi
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


for a in "$@"; do

  p=$(echo "$a" | awk '{print tolower($0)}')

  case "$p" in
    menu)
      ACTION=menu
      ;;

    collect)
      ACTION=collect
      ;;

    mail|send|senddiag)
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

    explore)
      ACTION=explore
      ;;

    -mail=*|-rcpt=*)
      DIAG_RCPT=$(echo "$a" | cut -f2 -d= -s)
      ;;

    -h|/h|-?|/?|-help|--help|help|usage)
      usage
      exit 0
      ;;

    "")
      # Ignore empty commands (can happen if invoked from outside
      ;;

    *)
      log_error "Invalid parameter [$a]"
      exit 1
      ;;
  esac
done


case "$ACTION" in

  "")
    menu
    ;;

  menu)
    menu
    ;;

  sendnsd)
    send_nsd
    ;;

  last|nsd)
    edit_nsd
    ;;

  mail)
    collect_diag
    send_diag
    remove_file "$DOMINO_DIAG_LOG"
    ;;

  collect)
    collect_diag
    remove_file "$DOMINO_DIAG_LOG"
    ;;

  explore)
    domino_process_explorer
    ;;

  *)
    echo "Unknown action: $ACTION"
    ;;
esac

