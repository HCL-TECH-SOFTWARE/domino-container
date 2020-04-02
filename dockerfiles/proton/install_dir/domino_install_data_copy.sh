#!/bin/bash

############################################################################
# Copyright Nash!Com, Daniel Nashed 2019, 2020 - APACHE 2.0 see LICENSE
# Copyright IBM Corporation 2015, 2019 - APACHE 2.0 see LICENSE
############################################################################

DOMINO_INSTDATA_BACKUP=$Notes_ExecDirectory/data1_bck
UPDATE_CHECK_STATUS_FILE=$DOMDOCK_TXT_DIR/data_update_checked.txt
LOG_FILE=$DOMDOCK_LOG_DIR/domino_data_update.log

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
  VersionFile=$DOMDOCK_TXT_DIR/domino_$1.txt
  InstalledFile=$DOMINO_DATA_PATH/domino_$1.txt

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

copy_files_for_addon ()
{
  PROD_NAME=$1
  VersionFile=$DOMDOCK_TXT_DIR/${PROD_NAME}_ver.txt
  InstalledFile=$DOMINO_DATA_PATH/${PROD_NAME}_ver.txt

  if [ ! -r $VersionFile ]; then
    return 1
  fi

  if [ -r $InstalledFile ]; then
    INST_VER=`cat $InstalledFile`
  else
    INST_VER=""
  fi

  PROD_VER=`cat $VersionFile`

  # echo "PROD_VER: [$PROD_VER]"
  # echo "INST_VER: [$INST_VER]"

  if [ "$PROD_VER" = "$INST_VER" ]; then
    log "Data already installed for $PROD_NAME $PROD_VER"
    return 0
  fi

  log "Copying new data files for $PROD_NAME $PROD_VER"
  log

  tar xvf $DOMDOCK_DIR/install_data_${PROD_NAME}_${PROD_VER}.taz -C $DOMINO_DATA_PATH >> $LOG_FILE

  echo $PROD_VER > $InstalledFile

  return 0
}


NOW=`date`

# check data update only at first container start

if [ -e $UPDATE_CHECK_STATUS_FILE ]; then
  UPDATE_CHECKED=`cat $UPDATE_CHECK_STATUS_FILE`
  exit 0
fi

echo $NOW > $UPDATE_CHECK_STATUS_FILE


log --------------------------------------------------
log $NOW
log --------------------------------------------------

log Checking for Data Directory Update

copy_files_for_version fp
copy_files_for_version hf

copy_files_for_addon proton 

log --------------------------------------------------
log

exit 0
