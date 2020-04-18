#!/bin/bash

############################################################################
# Copyright Nash!Com, Daniel Nashed 2019, 2020 - APACHE 2.0 see LICENSE
# Copyright IBM Corporation 2015, 2019 - APACHE 2.0 see LICENSE
############################################################################

INSTALL_DIR=`dirname $0`

# export required environment variables
export LANG=C

SOFTWARE_FILE=$INSTALL_DIR/software.txt
WGET_COMMAND="wget --connect-timeout=10 --tries=1"

pushd()
{
  command pushd "$@" > /dev/null
}

popd ()
{
  command popd "$@" > /dev/null
}

export pushd popd

print_delim ()
{
  echo "--------------------------------------------------------------------------------"
}

log_ok ()
{
  echo "$1"
}

log_error ()
{
  echo
  echo "Failed - $1"
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

check_file_str ()
{
  CURRENT_FILE="$1"
  CURRENT_STRING="$2"


  if [ -e "$CURRENT_FILE" ]; then
    CURRENT_RESULT=`grep "$CURRENT_STRING" "$CURRENT_FILE" ` 

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
    DOWNLOAD_NAME=`grep "$1|$2|" "$SOFTWARE_FILE" | cut -d"|" -f3`
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
  DOWNLOAD_SERVER=$1
  DOWNLOAD_FILE=$2
  TARGET_DIR=$3

  if [ -z "$DOWNLOAD_FILE" ]; then
    log_error "No download file specified!"
    exit 1
  fi

  WGET_RET_OK=`$WGET_COMMAND -S --spider "$DOWNLOAD_SERVER/$DOWNLOAD_FILE" 2>&1 | grep 'HTTP/1.1 200 OK'`
  if [ -z "$WGET_RET_OK" ]; then
    echo "Download file does not exist [$DOWNLOAD_FILE]"
    return 0
  fi

  pushd .
  cd $TARGET_DIR

  if [ -e "$DOWNLOAD_FILE" ]; then
  	echo
    echo "Replacing existing file [$DOWNLOAD_FILE]"
    rm -f "$DOWNLOAD_FILE"
  fi

  $WGET_COMMAND "$DOWNLOAD_SERVER/$DOWNLOAD_FILE" 2>/dev/null

  if [ "$?" = "0" ]; then
    log_ok "Successfully downloaded: [$DOWNLOAD_FILE] "
    echo
    popd
    return 0

  else
    log_error "File [$DOWNLOAD_FILE] not downloaded correctly"
    popd
    exit 1
  fi
}

download_and_check_hash ()
{
  DOWNLOAD_FILE=$1
  TARGET_DIR=$2

  if [ -z "$DOWNLOAD_FILE" ]; then
    log_error "No download file specified!"
    exit 1
  fi

  # check if file exists before downloading

  WGET_RET_OK=`$WGET_COMMAND -S --spider "$DOWNLOAD_FILE" 2>&1 | grep 'HTTP/1.1 200 OK'`
  if [ -z "$WGET_RET_OK" ]; then
    log_error "File [$DOWNLOAD_FILE] does not exist"
    exit 1
  fi

  pushd .

  if [ ! -z "$TARGET_DIR" ]; then
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

    # download without extracting for none tar files, without hash checking
    $WGET_COMMAND "$DOWNLOAD_FILE" 2>/dev/null

    if [ "$?" = "0" ]; then
      log_ok "Successfully downloaded: [$DOWNLOAD_FILE] "
      popd
      return 0

    else
      log_error "File [$DOWNLOAD_FILE] not downloaded correctly [1]"
      popd
      exit 1
    fi
  else
    if [ -e $SOFTWARE_FILE ]; then
      HASH=`$WGET_COMMAND -qO- $DOWNLOAD_FILE | tee >(tar $TAR_OPTIONS 2>/dev/null) | sha256sum -b | cut -d" " -f1`
      FOUND=`grep $HASH $SOFTWARE_FILE | wc -l`

      if [ "$FOUND" = "1" ]; then
        log_ok "Successfully downloaded, extracted & checked: [$DOWNLOAD_FILE] "
        popd
        return 0

      else
        log_error "File [$DOWNLOAD_FILE] not downloaded correctly [2]"
        popd
        exit 1
      fi
    else
      $WGET_COMMAND -qO- $DOWNLOAD_FILE | tar $TAR_OPTIONS 2>/dev/null

      if [ "$?" = "0" ]; then
        log_ok "Successfully downloaded & extracted: [$DOWNLOAD_FILE] "
        popd
        return 0

      else
        log_error "File [$DOWNLOAD_FILE] not downloaded correctly [3]"
        popd
        exit 1
      fi
    fi
  fi

  popd
  return 0
}


check_file_busy()
{
  if [ ! -e "$1" ]; then
    return 0
  fi

  local TARGET_REAL_BIN=`readlink -f $1`
  local DIRNAME=`dirname $TARGET_REAL_BIN`
  local FOUND_TARGETS=`lsof +D "$DIRNAME" 2>/dev/null | grep "$TARGET_REAL_BIN"`

  if [ -n "$FOUND_TARGETS" ]; then
    return 1
  else
    return 0
  fi
}


install_file()
{
  SOURCE_FILE=$1
  TARGET_FILE=$2
  OWNER=$3
  GROUP=$4
  PERMS=$5

  if [ ! -r "$SOURCE_FILE" ]; then
    echo "No source file --> copy skipped for [$SOURCE_FILE]"
    return 1
  fi

  if [ -e "$TARGET_FILE" ]; then

    cmp -s "$SOURCE_FILE" "$TARGET_FILE"
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
 
  if [ ! -z "$OWNER" ]; then
    chown $OWNER:$GROUP "$TARGET_FILE"
  fi

  if [ ! -z "$PERMS" ]; then
    chmod "$PERMS" "$TARGET_FILE"
  fi

  echo "[$TARGET_FILE] copied"

  return 2
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
  
  if [ ! -z "$OWNER" ]; then
    chown $OWNER:$GROUP "$TARGET_FILE"
  fi

  if [ ! -z "$PERMS" ]; then
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
  	echo " --- directory not completely deleted! ---"
  	ls -l "$1"
  	echo " --- directory not completely deleted! ---"
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

extract_tar()
{
  TAR=`find . -name "$1"`

  if [ ! -z "$2" ]; then
    mkdir -p "$2"
    tar -xf "$TAR" -C $2
  else
    tar -xf "$TAR"
  fi
}

extract_tgz()
{
  TGZ=`find . -name "$1"`
  gzip -d "$TGZ"
}

extract_taz()
{
  TAZ=`find . -name "$1" `

  if [ ! -z "$2" ]; then
    mkdir -p "$2"
    tar -xzf "$TAZ" -C $2
  else
    tar -xzf "$TAZ"
  fi
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

  INSTALL_BIN_NAME=`basename $SOURCE_BIN`

  if [ -z "$INSTALL_BIN_NAME" ]; then
    echo "no file specified"
    return 0
  fi

  TARGET_BIN=$Notes_ExecDirectory/$INSTALL_BIN_NAME

  if [ -e "$TARGET_BIN" ]; then

    cmp -s "$SOURCE_BIN" "$TARGET_BIN"
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
      pushd .
      cd $LOTUS/bin
      ln -f -s tools/startup "$INSTALL_BIN_NAME"
      popd
      ;;

  esac

  return 0
}


install_iam ()
{
  header "$PROD_NAME Installation"

  INST_VER=$PROD_VER

  pushd .

  cd /data
  mkdir appdevpack
  cd appdevpack

  if [ ! -z "$INST_VER" ]; then
    get_download_name $PROD_NAME $INST_VER
    download_and_check_hash $DownloadFrom/$DOWNLOAD_NAME 
  else
    log_error "No Target Version specified"
    exit 1
  fi

  header "Installing $PROD_NAME $INST_VER"
  
  # Extract various compressed tars in different formats and names..
  extract_tgz "DOMINO_APPDEV_PACK_*.tgz"
  extract_tar "DOMINO_APPDEV_PACK_*.tar"
  extract_tgz "domino-iam-service*.tgz"
  extract_tar "domino-iam-service*.tar" "domino-iam-service"

  # install_file "domino-iam-service/template/iam-store.ntf" $DOMINO_DATA_PATH/iam-store.ntf notes notes 644

  echo
  log_ok "$PROD_NAME $INST_VER installed successfully"

  # log_error "$PROD_NAME $INST_VER Installation failed!!!"

  popd
  # rm -rf appdevpack 

  return 0
}

/ ()
{
  echo $PROD_VER > "/local/${PROD_NAME}_ver.txt"
  #echo $PROD_VER > "/local/notesdata/${PROD_NAME}_ver.txt"
}

# --- Main Install Logic ---

header "Environment Setup"

echo "INSTALL_DIR           = [$INSTALL_DIR]"
echo "DownloadFrom          = [$DownloadFrom]"
echo "Product               = [$PROD_NAME]"
echo "Version               = [$PROD_VER]"
echo "DominoUserID          = [$DominoUserID]"

whoami
echo "LOGNAME: [$LOGNAME]"

cd "$INSTALL_DIR"

install_iam

# Set Installed Version

set_version

header "Successfully completed installation!"

exit 0
