#!/bin/bash
############################################################################
# Copyright Nash!Com, Daniel Nashed 2019, 2025 - APACHE 2.0 see LICENSE
# Copyright IBM Corporation 2015, 2019 - APACHE 2.0 see LICENSE
############################################################################

# Global helper script only included once.
# The script is installed by the Domino installer script and is used by add-on installers and run-time config scripts.

if [ -n "$DOMDOCK_SCRIPT_LIB_INCLUDED" ]; then
  # Only included once. Use "return" - exit would terminate also the calling script!
  return 0
fi
export DOMDOCK_SCRIPT_LIB_INCLUDED=DONE

# Global definitions
export DOMDOCK_DIR=/domino-container
export DOMDOCK_TXT_DIR=/domino-container
export DOMDOCK_SCRIPT_DIR=/domino-container/scripts
export DOMDOCK_INSTALL_DATA_TAR=$DOMDOCK_DIR/install_data_domino.taz

if [ -z "$DOMDOCK_LOG_DIR" ]; then
  export DOMDOCK_LOG_DIR=/tmp/domino-container
fi

# Ensure the environment is setup
export LOTUS=/opt/hcl/domino
export Notes_ExecDirectory=$LOTUS/notes/latest/linux
export LD_LIBRARY_PATH=$Notes_ExecDirectory:$LD_LIBRARY_PATH
export NUI_NOTESDIR=$LOTUS
export PATH=$PATH:$DOMINO_DATA_PATH
export SOFTWARE_FILE=$INSTALL_DIR/software.txt

# Ensure files extracted by root get standard owner (some files have high UID/GID values)
export TAR_OPTIONS=--no-same-owner

# In container environments the LOGNAME is not set
if [ -z "$LOGNAME" ]; then
  export LOGNAME=$(whoami)
fi

# Ensure environment is defined, if not already set

if [ -z "$DOMINO_DATA_PATH" ]; then
export DOMINO_DATA_PATH=/local/notesdata
fi

if [ -z "$DOMINO_INI_PATH" ]; then
  export DOMINO_INI_PATH=$DOMINO_DATA_PATH/notes.ini
fi

if [ -z "$CURL_CMD" ]; then
  CURL_CMD="curl --location --max-redirs 10 --fail --connect-timeout 15 --max-time 300 $SPECIAL_CURL_ARGS"
fi

if [ -z "$DOMINO_USER" ]; then
  DOMINO_USER=notes
fi

if [ -z "$DOMINO_GROUP" ]; then
  DOMINO_GROUP=notes
fi

if [ -z "$DIR_PERM" ]; then
  DIR_PERM=770
fi

# Exclude repo IP if set
if [ -n "$SOFTWARE_REPO_IP" ]; then
  if [ -z "$no_proxy" ]; then
    export no_proxy="$SOFTWARE_REPO_IP"
  else
    export no_proxy="$no_proxy,$SOFTWARE_REPO_IP"
  fi
fi


# Helper Functions

print_delim()
{
  echo "--------------------------------------------------------------------------------"
}

log_ok()
{
  echo "$@"
}

log_file()
{
  echo "$@"

  if [ -z "$LOG_FILE" ]; then
    return 0
  fi
  echo "$@" >> $LOG_FILE 2>&1
}

log_file_delim()
{
   log_file "--------------------------------------------------------------------------------"
}

log_file_header()
{
   log_file
   log_file_delim
   log_file "$@"
   log_file_delim
   log_file
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
  echo "ERROR - $@"
  echo
}

log_debug()
{
  if [ "$DOMDOCK_DEBUG" = "yes" ]; then
    echo "$(date '+%F %T') debug: $@"
  fi
}

copy_log()
{
 if [ -e "$1" ]; then
    cp -f "$1" "$2"
 else
   echo "Warning: Log file not found: $1"
 fi
}

header()
{
  echo
  print_delim
  echo "$1"
  print_delim
  echo
}

dump_file()
{
  if [ -z "$1" ]; then
    return 0
  fi

  if [ ! -e "$1" ]; then
    echo "Cannot dump file - File does not exist: $1"
    return 0
  fi

  echo
  echo "----- $1 -----"
  cat "$1"
  echo "----- $1 -----"
  echo
}

check_file_str()
{
  CURRENT_FILE="$1"
  CURRENT_STRING="$2"


  if [ -e "$CURRENT_FILE" ]; then
    CURRENT_RESULT=$(grep "$CURRENT_STRING" "$CURRENT_FILE")

    if [ -z "$CURRENT_RESULT" ]; then
      return 0
    else
      return 1
    fi
  fi

  return 0
}

http_head_check()
{
  local CURL_RET=$($CURL_CMD -w 'RESP_CODE:%{response_code}\n' --silent --head "$1" | grep 'RESP_CODE:200')

  if [ -z "$CURL_RET" ]; then
    return 0
  else
    return 1
  fi
}

get_download_name()
{
  DOWNLOAD_NAME=""
  if [ -e "$SOFTWARE_FILE" ]; then
    DOWNLOAD_NAME=$(grep "$1|$2|" "$SOFTWARE_FILE" | cut -d"|" -f3)
  else
    log_error "Download file [$SOFTWARE_FILE] not found!"
    exit 1
  fi

  if [ -z "$DOWNLOAD_NAME" ]; then
    log_error "Download for [$1] [$2] not found!"
    exit 1
  fi

  return 0
}

download_file_ifpresent()
{
  CURRENT_DIR=
  DOWNLOAD_SERVER=$1
  DOWNLOAD_FILE=$2
  TARGET_DIR=$3

  if [ -z "$DOWNLOAD_FILE" ]; then
    log_error "No download file specified!"
    exit 1
  fi

  http_head_check "$DOWNLOAD_SERVER/$DOWNLOAD_FILE"
  if [ "$?" = "0" ]; then
    echo "Info: Download file does not exist [$DOWNLOAD_FILE]"
    return 0
  fi

  CURRENT_DIR=$(pwd)

  if [ -n "$TARGET_DIR" ]; then
    mkdir -p "$TARGET_DIR"
    cd $TARGET_DIR
  fi

  if [ -e "$DOWNLOAD_FILE" ]; then
    echo
    echo "Replacing existing file [$DOWNLOAD_FILE]"
    rm -f "$DOWNLOAD_FILE"
  fi

  echo
  $CURL_CMD "$DOWNLOAD_SERVER/$DOWNLOAD_FILE" -o "$(basename $DOWNLOAD_FILE)" 2>/dev/null
  echo

  if [ "$?" = "0" ]; then
    log_ok "Successfully downloaded: [$DOWNLOAD_SERVER/$DOWNLOAD_FILE] "
    echo
    cd $CURRENT_DIR
    return 0

  else
    log_error "File [$DOWNLOAD_FILE] not downloaded correctly"
    echo "CURL returned: [$CURL_RET]"
    exit 1
  fi
}

