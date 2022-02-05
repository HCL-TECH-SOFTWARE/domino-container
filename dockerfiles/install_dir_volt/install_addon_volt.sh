#!/bin/bash

############################################################################
# Copyright Nash!Com, Daniel Nashed 2019, 2022 - APACHE 2.0 see LICENSE
############################################################################

PROD_NAME=volt

# Include helper functions & defines
. /domino-docker/scripts/script_lib.sh

INSTALL_ADDON_DATA_TAR=$DOMDOCK_DIR/install_data_addon_${PROD_NAME}.taz
LOG_FILE=$DOMINO_DATA_PATH/IBM_TECHNICAL_SUPPORT/addon_{$PROD_NAME}_data_update.log

# --- Main Install Logic ---

set_notes_ini_var "$DOMINO_INI_PATH" "HTTPEnableMethods" "GET,POST,PUT,DELETE,HEAD"

set_notes_ini_var $DOMINO_INI_PATH ServerTasks "Update,Replica,Router,AMgr,AdminP"
set_notes_ini_var $DOMINO_INI_PATH SetupLeaveServertasks "1"
add_list_ini $DOMINO_INI_PATH servertasks http

if [ -r "$INSTALL_ADDON_DATA_TAR" ]; then
  tar xzvf "$INSTALL_ADDON_DATA_TAR" --overwrite -C $DOMINO_DATA_PATH
fi

if [ -z "$DOMINO_HOST_NAME" ]; then
  DOMINO_HOST_NAME=$(hostname)
fi

if [ -z "$DOMINO_VOLT_URL" ]; then
  DOMINO_VOLT_URL="https://$DOMINO_HOST_NAME/volt-apps"
fi

cd $DOMINO_DATA_PATH
$LOTUS/bin/nshdocker -VoltUri "$DOMINO_VOLT_URL"

log_space "Volt configuration done"
