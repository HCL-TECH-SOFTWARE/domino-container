#!/bin/bash

###########################################################################
# Nash!Com Domino Docker Script                                           #
# Version 1.1.1 27.04.2019                                                #
#                                                                         #
# (C) Copyright Daniel Nashed/NashCom 2019                                #
# Feedback domino_unix@nashcom.de                                         #
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

export INSTALL_DIR=/tmp/install_dir
export LOTUS=/opt/ibm/domino
export Notes_ExecDirectory=$LOTUS/notes/latest/linux
export LD_LIBRARY_PATH=$Notes_ExecDirectory:$LD_LIBRARY_PATH
export NUI_NOTESDIR=$LOTUS
export LANG=C

SCRIPT_NAME=$0
SOFTWARE_FILE=$INSTALL_DIR/software.txt
WGET_COMMAND="wget --connect-timeout=20"


DOM_STRING_OK="Dominoserver Installation successful"
LP_STRING_OK="Selected Language Packs are successfully installed."
FP_STRING_OK="The installation completed successfully."
HF_STRING_OK="The installation completed successfully."
TRAVELER_STRING_OK="Installation completed with warnings."
HF_UNINSTALL_STRING_OK="The installation completed successfully."
JVM_STRING_OK="Patch was successfully applied."
JVM_STRING_FP_OK="Tree diff file patch successful!"


INST_DOM_LOG=/local/install_domino.log
INST_FP_LOG=/local/install_fp.log
INST_HF_LOG=/local/install_hf.log
INST_TRAVELER_LOG=/local/install_traveler.log

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

check_binary_busy()
{
  if [ ! -e "$1" ]; then
    return 0
  fi

  TARGET_REAL_BIN=`readlink -f $1`
  FOUND_TARGETS=`lsof | awk '{print $9}' | grep "$TARGET_REAL_BIN"`

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
    echo "[$SOURCE_FILE] Can not read source file"
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

    check_binary_busy "$TARGET_FILE"

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

install_binary()
{
  SOURCE_BIN=$1

  if [ -z "$SOURCE_BIN" ]; then
    echo "no file specified"
    return 0
  fi

  if [ ! -r "$SOURCE_BIN" ]; then
    echo "Source file does not exist or is not readable"
    return 0
  fi

  if [ ! -e "$SOURCE_BIN" ]; then
    echo "Cannot find binary '$SOURCE_BIN'"
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

    check_binary_busy "$TARGET_BIN"

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
      cd $LOTUS/bin
      ln -f -s tools/startup "$INSTALL_BIN_NAME"
      ;;

  esac

  return 0
}

install_all_servertasks ()
{
  SERVERTASKS_INSTALL_DIR=$1

  if [ ! -e "$SERVERTASKS_INSTALL_DIR" ]; then
    return 0
  fi

  all_servertasks=`find $SERVERTASKS_INSTALL_DIR -type f -printf "%p\n"`

  for servertask in $all_servertasks; do
    install_binary "$servertask"
  done

  return 0
}

install_all_extmgr ()
{
  EXTMGR_INSTALL_DIR=$1

  if [ ! -e "$EXTMGR_INSTALL_DIR" ]; then
    return 0
  fi

  all_extmgr=`find $EXTMGR_INSTALL_DIR -type f -printf "%p\n"`

  for extmgr in $all_extmgr; do
    install_binary "$extmgr"
  done

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

cd $INSTALL_DIR

header "Environment"

df -h

echo
print_delim
echo

download_file_ifpresent "$DownloadFrom" software.txt "$INSTALL_DIR"

if [ ! -z $DownloadFrom ]; then
  header "Download Files Demo"

  download_and_check_hash $DownloadFrom/start_script.tar
  download_and_check_hash $DownloadFrom/text.txt "My Install Directory"
fi

header "Installing Domino related Files"

# install servertasks 
install_all_servertasks "$INSTALL_DIR/servertasks"

# install extmgrs
install_all_extmgr "$INSTALL_DIR/extmgr"


# install health check script

install_file "$INSTALL_DIR/domino_docker_healthcheck.sh" "/domino_docker_healthcheck.sh" root root 755

header "Successfully Build Image"

exit 0