dump_download_error()
{
  echo "HASH         : [$HASH]"
  echo "SOFTWARE_FILE: [$SOFTWARE_FILE]"
  echo "CURRENT_FILE : [$CURRENT_FILE]"
  echo
  echo "--- $SOFTWARE_FILE ---"
  cat $SOFTWARE_FILE
  echo "--- $SOFTWARE_FILE ---"
  echo
}


copy_file_and_check_hash()
{
  local DOWNLOAD_SERVER=$1
  local DOWNLOAD_STR=$2
  local TARGET_DIR=$3
  local TARGET_FILE=$4
  local FILES_TO_EXTRACT=$5

  case "$DOWNLOAD_SERVER" in
    file://*)
      DOWNLOAD_SERVER=$(echo "$DOWNLOAD_SERVER" | awk -F "file://" '{print $2}')
      ;;
    *)
      ;;
  esac

  log_debug "DOWNLOAD_SERVER: [$DOWNLOAD_SERVER]"

  # If "nohash" option is specified, don't check for hash
  if [ "$5" = "nohash" ]; then
    local NOHASH=1
    echo "Copying file without hash [$DOWNLOAD_STR]"
  fi

  # Check if file exists before downloading

  for CHECK_FILE in $(echo "$DOWNLOAD_STR" | tr "," "\n" ) ; do

    # Check for absolute download link
    case "$CHECK_FILE" in
      *://*)
        echo "Skipping copy file for: [$CHECK_FILE]"
        ;;

      *)
        DOWNLOAD_FILE=$DOWNLOAD_SERVER/$CHECK_FILE
        ;;
    esac

    if [ -r "$DOWNLOAD_FILE" ]; then
      CURRENT_FILE="$CHECK_FILE"
      FOUND=TRUE
      break
    fi
  done

  if [ ! "$FOUND" = "TRUE" ]; then
    log_error "File [$DOWNLOAD_FILE] does not exist"
    exit 1
  fi

  echo "Downloading: [$DOWNLOAD_FILE]"

  CURRENT_DIR=$(pwd)

  if [ -n "$TARGET_DIR" ]; then
    mkdir -p "$TARGET_DIR"
    cd "$TARGET_DIR"
  fi

  case "$DOWNLOAD_FILE" in
    *.tar.gz)
      TAR_OPT=-xz
      ;;

    *.tgz)
      TAR_OPT=-xz
      ;;

    *.taz)
      TAR_OPT=-xz
      ;;

    *.tar)
      TAR_OPT=-x
      ;;

    *)
      TAR_OPT=""
      ;;
  esac

  if [ -z "$TAR_OPT" ]; then

    # Download without extracting for none tar files
    if [ -z "$TARGET_FILE" ] || [ "." = "$TARGET_FILE" ]; then
      TARGET_FILE=$(basename $DOWNLOAD_FILE)
    fi

    cp "$DOWNLOAD_FILE" "$TARGET_FILE"

    if [ ! -e "$TARGET_FILE" ]; then
      log_error "File [$DOWNLOAD_FILE] not copied [1]"
      exit 1
    fi

    if [ "$NOHASH" = "1" ]; then
      FOUND=1
    else
      HASH=$(sha256sum -b $TARGET_FILE | cut -f1 -d" ")
      FOUND=$(grep "$HASH" "$SOFTWARE_FILE" | grep "$CURRENT_FILE" | wc -l)
    fi

    # Download file can be present more than once (e.g. IF/HF). Perfectly OK as long the hash matches.
    if [ "$FOUND" = "0" ]; then
      log_error "File [$DOWNLOAD_FILE] not copied correctly [1]"
      dump_download_error
      exit 1
    else
      log_ok "Successfully copied: [$DOWNLOAD_FILE] to [$TARGET_FILE]"
    fi

  else
    if [ -e $SOFTWARE_FILE ]; then

      log_debug "Software.txt file exists: $SOFTWARE_FILE"

      if [ "$NOHASH" = "1" ]; then
        echo
        tar  $TAR_OPT -f "$DOWNLOAD_FILE" 2>/dev/null
        echo
        FOUND=1
      else
        echo
        HASH=$(cat $DOWNLOAD_FILE | tee >(tar $TAR_OPT $FILES_TO_EXTRACT 2>/dev/null) | sha256sum -b | cut -d" " -f1)
        echo
        FOUND=$(grep "$HASH" "$SOFTWARE_FILE" | grep "$CURRENT_FILE" | wc -l)
      fi

      if [ "$FOUND" = "0" ]; then
        log_error "File [$DOWNLOAD_FILE] not copied correctly [2]"
        dump_download_error
        exit 1
      else
        log_ok "Successfully copied, extracted & checked: [$DOWNLOAD_FILE] "
      fi

    else
      log_debug "Software.txt file does not exists: $SOFTWARE_FILE"

      echo
      tar $TAR_OPT -f "$DOWNLOAD_FILE" 2>/dev/null
      echo

      if [ "$?" = "0" ]; then
        log_ok "Successfully copied & extracted: [$DOWNLOAD_FILE] "
      else
        log_error "File [$DOWNLOAD_FILE] not copied correctly [3]"
        exit 1
      fi
    fi
  fi

  cd $CURRENT_DIR
  return 0
}


