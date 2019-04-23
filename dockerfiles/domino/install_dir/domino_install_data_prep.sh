#!/bin/sh

LOG_FILE=/local/domino_install_data_prep.log

log ()
{
  echo "$1 $2 $3 $4 $5" >> $LOG_FILE
}

echo
echo Compacting install data directory ...
echo

cd /local/notesdata
echo "create_r10_databases=1" >> notes.ini
echo "create_r85_log=1" >> notes.ini

# Backup notes.ini
cp notes.ini notes.ini.orig

# Temorary disable log.nsf for compact
echo "log=,1,0,7,40000" >> notes.ini

# Enable compression, discard view index and upgrade to current ODS

log "--------------------"
df -h  >> $LOG_FILE
log "--------------------"

/opt/ibm/domino/bin/compact -# 4 -* -C -D -n -v -upgrade >> $LOG_FILE

log "--------------------"
df -h  >> $LOG_FILE
log "--------------------"

# Restore original notes.ini
rm notes.ini
mv notes.ini.orig notes.ini

echo Compact done.
echo

