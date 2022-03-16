#!/bin/bash

############################################################################
# Copyright Nash!Com, Daniel Nashed 2019, 2022 - APACHE 2.0 see LICENSE
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

# Check for Linux updates if requested
check_linux_update

cd "$INSTALL_DIR"

# Download updated software.txt file if available
download_file_ifpresent "$DownloadFrom" software.txt "$INSTALL_DIR"

# Installing Add-On Product

header "$PROD_NAME Installation"

INST_VER=$PROD_VER

if [ -n "$INST_VER" ]; then
  get_download_name $PROD_NAME $INST_VER
  download_and_check_hash "$DownloadFrom" "$DOWNLOAD_NAME" $PROD_NAME
else
  log_error "No Target Version specified"
  exit 1
fi

header "Installing $PROD_NAME $INST_VER"

create_directory $DOMINO_USER $DOMINO_GROUP $DIR_PERM

OSGI_FOLDER="$Notes_ExecDirectory/osgi"
OSGI_VOLT_FOLDER=$OSGI_FOLDER"/volt"
PLUGINS_FOLDER=$OSGI_VOLT_FOLDER"/eclipse/plugins"
VOLT_DATA_DIR=$DOMINO_DATA_PATH"/volt"
LINKS_FOLDER=$OSGI_FOLDER"/rcp/eclipse/links"
LINK_PATH=$OSGI_FOLDER"/volt"
LINK_FILE=$LINKS_FOLDER"/volt.link"

create_directory "$VOLT_DATA_DIR" $DOMINO_USER $DOMINO_GROUP $DIR_PERM
create_directory "$OSGI_VOLT_FOLDER" root root 755
create_directory "$LINKS_FOLDER" root root 755
create_directory "$PLUGINS_FOLDER" root root 755

echo 'path='$LINK_PATH > $LINK_FILE

cd $PROD_NAME
echo "Unzipping files .."
unzip -q *.zip

echo "Copying files .."
cp -f "templates/"* "$VOLT_DATA_DIR"
cp -f "bundles/"* "$PLUGINS_FOLDER"

cd ..
remove_directory $PROD_NAME

header "Final Steps & Configuration"

# Ensure permissons are set correctly for data directory
chown -R $DOMINO_USER:$DOMINO_GROUP $DOMINO_DATA_PATH

# Take a backup copy of Product Data Files

# Set Installed Version
set_version

# Copy demopack.zip if present in install dir
if [ -e "$INSTALL_DIR/demopack.zip" ]; then
  cp "$INSTALL_DIR/demopack.zip" "$DOMDOCK_DIR/demopack.zip"
fi

cd $DOMINO_DATA_PATH
tar -czf "$INSTALL_ADDON_DATA_TAR" volt ${PROD_NAME}_ver.txt

remove_directory "$DOMINO_DATA_PATH"
create_directory "$DOMINO_DATA_PATH" "$DOMINO_USER" $DOMINO_GROUP $DIR_PERM

# Cleanup repository cache to save space
clean_linux_repo_cache

header "Successfully completed installation!"