download_and_check_hash()
{
  local DOWNLOAD_SERVER=$1
  local DOWNLOAD_STR=$2
  local TARGET_DIR=$3
  local TARGET_FILE=$4
  local FILES_TO_EXTRACT=$5
  local TAR_OPT=

  case "$DOWNLOAD_SERVER" in
    file://*)
      copy_file_and_check_hash "$@"
      return 0
      ;;
    *)
      ;;
  esac

  # If "nohash" option is specified, don't check for hash
  if [ "$5" = "nohash" ]; then
    local NOHASH=1
    echo "Downloading file without hash [$DOWNLOAD_STR]"
  fi

  # Check if file exists before downloading

  for CHECK_FILE in $(echo "$DOWNLOAD_STR" | tr "," "\n" ) ; do

    # Check for absolute download link
    case "$CHECK_FILE" in
      *://*)
        DOWNLOAD_FILE=$CHECK_FILE
        ;;

      *)
        DOWNLOAD_FILE=$DOWNLOAD_SERVER/$CHECK_FILE
        ;;
    esac

    http_head_check "$DOWNLOAD_FILE"
    if [ "$?" = "1" ]; then
      CURRENT_FILE="$CHECK_FILE"
      FOUND=TRUE
      break
    fi
  done

  if [ ! "$FOUND" = "TRUE" ]; then
    log_error "File [$DOWNLOAD_FILE] does not exist"
    echo "CURL returned: [$CURL_RET]"
    header "Curl Error Information"
    curl -svIS "$DOWNLOAD_FILE"
    echo
    exit 1
  fi

  CURRENT_DIR=$(pwd)

  if [ -n "$TARGET_DIR" ]; then
    mkdir -p "$TARGET_DIR"
    cd "$TARGET_DIR"
  fi

  case "$DOWNLOAD_FILE" in
    *.tar.gz)
      TAR_OPT=-xz
      ;;

    *.tgz)
      TAR_OPT=-xz
      ;;

    *.taz)
      TAR_OPT=-xz
      ;;

    *.tar)
      TAR_OPT=-x
      ;;

    *)
      TAR_OPT=""
      ;;
  esac

  if [ -z "$TAR_OPT" ]; then

    # Download without extracting for none tar files
    if [ -z "$TARGET_FILE" ] || [ "." = "$TARGET_FILE" ]; then
      TARGET_FILE=$(basename $DOWNLOAD_FILE)
    fi

    $CURL_CMD "$DOWNLOAD_FILE" -o "$TARGET_FILE"

    if [ ! -e "$TARGET_FILE" ]; then
      log_error "File [$DOWNLOAD_FILE] not downloaded [1]"
      exit 1
    fi

    if [ "$NOHASH" = "1" ]; then
      FOUND=1
    else
      HASH=$(sha256sum -b $TARGET_FILE | cut -f1 -d" ")
      FOUND=$(grep "$HASH" "$SOFTWARE_FILE" | grep "$CURRENT_FILE" | wc -l)
    fi

    # Download file can be present more than once (e.g. IF/HF). Perfectly OK as long the hash matches.
    if [ "$FOUND" = "0" ]; then
      log_error "File [$DOWNLOAD_FILE] not downloaded correctly [1]"
      dump_download_error
      exit 1
    else
      log_ok "Successfully downloaded: [$DOWNLOAD_FILE] to [$TARGET_FILE]"
    fi

  else
    if [ -e $SOFTWARE_FILE ]; then

      if [ "$NOHASH" = "1" ]; then
        echo
        $CURL_CMD $DOWNLOAD_FILE | tar $TAR_OPT 2>/dev/null
        echo
        FOUND=1
      else
        echo
        HASH=$($CURL_CMD $DOWNLOAD_FILE | tee >(tar $TAR_OPT $FILES_TO_EXTRACT 2>/dev/null) | sha256sum -b | cut -d" " -f1)
        echo
        FOUND=$(grep "$HASH" "$SOFTWARE_FILE" | grep "$CURRENT_FILE" | wc -l)
      fi

      if [ "$FOUND" = "0" ]; then
        log_error "File [$DOWNLOAD_FILE] not downloaded correctly [2]"
        dump_download_error
        exit 1
      else
        log_ok "Successfully downloaded, extracted & checked: [$DOWNLOAD_FILE] "
      fi

    else
      echo
      $CURL_CMD $DOWNLOAD_FILE | tar $TAR_OPT 2>/dev/null
      echo

      if [ "$?" = "0" ]; then
        log_ok "Successfully downloaded & extracted: [$DOWNLOAD_FILE] "
      else
        log_error "File [$DOWNLOAD_FILE] not downloaded correctly [3]"
        exit 1
      fi
    fi
  fi

  cd $CURRENT_DIR
  return 0
}


download_tar_with_hash()
{
  local DOWNLOAD_SERVER=$1
  local DOWNLOAD_STR=$2
  local CHECK_FILE=
  local TAR_OPT=

  CHECK_FILE=$(echo "$DOWNLOAD_STR" | cut -f1 -d"#" | xargs)
  CHECK_HASH=$(echo "$DOWNLOAD_STR" | cut -f2 -d"#" | xargs)

  if [ -z "$CHECK_HASH" ]; then
    log_error "No hash specified for download: [$DOWNLOAD_FILE]"
    exit 1
  fi

  # Check for absolute download link
  case "$CHECK_FILE" in
    *://*)
      DOWNLOAD_FILE=$CHECK_FILE
      ;;

    *)
      DOWNLOAD_FILE=$DOWNLOAD_SERVER/$CHECK_FILE
      ;;
  esac

  case "$DOWNLOAD_FILE" in

    *.zip)
      TAR_OPT=unzip
      ;;

    *.tar.gz)
      TAR_OPT=-xz
      ;;

    *.tgz)
      TAR_OPT=-xz
      ;;

    *.taz)
      TAR_OPT=-xz
      ;;

    *.tar)
      TAR_OPT=-x
      ;;

    *)
      TAR_OPT=""
      ;;
  esac

  http_head_check "$DOWNLOAD_FILE"
  if [ "$?" = "0" ]; then
    log_error "Cannot download file: [$DOWNLOAD_FILE] - File not found"
    exit 1
  fi

  if [ "$TAR_OPT" = "unzip" ]; then

    header "Unzip $DOWNLOAD_FILE"

    local ZIP_FILE=custom_addon_download.zip
    $CURL_CMD -s $DOWNLOAD_FILE -o "$ZIP_FILE"
    HASH=$(sha256sum -b "$ZIP_FILE" | cut -d" " -f1)

    if [ "$HASH" = "$CHECK_HASH" ]; then
      unzip -o -q "$ZIP_FILE"
    fi

    find .

  else
    HASH=$($CURL_CMD -s $DOWNLOAD_FILE | tee >(tar $TAR_OPT --no-same-owner 2>/dev/null) | sha256sum -b | cut -d" " -f1)
  fi

  if [ "$HASH" = "$CHECK_HASH" ]; then
    return 0
  fi

  echo 
  echo "Download : $DOWNLOAD_FILE"
  echo "Current  : $HASH"
  echo "Expected : $CHECK_HASH"

  log_error "Cannot download file: [$DOWNLOAD_FILE] - Hash does not match"
  exit 1
}


