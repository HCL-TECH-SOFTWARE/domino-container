#!/bin/bash

############################################################################
# (C) Copyright IBM Corporation 2015, 2019                                 #
#                                                                          #
# Licensed under the Apache License, Version 2.0 (the "License");          #
# you may not use this file except in compliance with the License.         #
# You may obtain a copy of the License at                                  #
#                                                                          #
#      http://www.apache.org/licenses/LICENSE-2.0                          #
#                                                                          #
# Unless required by applicable law or agreed to in writing, software      #
# distributed under the License is distributed on an "AS IS" BASIS,        #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. #
# See the License for the specific language governing permissions and      #
# limitations under the License.                                           #
#                                                                          #
############################################################################

INSTALL_DIR=`dirname $0`

# export required environment variables
export LOGNAME=notes
export LOTUS=/opt/ibm/domino
export Notes_ExecDirectory=$LOTUS/notes/latest/linux
export DYLD_LIBRARY_PATH=$Notes_ExecDirectory:$DYLD_LIBRARY_PATH
export LD_LIBRARY_PATH=$Notes_ExecDirectory:$LD_LIBRARY_PATH
export NUI_NOTESDIR=$LOTUS
export PATH=$PATH:/local/notesdata
export LANG=C

SOFTWARE_FILE=$INSTALL_DIR/software.txt
WGET_COMMAND="wget --connect-timeout=20"

# Helper Functions

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



check_file_busy()
{
  if [ ! -e "$1" ]; then
    return 0
  fi

  TARGET_REAL_BIN=`readlink -f $1`
  FOUND_TARGETS=`lsof 2>/dev/null| awk '{print $9}' | grep "$TARGET_REAL_BIN"`

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
  if [ ! -z "$1" ]; then
    rm -rf "$1"
  fi

  if [ -e "$1" ]; then
  	echo " --- directory not completely deleted! ---"
  	ls -l "$1"
  	echo " --- directory not completely deleted! ---"
  fi
  
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


install_domino ()
{
  INST_VER=$PROD_VER

  if [ -z "$PROD_FP" ]; then
    INST_FP=""
  else
    INST_FP=$PROD_VER$PROD_FP
  fi

  if [ -z "$PROD_HF" ]; then
    INST_HF=""
  else
    INST_HF=$PROD_VER$PROD_FP$PROD_HF
  fi

  echo
  echo "Downloading Domino Installation files ..."
  echo
  
  # download start script
  download_and_check_hash $DownloadFrom/start_script.tar
  
  if [ ! -z "$INST_VER" ]; then
    get_download_name $PROD_NAME $INST_VER
    download_and_check_hash $DownloadFrom/$DOWNLOAD_NAME domino_server
  fi

  if [ ! -z "$INST_FP" ]; then
    get_download_name $PROD_NAME $INST_FP domino_fp
    download_and_check_hash $DownloadFrom/$DOWNLOAD_NAME domino_fp
  fi

  if [ ! -z "$INST_HF" ]; then
    get_download_name $PROD_NAME $INST_HF domino_hf
    download_and_check_hash $DownloadFrom/$DOWNLOAD_NAME domino_hf
  fi

  if [ ! -z "$INST_VER" ]; then
    header "Installing $PROD_NAME $INST_VER"
    pushd .

    case "$PROD_NAME" in
      domino)
        cd domino_server/linux64/domino
        ;;

      domino-ce)
        cd domino_server/linux64/DominoEval
      ;;

      *)
        log_error "Unknown product [$PROD_NAME] - Terminating installation"
        popd
        exit 1
        ;;
    esac

    echo
    echo "Running Domino Silent Install -- This takes a while ..."
    echo

    ./install -silent -options "$INSTALL_DIR/$DominoResponseFile"

    echo $INST_VER >/local/notesdata/data_version.txt

    mv "$Notes_ExecDirectory/DominoInstall.log" "$INST_DOM_LOG"

    check_file_str "$INST_DOM_LOG" "$DOM_STRING_OK"

    if [ "$?" = "1" ]; then
      echo
      log_ok "Domino installed successfully"

    else
      print_delim
      cat $INST_DOM_LOG
      print_delim

      log_error "Domino Installation failed!!!"
      popd
      exit 1
    fi

    popd
    rm -rf domino_server
  fi

  if [ ! -z "$INST_FP" ]; then
    header "Installing Fixpack $INST_FP"

    echo
    echo "Running Domino Fixpack Silent Install -- This takes a while ..."
    echo

    pushd .
    cd domino_fp/linux64/domino

    ./install -script script.dat > $INST_FP_LOG

    echo $INST_FP >/local/notesdata/data_version.txt

    check_file_str "$INST_FP_LOG" "$FP_STRING_OK"

    if [ "$?" = "1" ]; then
    	echo
      log_ok "Fixpack installed successfully"
    else

      echo
      print_delim
      cat $INST_FP_LOG
      print_delim
      log_error "Fixpack Installation failed!!!"
      popd
      exit 1
    fi

    popd
    rm -rf domino_fp

  fi  

  if [ ! -z "$INST_HF" ]; then
    header "Installing IF/HF INST_HF"

    echo
    echo "Running Domino Iterimsfix/Hotfix Silent Install -- This takes a while ..."
    echo

    pushd .
    cd domino_hf/linux64

    ./install -script script.dat > $INST_HF_LOG

    check_file_str "$INST_HF_LOG" "$HF_STRING_OK"

    if [ "$?" = "1" ]; then
      echo
      log_ok "InterimsFix/HotFix installed successfully"
    else

      echo
      print_delim
      cat hf.log
      print_delim
      log_error "InterimsFix/HotFix Installation failed!!!"

      popd
      exit 1
    fi

    popd
    rm -rf domino_hf

  fi

  return 0
}

