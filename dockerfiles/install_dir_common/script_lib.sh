#!/bin/bash
############################################################################
# Copyright Nash!Com, Daniel Nashed 2019, 2022 - APACHE 2.0 see LICENSE
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
export DOMDOCK_LOG_DIR=/tmp/domino-container
export DOMDOCK_INSTALL_DATA_TAR=$DOMDOCK_DIR/install_data_domino.taz

# Ensure the environment is setup
export LOTUS=/opt/hcl/domino
export Notes_ExecDirectory=$LOTUS/notes/latest/linux
export NUI_NOTESDIR=$LOTUS
export PATH=$PATH:$DOMINO_DATA_PATH
export SOFTWARE_FILE=$INSTALL_DIR/software.txt

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

header()
{
  echo
  print_delim
  echo "$1"
  print_delim
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

download_and_check_hash()
{
  DOWNLOAD_SERVER=$1
  DOWNLOAD_STR=$2
  TARGET_DIR=$3
  TARGET_FILE=$4

  # check if file exists before downloading

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
    exit 1
  fi

  CURRENT_DIR=$(pwd)

  if [ -n "$TARGET_DIR" ]; then
    mkdir -p "$TARGET_DIR"
    cd "$TARGET_DIR"
  fi

  if [[ "$DOWNLOAD_FILE" =~ ".tar.gz" ]]; then
    TAR_OPTIONS=xz
  elif [[ "$DOWNLOAD_FILE" =~ ".taz" ]]; then
    TAR_OPTIONS=xz
  elif [[ "$DOWNLOAD_FILE" =~ ".tar" ]]; then
    TAR_OPTIONS=x
  else
    TAR_OPTIONS=""
  fi

  if [ -z "$TAR_OPTIONS" ]; then

    # download without extracting for none tar files

    echo
    if [ -z "$TARGET_FILE" ]; then
      TARGET_FILE=$(basename $DOWNLOAD_FILE)
    fi

    $CURL_CMD "$DOWNLOAD_FILE" -o "$TARGET_FILE"

    if [ ! -e "$TARGET_FILE" ]; then
      log_error "File [$DOWNLOAD_FILE] not downloaded [1]"
      exit 1
    fi

    HASH=$(sha256sum -b $TARGET_FILE | cut -f1 -d" ")
    FOUND=$(grep "$HASH" "$SOFTWARE_FILE" | grep "$CURRENT_FILE" | wc -l)

    # Download file can be present more than once (e.g. IF/HF). Perfectly OK as long the hash matches.
    if [ "$FOUND" = "0" ]; then
      log_error "File [$DOWNLOAD_FILE] not downloaded correctly [1]"
      dump_download_error
      exit 1
    else
      log_ok "Successfully downloaded: [$DOWNLOAD_FILE] "
    fi

  else
    if [ -e $SOFTWARE_FILE ]; then
      echo
      HASH=$($CURL_CMD $DOWNLOAD_FILE | tee >(tar $TAR_OPTIONS 2>/dev/null) | sha256sum -b | cut -d" " -f1)
      echo
      FOUND=$(grep "$HASH" "$SOFTWARE_FILE" | grep "$CURRENT_FILE" | wc -l)

      if [ "$FOUND" = "1" ]; then
        log_ok "Successfully downloaded, extracted & checked: [$DOWNLOAD_FILE] "
      else
        log_error "File [$DOWNLOAD_FILE] not downloaded correctly [2]"
        dump_download_error
        exit 1
      fi
    else
      echo
      $CURL_CMD $DOWNLOAD_FILE | tar $TAR_OPTIONS 2>/dev/null
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

    check_file_busy "$TARGET_FILE"

    if [ $? -eq 1 ]; then
      echo "[$TARGET_FILE] Error - Can not update file -- Binary in use"
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

    check_file_busy "$TARGET_BIN"

    if [ $? -eq 1 ]; then
      echo "Error - Can not update binary '$TARGET_BIN' -- Binary in use"
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
  TARGET_FILE=$1
  OWNER=$2
  GROUP=$3
  PERMS=$4

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

  rm -rf "$1"
  return 0
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

install_res_links()
{
  DOMINO_RES_DIR=$Notes_ExecDirectory/res
  GERMAN_LOCALE="de_DE.UTF-8"
  ENGLISH_LOCALE="en_US.UTF-8"

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
  DOMINO_INSTALL_DAT=$LOTUS/.install.dat

  if [ -e $DOMINO_INSTALL_DAT ]; then

    find_str=$(tail "$DOMINO_INSTALL_DAT" | grep "rev = " | awk -F " = " '{print $2}' | tr -d '"')

    if [ -n "$find_str" ]; then
      DOMINO_VERSION=$find_str

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
  get_domino_version
  echo $PROD_VER > $DOMDOCK_TXT_DIR/domino_$1.txt
  echo $PROD_VER > $DOMINO_DATA_PATH/domino_$1.txt
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
   echo "Domino $INSTALL_VERSION already installed"
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
 if [ -x /usr/bin/zypper ]; then
   zypper install -y "$@"

 elif [ -x /usr/bin/dnf ]; then
   dnf install -y "$@"

 elif [ -x /usr/bin/yum ]; then
   yum install -y "$@"

 elif [ -x /usr/bin/apt-get ]; then
   apt-get install -y "$@"

 else
  echo "No package manager found!"
  exit 1

 fi
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
   zypper rm -y "$@"

 elif [ -x /usr/bin/dnf ]; then
   dnf remove -y "$@"

 elif [ -x /usr/bin/yum ]; then
   yum remove -y "$@"

 elif [ -x /usr/bin/apt-get ]; then
   apt-get remove -y "$@"

 fi
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
  if [ -z "$1" ]; then
    return 0
  fi

  if [ -x  "/usr/bin/$1" ]; then
    echo "already exists: $1"
    return 0
  fi

  if [ -x "/usr/local/bin/$1" ]; then
    return 0
  fi

  if [ -z "$2" ]; then
    install_package "$1"
  else
    install_package "$2"
  fi
}

check_linux_update()
{
  # Install Linux updates if requested
  if [ ! "$LinuxYumUpdate" = "yes" ]; then
    return 0
  fi

  if [ -x /usr/bin/zypper ]; then

    header "Updating Linux via zypper"
    zypper refresh
    zypper update -y

  elif [ -x /usr/bin/dnf ]; then

    header "Updating Linux via dnf"
    dnf update -y

  elif [ -x /usr/bin/yum ]; then

    header "Updating Linux via yum"
    yum update -y

  elif [ -x /usr/bin/apt-get ]; then

    header "Updating Linux via apt-get"
    apt-get update -y

    # Needed by Astra Linux, Ubuntu and Debian. Should be installed before updating Linux but after updating the repo!
    if [ -x /usr/bin/apt-get ]; then
      install_package apt-utils
    fi

    apt-get upgrade -y

  fi
}

clean_linux_repo_cache()
{
  if [ -x /usr/bin/zypper ]; then

    header "Cleaning zypper cache"
    zypper clean --all >/dev/null
    rm -fr /var/cache

  elif [ -x /usr/bin/dnf ]; then

    header "Cleaning dnf cache"
    dnf clean all >/dev/null

  elif [ -x /usr/bin/yum ]; then

    header "Cleaning yum cache"
    yum clean all >/dev/null
    rm -fr /var/cache/yum

  elif [ -x /usr/bin/apt-get ]; then

    header "Cleaning apt cache"
    apt-get clean
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
  if [ -z "$DEBUG" ]; then
    return 0
  fi

  echo
  echo "----------------------------[$@] ------------------------------"
  ls -l /local
  echo "----------------------------[$@] ------------------------------"
  echo

  log_ok
  log_ok "-----------------------------[$@]------------------------------"
  ls -l /local >> $LOG_FILE
  log_ok "-----------------------------[$@]------------------------------"
  log_ok
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
