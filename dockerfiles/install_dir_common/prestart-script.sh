#!/bin/bash
############################################################################
# Copyright Nash!Com, Daniel Nashed 2026 - APACHE 2.0 see LICENSE
############################################################################


export DOMDOCK_DIR=/opt/domino-container
export DOMDOCK_LOG_DIR=/tmp/domino-container
export DOMDOCK_TXT_DIR=/opt/domino-container
export DOMDOCK_SCRIPT_DIR=/opt/domino-container/scripts
export LOTUS=/opt/hcl/domino
export Notes_ExecDirectory=$LOTUS/notes/latest/linux
export DOMINO_DATA_PATH=/local/notesdata

DOMDOCK_UPDATE_CHECK_STATUS_FILE=$DOMDOCK_LOG_DIR/domino_data_upd_checked.txt

mkdir -p "$DOMDOCK_LOG_DIR"
mkdir -p "$DOMDOCK_TXT_DIR"

if [ ! -e "$DOMDOCK_UPDATE_CHECK_STATUS_FILE" ]; then
  "$DOMDOCK_SCRIPT_DIR/domino_install_data_copy.sh"
  date > "$DOMDOCK_UPDATE_CHECK_STATUS_FILE"
fi