check_file_busy()
{
  if [ ! -e "$1" ]; then
    return 0
  fi

  local TARGET_REAL_BIN=$(readlink -f $1)
  local FOUND_TARGETS=$(lsof "$TARGET_REAL_BIN" 2>/dev/null | grep "$TARGET_REAL_BIN")

  if [ -n "$FOUND_TARGETS" ]; then
    return 1
  else
    return 0
  fi
}

nsh_cmp()
{
  if [ -z "$1" ]; then
    return 1
  fi

  if [ -z "$2" ]; then
    return 1
  fi

  if [ ! -e "$1" ]; then
    return 1
  fi

  if [ ! -e "$2" ]; then
    return 1
  fi

  if [ -x /usr/bin/cmp ]; then
    cmp -s "$1" "$2"
    return $?
  fi

  HASH1=$(sha256sum "$1" | cut -d" " -f1)
  HASH2=$(sha256sum "$2" | cut -d" " -f1)

  if [ "$HASH1" = "$HASH2" ]; then
    return 0
  fi

  return 1
}

install_file()
{
  SOURCE_FILE=$1
  TARGET_FILE=$2
  OWNER=$3
  GROUP=$4
  PERMS=$5

  if [ ! -r "$SOURCE_FILE" ]; then
    echo "[$SOURCE_FILE] Can not read source file"
    return 1
  fi

  if [ -e "$TARGET_FILE" ]; then

    nsh_cmp "$SOURCE_FILE" "$TARGET_FILE"
    if [ $? -eq 0 ]; then
      echo "[$TARGET_FILE] File did not change -- No update needed"
      return 0
    fi

    if [ ! -w "$TARGET_FILE" ]; then
      echo "[$TARGET_FILE] Can not update binary -- No write permissions"
      return 1
    fi
  fi

  cp -f "$SOURCE_FILE" "$TARGET_FILE"

  if [ -n "$OWNER" ]; then
    chown $OWNER:$GROUP "$TARGET_FILE"
  fi

  if [ -n "$PERMS" ]; then
    chmod "$PERMS" "$TARGET_FILE"
  fi

  echo "[$TARGET_FILE] copied"

  return 2
}

install_binary()
{
  SOURCE_BIN="$1"

  if [ -z "$SOURCE_BIN" ]; then
    echo "no file specified"
    return 0
  fi

  if [ ! -r "$SOURCE_BIN" ]; then
    echo "Source file does not exist or is not readable [$SOURCE_BIN]"
    return 0
  fi

  if [ ! -e "$SOURCE_BIN" ]; then
    echo "Cannot find binary [$SOURCE_BIN]"
    return 0
  fi

  INSTALL_BIN_NAME=$(basename $SOURCE_BIN)

  if [ -z "$INSTALL_BIN_NAME" ]; then
    echo "no file specified"
    return 0
  fi

  TARGET_BIN=$Notes_ExecDirectory/$INSTALL_BIN_NAME

  if [ -e "$TARGET_BIN" ]; then

    nsh_cmp "$SOURCE_BIN" "$TARGET_BIN"
    if [ $? -eq 0 ]; then
      return 0
    fi

    if [ ! -w "$TARGET_BIN" ]; then
      echo "Error - Can not update binary '$TARGET_BIN' -- No write permissions"
      return 1
    fi

    echo "Updating '$TARGET_BIN'"
  else
    echo "Installing '$TARGET_BIN'"
  fi

  cp -f "$SOURCE_BIN" "$TARGET_BIN"
  chmod 755 "$TARGET_BIN"


  case "$INSTALL_BIN_NAME" in
    *.so)
      ;;

    *)
      CURRENT_DIR=$(pwd)
      cd $LOTUS/bin
      ln -f -s tools/startup "$INSTALL_BIN_NAME"
      cd $CURRENT_DIR
      ;;

  esac

  return 0
}

secure_move_file()
{
  # Routine to move a file with proper error checks and warnings

  # Check if source file is present
  if [ ! -e "$1" ]; then
    log_error "Cannot rename [$1] - file does not exist"
    return 1
  fi

  # Check if target already exist and try to remove first
  if [ -e "$2" ]; then

    rm -f "$2" > /dev/null 2>&1

    if [ -e "$2" ]; then
      log_error "Cannot rename [$1] to [$2]  - target cannot be removed"
      return 1
    else
      log_ok "Replacing file [$2] with [$1]"
    fi

  else
    log_ok "Renaming file [$1] to [$2]"
  fi

  # Now copy file
  cp -f "$1" "$2" > /dev/null 2>&1

  if [ -e "$2" ]; then

    # Try to remove source file after copy
    rm -f "$1" > /dev/null 2>&1

    if [ -e "$1" ]; then
      log_ok "Warning: cannot remove source file [$1]"
    fi

    return 0

  else
    log_error "Cannot copy file [$1] to [$2]"
    return 1
  fi
}

create_directory()
{
  local TARGET_FILE=$1
  local OWNER=$2
  local GROUP=$3
  local PERMS=$4

  if [ -z "$TARGET_FILE" ]; then
    return 0
  fi

  if [ -e "$TARGET_FILE" ]; then
    return 0
  fi

  mkdir -p "$TARGET_FILE"

  if [ -n "$OWNER" ]; then
    chown $OWNER:$GROUP "$TARGET_FILE"
  fi

  if [ -n "$PERMS" ]; then
    chmod "$PERMS" "$TARGET_FILE"
  fi

  return 0
}

