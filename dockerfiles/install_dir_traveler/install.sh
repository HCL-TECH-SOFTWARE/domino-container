#!/bin/bash

############################################################################
# Copyright Nash!Com, Daniel Nashed 2019, 2022 - APACHE 2.0 see LICENSE
# Copyright IBM Corporation 2015, 2019 - APACHE 2.0 see LICENSE
############################################################################

INSTALL_DIR=$(dirname $0)

export DOMDOCK_DIR=/domino-docker
export DOMDOCK_LOG_DIR=/domino-docker
export DOMDOCK_TXT_DIR=/domino-docker
export DOMDOCK_SCRIPT_DIR=/domino-docker/scripts

export LOTUS=/opt/hcl/domino

if [ -n "$(find /opt/hcl/domino/notes/ -maxdepth 1 -name "120001*")" ]; then
  TRAVELER_INSTALLER_PROPERTIES=$INSTALL_DIR/installer_domino1201.properties
else [ -n "$(find /opt/hcl/domino/notes/ -maxdepth 1 -name "12*")" ]; then
  TRAVELER_INSTALLER_PROPERTIES=$INSTALL_DIR/installer_domino12.properties
fi

# export required environment variables
export LOGNAME=notes
export Notes_ExecDirectory=$LOTUS/notes/latest/linux
export DYLD_LIBRARY_PATH=$Notes_ExecDirectory:$DYLD_LIBRARY_PATH
export LD_LIBRARY_PATH=$Notes_ExecDirectory:$LD_LIBRARY_PATH
export NUI_NOTESDIR=$LOTUS
export DOMINO_DATA_PATH=/local/notesdata
export PATH=$PATH:$DOMINO_DATA_PATH
export LANG=C

INSTALL_DATA_TAR=$DOMDOCK_DIR/install_data_domino.taz

SOFTWARE_FILE=$INSTALL_DIR/software.txt
CURL_CMD="curl --fail --location --connect-timeout 15 --max-time 300 $SPECIAL_CURL_ARGS"

TRAVELER_STRING_OK="Installation completed successfully."
TRAVELER_STRING_WARNINGS="Installation completed with warnings."
INST_TRAVELER_LOG=$DOMDOCK_LOG_DIR/install_traveler.log


# Include helper functions
. $INSTALL_DIR/script_lib.sh


install_traveler()
{
  header "$PROD_NAME Installation"

  INST_VER=$PROD_VER

  if [ ! -z "$INST_VER" ]; then
    get_download_name $PROD_NAME $INST_VER
    download_and_check_hash "$DownloadFrom" "$DOWNLOAD_NAME" traveler
  else
    log_error "No Target Version specified"
    exit 1
  fi

  header "Installing $PROD_NAME $INST_VER"

  create_directory $DOMINO_DATA_PATH root root 777
  create_directory $DOMINO_DATA_PATH/IBM_TECHNICAL_SUPPORT root root 777 

  if [ ! -e "$DOMINO_DATA_PATH/notes.ini" ]; then
    log_ok "Extracting install notesdata for Traveler install"
    tar xf "$INSTALL_DATA_TAR" -C "$DOMINO_DATA_PATH"
  fi

  pushd .

  cd traveler

  header "Running Traveler silent install"

  ./TravelerSetup -f $TRAVELER_INSTALLER_PROPERTIES -i SILENT -l en > $INST_TRAVELER_LOG

  cp -f $DOMINO_DATA_PATH/IBM_TECHNICAL_SUPPORT/traveler/logs/TravelerInstall.log $DOMDOCK_LOG_DIR

  check_file_str "$INST_TRAVELER_LOG" "$TRAVELER_STRING_OK"

  if [ "$?" = "1" ]; then
    echo
    log_ok "$PROD_NAME $INST_VER installed successfully"

  else

    check_file_str "$INST_TRAVELER_LOG" "$TRAVELER_STRING_WARNINGS"

    if [ "$?" = "1" ]; then
      echo
      log_ok "$PROD_NAME $INST_VER installed successfully (with warnings)"
    else
      print_delim
      cat $INST_TRAVELER_LOG
      print_delim

      log_error "Traveler Installation failed!!!"
      exit 1
    fi
  fi

  popd
  remove_directory traveler 
  create_directory $DOMINO_DATA_PATH root root 777 

  return 0
}


# --- Main Install Logic ---

header "Environment Setup"

echo "INSTALL_DIR           = [$INSTALL_DIR]"
echo "DownloadFrom          = [$DownloadFrom]"
echo "Product               = [$PROD_NAME]"
echo "Version               = [$PROD_VER]"
echo "DominoUserID          = [$DominoUserID]"

# Check for Linux updates if requested
check_linux_update

cd "$INSTALL_DIR"

# Download updated software.txt file if available
download_file_ifpresent "$DownloadFrom" software.txt "$INSTALL_DIR"

case "$PROD_NAME" in

  traveler)
    install_traveler
    ;;

  *)
    log_error "Unknown product [$PROD_NAME] - Terminating installation"
    exit 1
    ;;
esac

header "Final Steps & Configuration"

# Install Data Directory Copy File 
install_file "$INSTALL_DIR/domino_install_data_copy.sh" "$DOMDOCK_SCRIPT_DIR/domino_install_data_copy.sh" root root 755

# Install health check script
install_file "$INSTALL_DIR/domino_docker_healthcheck.sh" "/domino_docker_healthcheck.sh" root root 755

# --- Cleanup Routines to reduce image size ---

# Remove uninstaller --> we never uninstall but rebuild from scratch
remove_directory $Notes_ExecDirectory/_uninst


# Ensure permissons are set correctly for data directory
chown -R notes:notes $DOMINO_DATA_PATH

set_version

# Take a backup copy of Product Data Files

case "$PROD_NAME" in

  traveler)
    cd $DOMINO_DATA_PATH
    tar -czf $DOMDOCK_DIR/install_data_${PROD_NAME}_${PROD_VER}.taz traveler domino/workspace ${PROD_NAME}_ver.txt
    cp -f $DOMINO_DATA_PATH/notes.ini $DOMDOCK_DIR/traveler_install_notes.ini
    cd /
    remove_directory $DOMINO_DATA_PATH
    create_directory $DOMINO_DATA_PATH root root 777
    ;;

esac

# Cleanup repository cache to save space
clean_linux_repo_cache

header "Successfully completed installation!"

exit 0
