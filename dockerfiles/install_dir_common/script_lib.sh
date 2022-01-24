#!/bin/bash
############################################################################
# Copyright Nash!Com, Daniel Nashed 2019, 2022 - APACHE 2.0 see LICENSE
# Copyright IBM Corporation 2015, 2019 - APACHE 2.0 see LICENSE
############################################################################

if [ -z "$CURL_CMD" ]; then
  CURL_CMD="curl --fail --location --connect-timeout 15 --max-time 300 $SPECIAL_CURL_ARGS"
fi

if [ -z "$DIR_PERM" ]; then
  DIR_PERM=770
fi

# Helper Functions

print_delim ()
{
  echo "--------------------------------------------------------------------------------"
}

log_ok ()
{
  echo "$@"
}

log_space ()
{
  echo
  echo "$@"
  echo
}

log_error ()
{
  echo
  echo "Failed - $@"
  echo
}

header ()
{
  echo
  print_delim
  echo "$1"
  print_delim
  echo
}

install_package()
{
 if [ -x /usr/bin/zypper ]; then

   zypper install -y "$@"

 elif [ -x /usr/bin/yum ]; then

   yum install -y "$@"

 fi
}

remove_package()
{
 if [ -x /usr/bin/zypper ]; then
   zypper rm -y "$@"

 elif [ -x /usr/bin/yum ]; then
   yum remove -y "$@"

 fi
}

check_file_str ()
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

get_download_name ()
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

download_file_ifpresent ()
{
  CURRENT_DIR=
  DOWNLOAD_SERVER=$1
  DOWNLOAD_FILE=$2
  TARGET_DIR=$3

  if [ -z "$DOWNLOAD_FILE" ]; then
    log_error "No download file specified!"
    exit 1
  fi

  CURL_RET=$($CURL_CMD "$DOWNLOAD_SERVER/$DOWNLOAD_FILE" --silent --head 2>&1)
  STATUS_RET=$(echo $CURL_RET | grep 'HTTP/1.1 200 OK')
  if [ -z "$STATUS_RET" ]; then

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

  cd $CURRENT_DIR

  if [ "$?" = "0" ]; then
    log_ok "Successfully downloaded: [$DOWNLOAD_FILE] "
    echo
    return 0

  else
    log_error "File [$DOWNLOAD_FILE] not downloaded correctly"
    echo "CURL returned: [$CURL_RET]"
    exit 1
  fi
}

download_and_check_hash ()
{
  DOWNLOAD_SERVER=$1
  DOWNLOAD_STR=$2
  TARGET_DIR=$3

  if [ -z "$DOWNLOAD_FILE" ]; then
    log_error "No download file specified!"
    exit 1
  fi

  # check if file exists before downloading

  for CHECK_FILE in $(echo "$DOWNLOAD_STR" | tr "," "\n" ) ; do

    DOWNLOAD_FILE=$DOWNLOAD_SERVER/$CHECK_FILE
    CURL_RET=$($CURL_CMD "$DOWNLOAD_FILE" --silent --head 2>&1)
    STATUS_RET=$(echo $CURL_RET | grep 'HTTP/1.1 200 OK')

    if [ -n "$STATUS_RET" ]; then
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
    DOWNLOADED_FILE=$(basename $DOWNLOAD_FILE)
    $CURL_CMD "$DOWNLOAD_FILE" -o "$DOWNLOADED_FILE"

    if [ ! -e "$DOWNLOADED_FILE" ]; then
      log_error "File [$DOWNLOAD_FILE] not downloaded [1]"
      exit 1
    fi

    HASH=$(sha256sum -b $DOWNLOADED_FILE | cut -f1 -d" ")
    FOUND=$(grep "$HASH" "$SOFTWARE_FILE" | grep "$CURRENT_FILE" | wc -l)

    if [ "$FOUND" = "1" ]; then
      log_ok "Successfully downloaded: [$DOWNLOAD_FILE] "
    else
      log_error "File [$DOWNLOAD_FILE] not downloaded correctly [1]"
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

create_directory ()
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

remove_directory ()
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

remove_file ()
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

install_res_links ()
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

create_startup_link ()
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

get_domino_version ()
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

set_domino_version ()
{
  get_domino_version
  echo $PROD_VER > $DOMDOCK_TXT_DIR/domino_$1.txt
  echo $PROD_VER > $DOMINO_DATA_PATH/domino_$1.txt
}

check_installed_version ()
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

set_version ()
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

check_linux_update()
{
  # Install Linux updates if requested
  if [ "$LinuxYumUpdate" = "yes" ]; then

    if [ -x /usr/bin/zypper ]; then

      header "Updating Linux via zypper"
      zypper refersh -y
      zypper update -y

    elif [ -x /usr/bin/yum ]; then

      header "Updating Linux via yum"
      yum update -y

    fi
  fi
}

clean_linux_repo_cache()
{
    if [ -x /usr/bin/zypper ]; then

      header "Cleaning zypper cache"
      zypper clean --all >/dev/null
      rm -fr /var/cache

    elif [ -x /usr/bin/yum ]; then

      header "Cleaning yum cache"
      yum clean all >/dev/null
      rm -fr /var/cache/yum

    fi
}

install_custom_packages()
{
  if [ -n "$LinuxAddOnPackages" ]; then
    install_package "$LinuxAddOnPackages"
  fi
}