remove_directory()
{
  if [ -z "$1" ]; then
    return 1
  fi

  if [ ! -e "$1" ]; then
    return 2
  fi

  rm -rf "$1"

  if [ -e "$1" ]; then
    echo " --- Directory not completely deleted! ---"
    ls -l "$1"
    echo " --- Directory not completely deleted! ---"
  fi

  return 0
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

install_files_from_dir()
{
  local SOURCE_DIR=$1
  local TARGET_DIR=$2
  local OWNER=$3
  local GROUP=$4
  local PERMS=$5
  local DIRPERMS=$6

  local CURRENT_FILE=
  local CURRENT_TARGET_DIR=
  local TARGET_FILE=

  if [ -z "$SOURCE_DIR" ]; then
    return 0
  fi

  if [ -z "$TARGET_DIR" ]; then
    return 0
  fi

  if [ ! -e "$SOURCE_DIR" ]; then
    return 0
  fi

  find "$SOURCE_DIR/" -type f -printf "%P\n" | while read CURRENT_FILE; do

    TARGET_FILE="$TARGET_DIR/$CURRENT_FILE"
    CURRENT_TARGET_DIR="$(dirname "$TARGET_FILE")"

    create_directory "$CURRENT_TARGET_DIR" "$OWNER" "$GROUP" "$DIRPERMS"
    echo "Installing file: [$SOURCE_DIR/$CURRENT_FILE] -> [$TARGET_FILE]"
    install_file "$SOURCE_DIR/$CURRENT_FILE" "$TARGET_FILE" "$OWNER" "$GROUP" "$PERMS"
  done
}

create_servertask_links()
{
  local TASKNAME=

  if [ -z "$1" ]; then
    return 0
  fi

  if [ ! -e "$1" ]; then
    return 0
  fi

  cat "$1" | while read TASKNAME; do
    if [ ! -e "$LOTUS/bin/$TASKNAME" ]; then
      echo "Creating link [$LOTUS/bin/tools/startup] -> [$LOTUS/bin/$TASKNAME]"
      ln -s "$LOTUS/bin/tools/startup" "$LOTUS/bin/$TASKNAME"
    fi
  done
}

get_notes_ini_var()
{
  # $1 = filename
  # $2 = ini.variable

  ret_ini_var=""
  if [ -z "$1" ]; then
    return 0
  fi

  if [ ! -r "$1" ]; then
    echo "cannot read [$1]"
    return 0
  fi

  if [ -z "$2" ]; then
    return 0
  fi

  ret_ini_var=$(awk -F '(=| =)' -v SEARCH_STR="$2" '{if (tolower($1) == tolower(SEARCH_STR)) print $2}' $1 | xargs)
  return 0
}

set_notes_ini_var()
{
  # updates or sets notes.ini parameter
  file=$1
  var=$2
  new=$3

  if [ ! -w "$file" ]; then
    echo "cannot write [$file]"
    return 0
  fi

  get_notes_ini_var "$file" "$var"

  if [ "$ret_ini_var" = "$new" ]; then
    return 0
  fi

  # check if entry exists empty. if not present just append new entry, else use replace code
  if [ -z "$ret_ini_var" ]; then
    found=$(grep -i "^$var=" $file)
    if [ -z "$found" ]; then
      echo $var=$new >> $file
      return 0
    fi
  fi

  awk -v var="$var" -v new="$new" 'BEGIN{FS=OFS="=";IGNORECASE=1}match($1,"^"var"$") {$2=new}1' "$file" > $file.updated
  mv $file.updated $file

  return 0
}

add_list_ini()
{
  # appends entry to ini list
  file=$1
  var=$2
  param=$3

  get_notes_ini_var "$file" "$var"

  if [ -z "$ret_ini_var" ]; then
    set_notes_ini_var "$file" "$var" "$param"
    # echo "entry [$param] set"
    return 1
  fi

  for CHECK_ENTRY in $(echo "$ret_ini_var" | awk '{print tolower($0)}' | tr "," "\n") ; do
    if [ $CHECK_ENTRY = "$param" ]; then
      # echo "entry [$param] already set"
      return 0
    fi
  done

  set_notes_ini_var "$file" "$var" "$ret_ini_var,$param"
  # echo "entry [$param] added"

  return 1
}

remove_list_ini()
{
  # remove entry to ini list
  file=$1
  var=$2
  param=$3
  found=
  newlist=

  get_notes_ini_var "$file" "$var"

  if [ -z "$ret_ini_var" ]; then
    # echo "entry [$var] empty"
    return 0
  fi

  for CHECK_ENTRY in $(echo "$ret_ini_var" | awk '{print tolower($0)}' | tr "," "\n") ; do
    if [ $CHECK_ENTRY = "$param" ]; then
      found=YES
    else
      if [ -z "$newlist" ]; then
        newlist="$CHECK_ENTRY"
      else
        newlist="$newlist,$CHECK_ENTRY"
      fi
    fi
  done

  if [ -z "$found" ]; then
    # echo "entry [$param] not found"
    return 0
  fi

  set_notes_ini_var "$file" "$var" "$newlist"
  # echo "entry [$param] removed"

  return 0
}

remove_notes_ini_var()
{
  # updates or sets notes.ini parameter
  file=$1
  var=$2

  found=$(grep -i "^$var=" $file)
  echo "found: [$found]"
  if [ -z "$found" ]; then
    return 0
  fi

  grep -v -i "^$var=" $file > $file.updated
  mv $file.updated $file

  return 0
}

create_link ()
{
  SOURCE_FILE=$1
  TARGET_FILE=$2

  if [ -e "$SOURCE_FILE" ]; then
    if [ ! -e "$TARGET_FILE" ]; then
      ln -s "$SOURCE_FILE" "$TARGET_FILE"
      if [ -e "$TARGET_FILE" ]; then
         echo "Created link '$SOURCE_FILE' -> '$TARGET_FILE'"
      else
         echo "Cannot create link '$SOURCE_FILE' -> '$TARGET_FILE'"
      fi
    fi
  else
    echo "Cannot create link - file not found '$SOURCE_FILE'"
  fi

  return 0
}


install_res_links()
{
  local DOMINO_RES_DIR=$Notes_ExecDirectory/res
  local GERMAN_LOCALE="de_DE"
  local ENGLISH_LOCALE="en_US"
  local GERMAN_LOCALE_UTF8="${GERMAN_LOCALE}.UTF-8"
  local ENGLISH_LOCALE_UTF8="${ENGLISH_LOCALE}.UTF-8"
  local CURRENT_DIR=$(pwd)

  cd $DOMINO_RES_DIR

  if [ ! -e "$DOMINO_RES_DIR/C" ]; then
    echo "Error: No default locate res files found ($DOMINO_RES_DIR/C)"
    return 1
  fi

  if [ ! -e "$DOMINO_RES_DIR/$GERMAN_LOCALE" ]; then
    echo "Creating symbolic link for German res files ($GERMAN_LOCALE)"
    ln -s C $GERMAN_LOCALE
  fi

  if [ ! -e "$DOMINO_RES_DIR/$ENGLISH_LOCALE" ]; then
    echo "Creating symbolic link for English res files ($ENGLISH_LOCALE)"
    ln -s C $ENGLISH_LOCALE
  fi

  if [ ! -e "$DOMINO_RES_DIR/$GERMAN_LOCALE_UTF8" ]; then
    echo "Creating symbolic link for German res files ($GERMAN_LOCALE_UTF8)"
    ln -s C $GERMAN_LOCALE_UTF8
  fi

  if [ ! -e "$DOMINO_RES_DIR/$ENGLISH_LOCALE_UTF8" ]; then
    echo "Creating symbolic link for English res files ($ENGLISH_LOCALE_UTF8)"
    ln -s C $ENGLISH_LOCALE_UTF8
  fi

  cd "$CURRENT_DIR"
  return 0
}

create_startup_link()
{
  if [ -z "$1" ]; then
    return 0
  fi

  TARGET_PATH=$LOTUS/bin/$1
  SOURCE_PATH=$LOTUS/bin/tools/startup

  if [ ! -e "$TARGET_PATH" ]; then
    ln -f -s $SOURCE_PATH $TARGET_PATH
    echo "Installed startup link for [$1]"
  fi

  return 0
}

get_domino_version()
{
  # In case PROD_VER contains an underscore, use this explicitly specified product version (daily builds)
  # Also for Early Access builds overwriting the version is important to update templates
  case "$PROD_VER" in

    *_*|*EA*)
      DOMINO_VERSION=$PROD_VER
      return 0
      ;;
  esac

  DOMINO_INSTALL_DAT=$LOTUS/.install.dat

  if [ -e $DOMINO_INSTALL_DAT ]; then

    find_str=$(tail "$DOMINO_INSTALL_DAT" | grep "rev = " | awk -F " = " '{print $2}' | tr -d '"')

    if [ -n "$find_str" ]; then
      DOMINO_VERSION=$find_str

      # Fix Domino version for older releases. Current releases have proper "rev" entries

      if [ "$DOMINO_VERSION" = "11000000" ]; then
        DOMINO_VERSION=1100
      fi

      if [ "$DOMINO_VERSION" = "10000000" ]; then
        DOMINO_VERSION=1001
      fi

      if [ "$DOMINO_VERSION" = "90010" ]; then
        DOMINO_VERSION=901
      fi

    else
      DOMINO_VERSION="UNKNOWN"
    fi
  else
    DOMINO_VERSION="NONE"
  fi

  return 0
}

