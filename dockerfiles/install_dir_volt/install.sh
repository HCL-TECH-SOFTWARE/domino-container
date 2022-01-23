#!/bin/bash

############################################################################
# Copyright Nash!Com, Daniel Nashed 2019, 2022 - APACHE 2.0 see LICENSE
############################################################################

INSTALL_DIR=$(dirname $0)

export DOMDOCK_DIR=/domino-docker
export DOMDOCK_LOG_DIR=/domino-docker
export DOMDOCK_TXT_DIR=/domino-docker
export DOMDOCK_SCRIPT_DIR=/domino-docker/scripts
export LOTUS=/opt/hcl/domino

# export required environment variables
export LOGNAME=notes
export Notes_ExecDirectory=$LOTUS/notes/latest/linux
export DYLD_LIBRARY_PATH=$Notes_ExecDirectory:$DYLD_LIBRARY_PATH
export LD_LIBRARY_PATH=$Notes_ExecDirectory:$LD_LIBRARY_PATH
export NUI_NOTESDIR=$LOTUS
export DOMINO_DATA_PATH=/local/notesdata
export PATH=$PATH:$DOMINO_DATA_PATH
export LANG=C

INSTALL_ADDON_DATA_TAR=$DOMDOCK_DIR/install_data_addon_${PROD_NAME}.taz

SOFTWARE_FILE=$INSTALL_DIR/software.txt
CURL_CMD="curl --fail --connect-timeout 15 --max-time 300 $SPECIAL_CURL_ARGS"

# Include helper functions
. $INSTALL_DIR/script_lib.sh


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

DOMINO_USER=notes
DOMINO_GROUP=notes

ROOT_USER=root
ROOT_GROUP=root

DOMINO_DATA_DIRECTORY=$DOMINO_DATA_PATH
create_directory $DOMINO_DATA_PATH $DOMINO_USER $DOMINO_GROUP 770

OSGI_FOLDER="$Notes_ExecDirectory/osgi"
OSGI_VOLT_FOLDER=$OSGI_FOLDER"/volt"
PLUGINS_FOLDER=$OSGI_VOLT_FOLDER"/eclipse/plugins"
VOLT_DATA_DIR=$DOMINO_DATA_DIRECTORY"/volt"
LINKS_FOLDER=$OSGI_FOLDER"/rcp/eclipse/links"
LINK_PATH=$OSGI_FOLDER"/volt"
LINK_FILE=$LINKS_FOLDER"/volt.link" 

create_directory "$VOLT_DATA_DIR" $DOMINO_USER $DOMINO_GROUP 770
create_directory "$OSGI_VOLT_FOLDER" $ROOT_USER $ROOT_GROUP 777
create_directory "$LINKS_FOLDER" $ROOT_USER $ROOT_GROUP 777
create_directory "$PLUGINS_FOLDER" $ROOT_USER $ROOT_GROUP 777

echo 'path='$LINK_PATH > $LINK_FILE

pushd .

cd $PROD_NAME
echo "Unzipping files .."
unzip -q *.zip

echo "Copying files .."
cp -f "templates/"* "$VOLT_DATA_DIR"
cp -f "bundles/"* "$PLUGINS_FOLDER"

install_file "$INSTALL_DIR/install_addon_volt.sh" "$DOMDOCK_SCRIPT_DIR/install_addon_volt.sh" $ROOT_USER $ROOT_GROUP 755

# Update java security policy to grant all permissions to Groovy templates

cat $INSTALL_DIR/java.policy.update >> $Notes_ExecDirectory/jvm/lib/security/java.policy

# Install helper binary
install_binary "$INSTALL_DIR/nshdocker"

popd
remove_directory $PROD_NAME 

header "Final Steps & Configuration"

# Ensure permissons are set correctly for data directory
chown -R notes:notes $DOMINO_DATA_PATH

# Take a backup copy of Product Data Files

# Set Installed Version
set_version

# Copy demopack.zip if present in install dir 
if [ -e "$INSTALL_DIR/demopack.zip" ]; then
  cp "$INSTALL_DIR/demopack.zip" "$DOMDOCK_DIR/demopack.zip"
fi

cd $DOMINO_DATA_PATH

tar -czf $INSTALL_ADDON_DATA_TAR volt ${PROD_NAME}_ver.txt

remove_directory $DOMINO_DATA_PATH
create_directory $DOMINO_DATA_PATH notes notes 770

# Cleanup repository cache to save space
clean_linux_repo_cache

header "Successfully completed installation!"

exit 0
