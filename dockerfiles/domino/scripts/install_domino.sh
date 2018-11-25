#!/bin/bash

############################################################################
# (C) Copyright IBM Corporation 2015, 2018                                 #
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

CHECK_SOFTWARE_HASH_FILE=$INSTALL_DIR/software_dir_sha256.txt
WGET_COMMAND="wget --connect-timeout=20"

# Helper Functions

download_and_check_hash ()
{
  DOWNLOAD_FILE=$1

  if [[ "$DOWNLOAD_FILE" =~ ".taz" ]]; then
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
      echo "Successfully downloaded: [$DOWNLOAD_FILE] "
      return 0
    else
      echo "File [$DOWNLOAD_FILE] not downloaded correctly - terminating installation"
      exit 1
    fi
  else
    if [ -e $CHECK_SOFTWARE_HASH_FILE ]; then
      HASH=`$WGET_COMMAND -qO- $DOWNLOAD_FILE | tee >(tar $TAR_OPTIONS) | sha256sum -b | cut -d" " -f1`
      FOUND=`grep $HASH $CHECK_SOFTWARE_HASH_FILE | wc -l`

      if [ "$FOUND" = "1" ]; then
        echo "Successfully downloaded, extracted & checked: [$DOWNLOAD_FILE] "
        return 0
      else
        echo "File [$DOWNLOAD_FILE] not downloaded correctly - terminating installation"
        exit 1
      fi
    else
      $WGET_COMMAND -qO- $DOWNLOAD_FILE | tar $TAR_OPTIONS 2>/dev/null

      if [ "$?" = "0" ]; then
        echo "Successfully downloaded & extracted: [$DOWNLOAD_FILE] "
      else
        echo "File [$DOWNLOAD_FILE] not downloaded correctly - terminating installation"
        exit 1
      fi
    fi
  fi
}


print_delim ()
{
  echo "--------------------------------------------------------------------------------"
}

header ()
{
  echo
  print_delim
  echo "$1"
  print_delim
  echo
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
echo "DominoBasePackage     = [$DominoBasePackage]"
echo "DominoResponseFile    = [$DominoResponseFile]"
echo "DominoMoveInstallData = [$DominoMoveInstallData]"
echo "DominoVersion         = [$DominoVersion]"
echo "DominoUserID          = [$DominoUserID]"

create_directory /local notes notes 770
create_directory /local/notesdata notes notes 770
create_directory /local/translog notes notes 770
create_directory /local/daos notes notes 770

header "IBM Domino Base Install"

# Download Domino Server install files
cd "$INSTALL_DIR"

echo
echo "Downloading Domino Installation files ..."
echo

download_and_check_hash $DownloadFrom/$DominoBasePackage
download_and_check_hash $DownloadFrom/start_script.tar

echo
echo "Running Domino Silent Install -- This takes a while ..."
echo

header "Final Steps & Configuration"

# Run Domino Silent Install
cd "$INSTALL_DIR/linux64/domino/"
./install -silent -options "$INSTALL_DIR/$DominoResponseFile"

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

# Create missing links
cd /opt/ibm/domino/bin/
ln -f -s tools/startup kyrtool
ln -f -s tools/startup dbmt
install_res_links

# Remove tunekernel. It is causing error messages because of Docker virtualization
rm -f /opt/ibm/domino/notes/latest/linux/tunekrnl

remove_directory "$INSTALL_DIR"

header "Done Install Domino"

exit 0