set_domino_version()
{
  # Domino version is updated after each install part (ver, fp, if/hf)
  get_domino_version
  echo $DOMINO_VERSION > $DOMDOCK_TXT_DIR/domino_$1.txt
  echo $DOMINO_VERSION > $DOMINO_DATA_PATH/domino_$1.txt
}

check_installed_version()
{
  VersionFile=$DOMDOCK_TXT_DIR/domino_$1.txt

  if [ ! -r $VersionFile ]; then
    return 0
  fi

 CHECK_VERSION=$(cat $VersionFile)
 INSTALL_VERSION=$(echo $2 | tr -d '.')

 if [ "$CHECK_VERSION" = "$INSTALL_VERSION" ]; then
   log_space "Domino $INSTALL_VERSION already installed"
   return 1
 else
   return 0
 fi

}

set_version()
{
  echo $PROD_VER > "$DOMDOCK_TXT_DIR/${PROD_NAME}_ver.txt"
  echo $PROD_VER > "$DOMINO_DATA_PATH/${PROD_NAME}_ver.txt"
}

set_ini_var_if_not_set()
{
  local file=$1
  local var=$2
  local new=$3

  # check if entry exists empty. if not present append new entry

  local found=$(grep -i "^$var=" $file)
  if [ -z "$found" ]; then
    echo $var=$new >> $file
  fi

  return 0
}

install_package()
{

  # Ensure only packages are installed which are not on the skip or remove list
  local PACKAGE=

  for PACKAGE in $LINUX_PKG_REMOVE; do
    case "$@" in
      ${PACKAGE}*)
	echo "Skipping package install: $@"
        return 0;
        ;;
    esac
  done

  for PACKAGE in $LINUX_PKG_SKIP; do
    case "$@" in
      ${PACKAGE}*)
        echo "Skipping package install: $@"
        return 0;
        ;;
    esac
  done

  if [ -x /usr/bin/zypper ]; then
    /usr/bin/zypper install -y "$@"

  elif [ -x /usr/bin/dnf ]; then
    /usr/bin/dnf install -y "$@"

  elif [ -x /usr/bin/tdnf ]; then
    /usr/bin/tdnf install -y "$@"

  elif [ -x /usr/bin/microdnf ]; then
    /usr/bin/microdnf install -y "$@"

  elif [ -x /usr/bin/yum ]; then
    /usr/bin/yum install -y "$@"

  elif [ -x /usr/bin/apt-get ]; then
    /usr/bin/apt-get install -y "$@"

  elif [ -x /usr/bin/pacman ]; then
    /usr/bin/pacman --noconfirm -Sy "$@"

  elif [ -x /sbin/apk ]; then
    /sbin/apk add "$@"

  else
    log_error "No package manager found!"
    exit 1
  fi

  echo "$@" >> /tmp/install_package.log
}

install_packages()
{
  local PACKAGE=
  for PACKAGE in $*; do
    install_package $PACKAGE
  done
}

