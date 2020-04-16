#!/bin/bash

############################################################################
# Copyright Nash!Com, Daniel Nashed 2019, 2020 - APACHE 2.0 see LICENSE
# Copyright IBM Corporation 2015, 2019 - APACHE 2.0 see LICENSE
############################################################################

DOMINO_DATA_PATH=/local/notesdata
DOMDOCK_LOG_DIR=/domino-docker
LOG_FILE=$DOMDOCK_LOG_DIR/domino_install_data_prep.log

if [ -z "$LOTUS" ]; then
  if [ -x /opt/hcl/domino/bin/server ]; then
    LOTUS=/opt/hcl/domino
  else
    LOTUS=/opt/ibm/domino
  fi
fi

log ()
{
  echo "$1 $2 $3 $4 $5" >> $LOG_FILE
}

echo
echo Compacting install data directory ...
echo

# Set inportant notes.ini defaults
cd $DOMINO_DATA_PATH
echo "create_r10_databases=1" >> notes.ini
echo "create_r85_log=1" >> notes.ini
echo "DOMINONOWEBADMIN=1" >> notes.ini

# Backup notes.ini
cp notes.ini notes.ini.orig

# Temorary disable log.nsf for compact
echo "log=,1,0,7,40000" >> notes.ini

# Enable compression, discard view index and upgrade to current ODS

log "--------------------"
df -h  >> $LOG_FILE
log "--------------------"

$LOTUS/bin/compact -# 4 -* -C -D -n -v -upgrade >> $LOG_FILE

log "--------------------"
df -h  >> $LOG_FILE
log "--------------------"

# Restore original notes.ini
rm notes.ini
mv notes.ini.orig notes.ini

echo Compact done.
echo

