#!/bin/bash

LOTUS=/opt/ibm/domino
Notes_ExecDirectory=$LOTUS/notes/latest/linux
DOMINO_DATA_PATH=/local/notesdata
DOMINO_INSTDATA_BACKUP=$Notes_ExecDirectory/data1_bck

LOG_FILE=/local/domino_data_update.log


log ()
{
  echo "$1 $2 $3 $4 $5" >> $LOG_FILE
}

copy_files ()
{
  if [ ! -e "$1" ]; then
    log "source directory does not exist [$1]" 
    return 1
  fi

  if [ ! -e "$2" ]; then
    log "taget directory does not exist [$2]" 
    return 2
  fi

  log
  log "Copying files [$1] --> [$2]" 
  cp -rvf "$1/" "$2" >> $LOG_FILE

  return 0
}

copy_files_for_version ()
{
  VersionFile=/local/domino_$1.txt
  InstalledFile=/local/notesdata/domino_$1.txt

  if [ ! -r $VersionFile ]; then
    return 1
  fi

  if [ -r $InstalledFile ]; then
    INSTALLED_VERSION=`cat $InstalledFile`
  else
    INSTALLED_VERSION=""
  fi

  DOMINO_VERSION=`cat $VersionFile`

  # echo "DOMINO_VERSION: [$DOMINO_VERSION]"
  # echo "INSTALLED_VERSION: [$INSTALLED_VERSION]"

  if [ "$DOMINO_VERSION" = "$INSTALLED_VERSION" ]; then
    log "Data already installed for $DOMINO_VERSION"
    return 0
  fi

  log "Copying new data files for Version $DOMINO_VERSION"

  copy_files $DOMINO_INSTDATA_BACKUP/$DOMINO_VERSION/localnotesdata $DOMINO_DATA_PATH
  copy_files $DOMINO_INSTDATA_BACKUP/$DOMINO_VERSION/localnotesdataiNotes $DOMINO_DATA_PATH/iNotes
  copy_files $DOMINO_INSTDATA_BACKUP/$DOMINO_VERSION/localnotesdatadominojava $DOMINO_DATA_PATH/domino/java

  echo $DOMINO_VERSION > $InstalledFile

  return 0
}

NOW=`date`

log --------------------------------------------------
log $NOW
log --------------------------------------------------
log Checking for Data Directory Update
copy_files_for_version fp
copy_files_for_version hf
log --------------------------------------------------
log

exit 0