remove_package()
{
  if [ -x /usr/bin/zypper ]; then
    /usr/bin/zypper rm -y "$@"

  elif [ -x /usr/bin/dnf ]; then
    /usr/bin/dnf remove -y "$@"

  elif [ -x /usr/bin/tdnf ]; then
    /usr/bin/tdnf remove -y "$@"

  elif [ -x /usr/bin/microdnf ]; then
    /usr/bin/microdnf remove -y "$@"

  elif [ -x /usr/bin/yum ]; then
    /usr/bin/yum remove -y "$@"

  elif [ -x /usr/bin/apt-get ]; then
    /usr/bin/apt-get remove -y "$@"

  elif [ -x /usr/bin/pacman ]; then
    /usr/bin/pacman --noconfirm -R "$@"

  elif [ -x /sbin/apk ]; then
      /sbin/apk del "$@"
  fi

  echo "$@" >> /tmp/remove_package.log
}

remove_packages()
{
  local PACKAGE=
  for PACKAGE in $*; do
    remove_package $PACKAGE
  done
}

install_if_missing()
{
  local PACKAGE=$1

  if [ -z "$1" ]; then
    return 0
  fi

  if [ -x "/usr/bin/$1" ] || [ -x "/usr/local/bin/$1" ]; then
    log_space "Already installed: $1"
    return 0
  fi

  if [ -n "$2" ]; then
    PACKAGE=$2
  fi

  install_package "$PACKAGE"

  if [ -x "/usr/bin/$1" ] || [ -x "/usr/local/bin/$1" ]; then
    log_space "Successfully installed: $PACKAGE"
    return 0
  fi

  if [ -z "$3" ]; then
    return 0
  fi

  PACKAGE=$3

  install_package "$PACKAGE"

  if [ -x "/usr/bin/$1" ] || [ -x "/usr/local/bin/$1" ]; then
    log_space "Successfully installed: $PACKAGE"
    return 0
  fi
}

check_linux_update()
{

  # On Ubuntu and Debian update the cache in any case to be able to install additional packages
  if [ -x /usr/bin/apt-get ]; then
    header "Refreshing packet list via apt-get"
    /usr/bin/apt-get update -y
  fi

  if [ -x /usr/bin/pacman ]; then
    header "Refreshing packet list via pacman"
    pacman --noconfirm -Sy
  fi

  # Install Linux updates if requested
  if [ ! "$LinuxYumUpdate" = "yes" ]; then
    return 0
  fi

  if [ -x /usr/bin/zypper ]; then

    header "Updating Linux via zypper"
    /usr/bin/zypper refresh
    /usr/bin/zypper update -y

  elif [ -x /usr/bin/dnf ]; then

    header "Updating Linux via dnf"
    /usr/bin/dnf update -y

  elif [ -x /usr/bin/tdnf ]; then

    header "Updating Linux via tdnf"
    /usr/bin/tdnf update -y

  elif [ -x /usr/bin/microdnf ]; then

    header "Updating Linux via microdnf"
    /usr/bin/microdnf update -y

  elif [ -x /usr/bin/yum ]; then

    header "Updating Linux via yum"
    /usr/bin/yum update -y

  elif [ -x /usr/bin/apt-get ]; then

    header "Updating Linux via apt"
    echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

    /usr/bin/apt-get update -y

    # Needed by Astra Linux, Ubuntu and Debian. Should be installed before updating Linux but after updating the repo!
    if [ -x /usr/bin/apt-get ]; then
      install_package apt-utils
    fi

    /usr/bin/apt-get upgrade -y

  elif [ -x /usr/bin/pacman ]; then
    header "Updating Linux via pacman"
    pacman --noconfirm -Syu

  elif [ -x /sbin/apk ]; then
    header "Updating Linux via apk"
    /sbin/apk update

  else
    log_error "No packet manager to update Linux"
  fi
}

clean_linux_repo_cache()
{
  if [ -x /usr/bin/zypper ]; then

    header "Cleaning zypper cache"
    /usr/bin/zypper clean --all >/dev/null
    rm -fr /var/cache

  elif [ -x /usr/bin/dnf ]; then

    header "Cleaning dnf cache"
    /usr/bin/dnf clean all >/dev/null

  elif [ -x /usr/bin/tdnf ]; then

    header "Cleaning tdnf cache"
    /usr/bin/tdnf clean all >/dev/null

  elif [ -x /usr/bin/microdnf ]; then

    header "Cleaning microdnf cache"
    /usr/bin/microdnf clean all >/dev/null

  elif [ -x /usr/bin/yum ]; then

    header "Cleaning yum cache"
    /usr/bin/yum clean all >/dev/null
    rm -fr /var/cache/yum

  elif [ -x /usr/bin/apt-get ]; then

    header "Cleaning apt cache"
    /usr/bin/apt-get clean

  elif [ -x /usr/bin/pacman ]; then
     header "Cleaning pacman cache"
     pacman --noconfirm -Sc

  else
    log_error "Warning: No packet manager to clear repo cache!"
  fi
}

install_custom_packages()
{
  if [ -n "$LinuxAddOnPackages" ]; then
    install_packages "$LinuxAddOnPackages"
  fi
}

debug_show_data_dir()
{
  if [ ! "$DOMDOCK_DEBUG" = "yes" ]; then
    return 0
  fi

  echo
  echo "----------------------------[$@] ------------------------------"
  ls -l /local
  echo "----------------------------[$@] ------------------------------"
  echo

  if [ -z "$LOG_FILE" ]; then
    return 0
  fi

  echo >> $LOG_FILE
  echo "-----------------------------[$@]------------------------------" >> $LOG_FILE
  ls -l /local >> $LOG_FILE
  echo "-----------------------------[$@]------------------------------" >> $LOG_FILE
  echo >> $LOG_FILE
}

set_sh_shell()
{
  ORIG_SHELL_LINK=$(readlink /bin/sh)

  if [ -z "$1" ]; then
     log_ok "Current sh: [$ORIG_SHELL_LINK]"
     ORIG_SHELL_LINK=
     return 0
  fi

  if [ "$ORIG_SHELL_LINK" = "$1" ]; then
    ORIG_SHELL_LINK=
    return 0
  fi

  log_ok "Switching sh shell from [$ORIG_SHELL_LINK] to [$1]"

  local SAVED_DIR=$(pwd)
  cd /bin
  ln -sf "$1" sh
  cd "$SAVED_DIR"

  return 1
}

