#!/bin/bash

############################################################################
# Copyright Nash!Com, Daniel Nashed 2022 - APACHE 2.0 see LICENSE
############################################################################

INSTALL_DIR=$(dirname $0)
export LANG=C

# Include helper functions

. $INSTALL_DIR/script_lib.sh

INSTALL_ADDON_DATA_TAR=$DOMDOCK_DIR/install_data_addon_${PROD_NAME}.taz

# --- Main Install Logic ---

header "Environment Setup"

echo "INSTALL_DIR           = [$INSTALL_DIR]"
echo "DownloadFrom          = [$DownloadFrom]"
echo "Product               = [$PROD_NAME]"
echo "Version               = [$PROD_VER]"
echo "DominoUserID          = [$DominoUserID]"

cd "$INSTALL_DIR"

# Download updated software.txt file if available
download_file_ifpresent "$DownloadFrom" software.txt "$INSTALL_DIR"

install_nomadweb()
{
  local ADDON_NAME=nomadweb
  local ADDON_VER=$1

  echo "NomadWeb Version: [$ADDON_VER]"

  if [ -z "$ADDON_VER" ]; then
    return 0
  fi

  header "$ADDON_NAME Installation"

  get_download_name $ADDON_NAME $ADDON_VER
  download_and_check_hash "$DownloadFrom" "$DOWNLOAD_NAME" "$ADDON_NAME"

  log_space Unzipping Nomad Web data

  mkdir -p /usr/local/nomad-src/nomad

  NOMADWEB_ZIP=$(find "$ADDON_NAME" -name "*.zip")

  if [ -z "$NOMADWEB_ZIP" ]; then
    log_error "No Nomad Web ZIP found"
  fi

  echo "NomadWebZip: [$NOMADWEB_ZIP]"

  time unzip -q $NOMADWEB_ZIP -d /usr/local/nomad-src/nomad

  remove_directory $ADDON_NAME

  log_space Installed $ADDON_NAME
}


# Installing SafeLinx

header "$PROD_NAME Installation"

INST_VER=$PROD_VER

if [ -n "$INST_VER" ]; then
  get_download_name $PROD_NAME $INST_VER
  download_and_check_hash "$DownloadFrom" "$DOWNLOAD_NAME" $PROD_NAME
else
  log_error "No Target Version specified"
  exit 1
fi

CURRENT_DIR=$(pwd)
cd $PROD_NAME

# If MS SQL client exists ensure it is in the part for installtion - even it is set in the profile
if [ -e /opt/mssql-tools18/bin ]; then
  echo "current path: $PATH"
  export PATH="$PATH:/opt/mssql-tools18/bin"
fi

cd inst.images
export SILENT_INSTALL=y

./install_wg --silent

setcap 'cap_net_bind_service=+ep' /opt/hcl/SafeLinx/bin/wgated

cd $CURRENT_DIR
remove_directory $PROD_NAME

mkdir /cert-mount

echo "Installed SafeLinx"

# Install Nomad Web if requested
install_nomadweb "$NOMADWEB_VERSION"

header "Final Steps & Configuration"

install_file "$INSTALL_DIR/entrypoint.sh" "/entrypoint.sh" root root 755

# Install health check script
install_file "$INSTALL_DIR/healthcheck.sh" "/healthcheck.sh" root root 755

# Cleanup repository cache to save space
clean_linux_repo_cache

header "Successfully completed installation!"
