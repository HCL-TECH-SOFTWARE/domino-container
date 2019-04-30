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
export DOMINO_DATA_PATH=/local/notesdata
export PATH=$PATH:$DOMINO_DATA_PATH

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
  
  cd $LOTUS/bin
  
  if [ ! -e "$" ]; then
    ln -f -s tools/startup "$1"
    echo "installed startup link for [$1]"
  fi

  return 0
}

get_domino_version ()
{
  DOMINO_INSTALL_DAT=$LOTUS/.install.dat

  if [ -e $DOMINO_INSTALL_DAT ]; then

    find_str=`tail "$DOMINO_INSTALL_DAT" | grep "rev = " | awk -F " = " '{print $2}' | tr -d '"'`

    if [ ! -z "$find_str" ]; then
      DOMINO_VERSION=$find_str

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
  echo $DOMINO_VERSION > /local/domino_$1.txt
  echo $DOMINO_VERSION > /local/notesdata/domino_$1.txt
}

check_installed_version ()
{
  VersionFile=/local/domino_$1.txt
  
  if [ ! -r $VersionFile ]; then
    return 0
  fi

 CHECK_VERSION=`cat $VersionFile`
 INSTALL_VERSION=`echo $2 | tr -d '.'`
 
 if [ "$CHECK_VERSION" = "$INSTALL_VERSION" ]; then
   echo "Domino $INSTALL_VERSION already installed" 
   return 1
 else
   return 0
 fi
 
}

install_domino ()
{
  INST_VER=$PROD_VER

  check_installed_version ver $INST_VER
  if [ "$?" = "1" ]; then
    INST_VER=""
  fi

  if [ -z "$PROD_FP" ]; then
    INST_FP=""
  else
    INST_FP=$PROD_VER$PROD_FP
    
    check_installed_version fp $INST_FP
    if [ "$?" = "1" ]; then
      INST_FP=""
    fi
  fi

  if [ -z "$PROD_HF" ]; then
    INST_HF=""
  else
    INST_HF=$PROD_VER$PROD_FP$PROD_HF
    
    check_installed_version hf $INST_HF
    if [ "$?" = "1" ]; then
    	INST_HF=""
    fi
  fi
  
  echo
  echo "Downloading Domino Installation files ..."
  echo
  
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

    mv "$Notes_ExecDirectory/DominoInstall.log" "$INST_DOM_LOG"

    check_file_str "$INST_DOM_LOG" "$DOM_STRING_OK"

    if [ "$?" = "1" ]; then
      echo
      log_ok "Domino installed successfully"

      # Store Domino Version Information
      set_domino_version ver

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

      # Store Domino Fixpack Information
      set_domino_version fp

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

      # Store Domino Interimsfix/Hotfix Information
      set_domino_version hf

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


docker_set_timezone ()
{
  if [ -z "$DOCKER_TZ" ]; then
    return 0
  fi

  CURRENT_TZ=$(readlink /etc/localtime)
  SET_TZ=/usr/share/zoneinfo/$DOCKER_TZ

  if [ "$CURRENT_TZ" = "$SET_TZ" ]; then
    echo
    echo "Timezone [$DOCKER_TZ] already set"
    echo
    return 0
  fi

  if [ ! -e "$SET_TZ" ]; then
    echo
    echo "Cannot read timezone [$SET_TZ] -- Timezone not changed"
    echo
    return 1
  fi

  echo
  echo "Timezone set to [$DOCKER_TZ]"
  echo
  ln -sf "$SET_TZ" /etc/localtime

  return 0
}

# --- Main Install Logic ---

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

# This logic allows icremental installes for images based on each other (e.g. 10.0.1 -> 10.0.1FP1) 
if [ -e /opt/ibm/domino ]; then
  FIRST_TIME_SETUP=0
  echo
  echo "!! Incremantal install based on exiting Domino image !!"
  echo
else
  FIRST_TIME_SETUP=1
fi

if [ "$FIRST_TIME_SETUP" = "1" ]; then

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

  create_directory /local notes notes 770
  create_directory /local/notesdata notes notes 770
  create_directory /local/translog notes notes 770
  create_directory /local/daos notes notes 770

  docker_set_timezone

fi

cd "$INSTALL_DIR"

# Download updated software.txt file if available
download_file_ifpresent "$DownloadFrom" software.txt "$INSTALL_DIR"

case "$PROD_NAME" in
  domino|domino-ce)
    install_domino
    ;;

  *)
    log_error "Unknown product [$PROD_NAME] - Terminating installation"
    exit 1
    ;;
esac

header "Installing Start Script"

# Extracting start script files
cd $INSTALL_DIR
tar -xf start_script.tar

# Run start script installer
$INSTALL_DIR/start_script/install_script

# Install Setup Files and Docker Entrypoint
install_file "$INSTALL_DIR/SetupProfile.pds" "/local/notesdata/SetupProfile.pds" notes notes 644

header "Final Steps & Configuration"

# Copy pre-start configuration
install_file "$INSTALL_DIR/docker_prestart.sh" "/docker_prestart.sh" notes notes 770

# Copy Docker specific start script configuration if provided
install_file "$INSTALL_DIR/rc_domino_config" "/local/notesdata/rc_domino_config" notes notes 644 
install_file "$INSTALL_DIR/domino_docker_entrypoint.sh" "/domino_docker_entrypoint.sh" notes notes 755

# Install Data Directory Copy File 
install_file "$INSTALL_DIR/domino_install_data_copy.sh" "/domino_install_data_copy.sh" root root 755

# Install health check script
install_file "$INSTALL_DIR/domino_docker_healthcheck.sh" "/domino_docker_healthcheck.sh" root root 755

# Copy tools required for automating Domino Server configuration
install_file "$INSTALL_DIR/DatabaseSigner.jar" "/local/notesdata/DatabaseSigner.jar" notes notes 644

# Move installed templates, etc. to install directory
if [ ! -z "$DominoMoveInstallData" ]; then
  echo "Moving install data /local/notesdata -> $DominoMoveInstallData"
  mv -f /local/notesdata "$DominoMoveInstallData"
  create_directory /local/notesdata notes notes 770
fi

# --- Cleanup Routines to reduce image size ---

# Remove Fixpack/Hotfix backup files
find $Notes_ExecDirectory -maxdepth 1 -type d -name "100**" -exec rm -rf {} \;

# Remove not needed domino/html data to keep image smaller
find /local/notesdata/domino/html -name "*.dll" -exec rm -rf {} \;
find /local/notesdata/domino/html -name "*.msi" -exec rm -rf {} \;

remove_directory /local/notesdata/domino/html/download/filesets
remove_directory /local/notesdata/domino/html/help

# Remove uninstaller --> we never uninstall but rebuild from scratch
remove_directory $Notes_ExecDirectory/_uninst

# Create missing links

create_startup_link kyrtool
create_startup_link dbmt
install_res_links

remove_file /opt/ibm/domino/notes/latest/linux/tunekrnl

# Ensure permissons are set correctly for data directory
chown -R notes:notes /local/notesdata

if [ "$FIRST_TIME_SETUP" = "1" ]; then
  # Prepare data directory (compact NSFs and NTFs)

  su - notes -c $INSTALL_DIR/domino_install_data_prep.sh
fi

header "Successfully completed installation!"

exit 0