download_and_decrypt()
{
  # Download and decrypt file
  # $1 = Output File (fails when file already exists)
  # $2 = Download URL
  # $3 = Password or password URL (if empty decode base64 only)
  # $4 = Verification hash SHA256 (lower case)
  # Returns: 0 = Success, else error status

  local OUTFILE="$1"
  local URL="$2"
  local PW_IN="$3"
  local HASH_IN="$4"

  if [ -z "$URL" ] || [ -z "$OUTFILE" ]; then
    return 1
  fi

  if [ -e "$OUTFILE" ]; then
    log_error "Download file already exists [$OUTFILE]"
    return 2
  fi

  if [ -z "$PW_IN" ] || [ "." = "$PW_IN" ] ; then
    # Only download and decode base64 if password is empty
    $CURL_CMD -s "$URL" | openssl enc -d -base64 -d -out "$OUTFILE"

  else
    case "$PW_IN" in

      http:*|https:*)
        export PW=$($CURL_CMD -s "$PW_IN")
        ;;

      *)
        export PW="$PW_IN"
        ;;
    esac

    if [ -z "$PW" ]; then
      log_error "No download password returned for download file [$OUTFILE]!"
      return 3
    fi

    # Download and decrypt
    $CURL_CMD -s "$URL" | openssl enc -d -a -aes-256-cbc -pbkdf2 -pass env:PW -out "$OUTFILE"
  fi

  # Save return code first and nuke password
  local ret=$?
  export PW=

  if [ "0" != "$ret" ]; then
    log_error "Cannot decrypt download file [$OUTFILE]"

    if [ -e "$OUTFILE" ]; then
      rm -f "$OUTFILE"
    fi
    return 4
  fi

  if [ ! -e "$OUTFILE" ]; then
    log_error "No decrypted download file found [$OUTFILE]"
    rm -f "$OUTFILE"
    return 5
  fi

  # Optionally verify the file hash
  if [ -n "$HASH_IN" ]; then
    local HASH=$(sha256sum -b $OUTFILE | cut -f1 -d" ")

    if [ "$HASH_IN" != "$HASH" ]; then
      log_error "Download hash does not match for [$OUTFILE] - Current Hash: [$HASH], Hash expected: [$HASH_IN]"
      rm -f "$OUTFILE"
      return 6
    fi
  fi

  return 0
}

install_mysql_client()
{

  local ADDON_NAME="MySQL Client"
  header "$ADDON_NAME Installation"

  $CURL_CMD -LO https://repo.mysql.com/mysql80-community-release-el9-1.noarch.rpm
  rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2022

  install_package mysql80-community-release-el9-1.noarch.rpm
  install_package mysql
  install_package mysql-connector-odbc.x86_64

  # Add symbolic link to ensure driver is found
  ln -s -T /usr/lib64/libodbc.so.2.0.0 /usr/lib64/libodbc.so

  log_space Installed $ADDON_NAME
}

install_mssql_client()
{

  local ADDON_NAME="Microsoft SQL Server Client"
  header "$ADDON_NAME Installation"

  $CURL_CMD https://packages.microsoft.com/config/rhel/8/prod.repo > /etc/yum.repos.d/mssql-release.repo

  ACCEPT_EULA=Y install_package msodbcsql18
  ACCEPT_EULA=Y install_package mssql-tools18

  echo >> /etc/bashrc
  echo 'PATH="$PATH:/opt/mssql-tools18/bin"' >> /etc/bashrc

  log_space Installed $ADDON_NAME
}


install_linux_trusted_root()
{
  if [ -z "$1" ]; then
     return 0
  fi

  # In case OpenSSL is not installed in base image
  if [ ! -e "/usr/bin/openssl" ]; then
    install_package openssl
  fi

  header "Install trusted root on Linux level"

  if [ ! -e "$1" ]; then
    log_error "Cannot find specified trusted root: [$1]"
    return 0
  fi

  # Dump certificate in PEM and text
  header "Root Certificate Information"
  openssl x509 -in "$1" -text -noout

  header "Root Certificate in PEM format"
  openssl x509 -in "$1"

  echo

  header "Updating Linux Certs"

  if [ -e /etc/photon-release ]; then
    # Photon OS requires uses a different mechanism
    install_package openssl-c_rehash
    cp -f "$1" /etc/ssl/certs/
    rehash_ca_certificates.sh

  elif [ -x /usr/bin/zypper ]; then
    cp -f "$1" /usr/share/pki/trust/anchors
    update-ca-certificates

  elif [ -x /usr/bin/apt-get ]; then
    install_package ca-certificates
    cp -f "$1" /usr/local/share/ca-certificates

    # Certs must have the .crt extension
    mv /usr/local/share/ca-certificates/*.pem /usr/local/share/ca-certificates/*.crt
    update-ca-certificates

  else
    cp -f "$1" /etc/pki/ca-trust/source/anchors
    update-ca-trust
  fi

  echo
}


install_domino_trusted_root()
{
  if [ -z "$1" ]; then
     return 0
  fi

  local DOMINO_TRUSTED_ROOT_NAME="Custom Domino Container imported Root"

  # Dump certificate in PEM and text
  header "Root Certificate Information"
  openssl x509 -in "$1" -text -noout

  header "Root Certificate in PEM format"
  openssl x509 -in "$1"
  echo
  echo

  # Import cert into Domino trusted roots
  echo  >> $DOMINO_DATA_PATH/cacert.pem
  echo "$DOMINO_TRUSTED_ROOT_NAME" >> $DOMINO_DATA_PATH/cacert.pem

  echo "=====================================" >> $DOMINO_DATA_PATH/cacert.pem
  openssl x509 -in "$1" >> $DOMINO_DATA_PATH/cacert.pem
  echo
  echo

  header "Import cert into Domino JVM trust store"
  # Import cert into Domino Java trusted roots
  "$Notes_ExecDirectory/jvm/bin/keytool" -import -trustcacerts -noprompt -keystore "$Notes_ExecDirectory/jvm/lib/security/cacerts" -storepass changeit -alias "$DOMINO_TRUSTED_ROOT_NAME" -file "$1"
  echo
  echo

  # Log trusted root imported
  openssl x509 -in "$1" -text >> $DOMDOCK_DIR/DominoImportedTrustedRoots.pem
}