install_traveler ()
{
  header "$PROD_NAME Installation"

  if [ ! -z "$INST_VER" ]; then
    get_download_name $PROD_NAME $INST_VER
    download_and_check_hash $DownloadFrom/$DOWNLOAD_NAME traveler
  fi

  header "Installing $PROD_NAME $INST_VER"

  pushd .

  cd traveler

  ./silentInstall > $INST_TRAVELER_LOG

  cp /local/notesdata/IBM_TECHNICAL_SUPPORT/traveler/logs/TravelerInstall.log /local

  check_file_str "$INST_TRAVELER_LOG" "$TRAVELER_STRING_OK"

  if [ "$?" = "1" ]; then
    echo
    log_ok "Traveler installed successfully"

  else

    print_delim
    cat $INST_TRAVELER_LOG
    print_delim

    log_error "Traveler Installation failed!!!"
    exit 1
  fi

  popd
  rm -rf traveler 

  return 0
}


# --- Main Install Logic ---

# Add notes:notes user
if [ -z "$DominoUserID" ]; then
  adduser notes -U
else
  adduser notes -U -u $DominoUserID 
fi

# Set User Local if configured
if [ ! -z "$DOMINO_LANG" ]; then
  echo "export LANG=$DOMINO_LANG" >> /home/notes/.bash_profile
fi

# Set security limits for pam modules (su needs it)
echo >> /etc/security/limits.conf
echo '# -- Begin Changes Domino --' >> /etc/security/limits.conf
echo 'notes soft nofile 60000' >> /etc/security/limits.conf
echo 'notes hard nofile 60000' >> /etc/security/limits.conf
echo '# -- End Changes Domino --' >> /etc/security/limits.conf

header "Environment Setup"

echo "INSTALL_DIR           = [$INSTALL_DIR]"
echo "DownloadFrom          = [$DownloadFrom]"
echo "Product               = [$PROD_NAME]"
echo "Version               = [$PROD_VER]"
echo "Fixpack               = [$PROD_FP]"
echo "InterimsFix/Hotfix    = [$PROD_HF]"
echo "DominoResponseFile    = [$DominoResponseFile]"
echo "DominoMoveInstallData = [$DominoMoveInstallData]"
echo "DominoVersion         = [$DominoVersion]"
echo "DominoUserID          = [$DominoUserID]"

create_directory /local notes notes 770
create_directory /local/notesdata notes notes 770
create_directory /local/translog notes notes 770
create_directory /local/daos notes notes 770

cd "$INSTALL_DIR"

header "Environment"

df -h

echo
print_delim
echo

# Download updated software.txt file if available
download_file_ifpresent "$DownloadFrom" software.txt "$INSTALL_DIR"

case "$PROD_NAME" in
  domino|domino-ce)
    install_domino
    ;;

  traveler)
    install_traveler
    ;;

  *)
    log_error "Unknown product [$PROD_NAME] - Terminating installation"
    exit 1
    ;;
esac

header "Final Steps & Configuration"

# Removing Base Install files
cd "$INSTALL_DIR"
remove_directory "$INSTALL_DIR/linux64"

header "Installing Start Script"

$INSTALL_DIR/start_script/install_script

# Install Setup Files and Docker Entrypoint
install_file "$INSTALL_DIR/SetupProfile.pds" "/local/notesdata/SetupProfile.pds" notes notes 644

header "Final Steps & Configuration"

# Copy pre-start configuration
install_file "$INSTALL_DIR/docker_prestart.sh" "/docker_prestart.sh" notes notes 770

# Copy Docker specific start script configuration if provided
install_file "$INSTALL_DIR/rc_domino_config" "/local/notesdata/rc_domino_config" notes notes 644 
install_file "$INSTALL_DIR/domino_docker_entrypoint.sh" "/local/notesdata/domino_docker_entrypoint.sh" notes notes 770

# Copy tools required for automating Domino Server configuration
install_file "$INSTALL_DIR/DatabaseSigner.jar" "/local/notesdata/DatabaseSigner.jar" notes notes 644

# Move installed templates, etc. to install directory
if [ ! -z "$DominoMoveInstallData" ]; then
  echo "Moving install data /local/notesdata -> $DominoMoveInstallData"
  mv -f /local/notesdata "$DominoMoveInstallData"
  create_directory /local/notesdata notes notes 770
fi

# Remove Fixpack/Hotfix Backup Files

find $Notes_ExecDirectory -maxdepth 1 -type d -name "100**" -exec rm -rf {} \;

# Create missing links
cd /opt/ibm/domino/bin/
ln -f -s tools/startup kyrtool
ln -f -s tools/startup dbmt
install_res_links

# Remove tunekernel. It is causing error messages because of Docker virtualization
rm -f /opt/ibm/domino/notes/latest/linux/tunekrnl

# remove_directory "$INSTALL_DIR"

header "Successfully completed installation!"

exit 0
