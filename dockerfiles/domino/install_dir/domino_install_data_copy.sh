#!/bin/bash

DOMINO_INSTDATA_BACKUP=$Notes_ExecDirectory/data1_bck
UPDATE_CHECK_STATUS_FILE=$DOMDOCK_TXT_DIR/data_update_checked.txt
LOG_FILE=$DOMDOCK_LOG_DIR/domino_data_update.log

log()
{
  echo "$1 $2 $3 $4 $5" >> $LOG_FILE
}

log_space()
{
  echo  >> $LOG_FILE
  echo "$1 $2 $3 $4 $5" >> $LOG_FILE
  echo  >> $LOG_FILE
}


print_delim()
{
  echo "--------------------------------------------------------------------------------" >> $LOG_FILE
}

header()
{
  echo >> $LOG_FILE
  print_delim
  echo "$1" >> $LOG_FILE
  print_delim
  echo >> $LOG_FILE
}

get_notes_ini_var()
{
  # $1 = filename
  # $2 = ini.variable

  ret_ini_var=""
  if [ -z "$1" ]; then
    return 0
  fi

  if [ -z "$2" ]; then
    return 0
  fi

  ret_ini_var=`awk -F '=' -v SEARCH_STR="$2" '{if (tolower($1) == tolower(SEARCH_STR)) print $2}' $1 | xargs`
  return 0
}

set_notes_ini_var()
{
  # updates or sets notes.ini parameter
  file=$1
  var=$2
  new=$3

  get_notes_ini_var "$file" "$var"

  if [ "$ret_ini_var" = "$new" ]; then
    return 0
  fi

  # check if entry exists empty. if not present just append new entry, else use replace code
  if [ -z "$ret_ini_var" ]; then
    found=`grep -i "^$var=" $file`
    if [ -z "$found" ]; then
      echo $var=$new >> $file
      return 0
    fi
  fi

  awk -v var="$var" -v new="$new" 'BEGIN{FS=OFS="=";IGNORECASE=1}match($1,"^"var"$") {$2=new}1' "$file" > $file.updated
  mv $file.updated $file

  return 0
}

remove_notes_ini_var()
{
  # updates or sets notes.ini parameter
  file=$1
  var=$2

  found=`grep -i "^$var=" $file`
  echo "found: [$found]"
  if [ -z "$found" ]; then
    return 0
  fi

  grep -v -i "^$var=" $file > $file.updated
  mv $file.updated $file

  return 0
}

update_traveler_ini_var()
{
  file=$1
  var=$2
  value=$3
  UPD_INI=0

  if [ -z "$var" ]; then
    return 0
  fi

  get_notes_ini_var "$file" "$var"

  if [ "$ret_ini_var" = "$val" ]; then
    return 0
  fi

  if [ ! -z "$ret_ini_var" ]; then

    if [ "$var" = "NTS_BUILD" ]; then
      UPD_INI=1
    else
      return 0
    fi
  fi

  set_notes_ini_var "$file" "$var" "$val"
  log "[$var] -> [$val]"
  UPD_INI=1
}

update_traveler_ini()
{
  file=$1
  upd_file=$2

  # change field separator
  BAK_IFS=$IFS
  IFS=$'\n'

  for x in `grep "^NTS_" $upd_file` ; do
    var=`echo "$x" | cut -d= -f1`
    val=`echo "$x" | cut -d= -f2-`
    update_traveler_ini_var "$file" "$var" "$val"
  done

  # restore seperator
  IFS=$BAK_IFS
  BAK_IFS=
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

copy_files_for_major_version ()
{
  VersionFile=$DOMDOCK_TXT_DIR/domino_ver.txt
  InstalledFile=$DOMINO_DATA_PATH/domino_ver.txt

  if [ ! -r $VersionFile ]; then
    return 1
  fi

  DOMINO_VERSION=`cat $VersionFile`

  if [ -r $InstalledFile ]; then
    INSTALLED_VERSION=`cat $InstalledFile`
  else
    INSTALLED_VERSION=""
  fi

  # echo "DOMINO_VERSION: [$DOMINO_VERSION]"
  # echo "INSTALLED_VERSION: [$INSTALLED_VERSION]"

  if [ "$DOMINO_VERSION" = "$INSTALLED_VERSION" ]; then
    log_space "Data already installed for $DOMINO_VERSION"
    return 0
  fi

  # Set NotesProgram notes.ini (required for Traveler, but should always point to the binary directoy)
  set_notes_ini_var $DOMINO_DATA_PATH/notes.ini "NotesProgram" "$Notes_ExecDirectory"

  # Avoid Domino Directory Design Update Prompt
  set_notes_ini_var $DOMINO_DATA_PATH/notes.ini "SERVER_UPGRADE_NO_DIRECTORY_UPGRADE_PROMPT" "1"

  header "Copying new data files for Version $DOMINO_VERSION"

  # Extracting new data files 

  INSTALL_DATA_TAR=$DOMDOCK_DIR/install_data_domino.taz

  tar xzvf "$INSTALL_DATA_TAR" --overwrite -C "$DOMINO_DATA_PATH" ./iNotes ./domino ./help ./panagenda ./xmlschemas ./aut ./rmeval ./dfc ./Properties ./W32 "*.ntf" "*.nsf" "*.cnf" >> $LOG_FILE 2>&1

  echo $DOMINO_VERSION > $InstalledFile

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
    log_space "Data already installed for $DOMINO_VERSION"
    return 0
  fi

  header "Copying new data files for Version $DOMINO_VERSION"

  copy_files $DOMINO_INSTDATA_BACKUP/$DOMINO_VERSION/localnotesdata $DOMINO_DATA_PATH
  copy_files $DOMINO_INSTDATA_BACKUP/$DOMINO_VERSION/localnotesdataiNotes $DOMINO_DATA_PATH/iNotes
  copy_files $DOMINO_INSTDATA_BACKUP/$DOMINO_VERSION/localnotesdatadominojava $DOMINO_DATA_PATH/domino/java

  echo $DOMINO_VERSION > $InstalledFile

  return 0
}


delete_directory ()
{
  TARGET_FILE=$1

  if [ -z "$TARGET_FILE" ]; then
    return 0
  fi

  if [ ! -e "$TARGET_FILE" ]; then
    return 0
  fi

  mountpoint -q "$TARGET_FILE"
  if [ "$?" = "0" ]; then
    echo "skipping directory delete for [$TARGET_FILE] -> is a mount point!"
  fi

  rmdir "$TARGET_FILE"

  return 0
}

create_directory ()
{
  TARGET_FILE=$1
  OWNER=$2
  GROUP=$3
  PERMS=$4

  if [ -z "$TARGET_FILE" ]; then
    return 0
  fi

  if [ -e "$TARGET_FILE" ]; then
    return 0
  fi

  mkdir -p "$TARGET_FILE"

  if [ ! -z "$PERMS" ]; then
    chmod "$PERMS" "$TARGET_FILE"
  fi


  # script always runs as user. only root can change owner!
  return 0

  if [ ! -z "$OWNER" ]; then
    chown $OWNER:$GROUP "$TARGET_FILE"
  fi

  return 0
}

copy_data_directory ()
{
  if [ -e "$DOMINO_DATA_PATH/notes.ini" ]; then
    log_space "Data directory already exists - nothing to copy."
    return 0
  fi 

  DIR_PERM=700

  if [ -e $DOMINO_DATA_PATH ]; then
    echo "$DOMINO_DATA_PATH already exists"
  else
    echo "creating directories with user: [$DOMINO_USER] group: [$DOMINO_GROUP] perm: [$DIR_PERM]"
  fi

  echo "------------------"
  ls -l /local
  echo "------------------"

  log "------------------"
  ls -l /local >> $LOG_FILE
  log "------------------"

  delete_directory $DOMINO_DATA_PATH
  delete_directory /local/translog
  delete_directory /local/daos
  delete_directory /local/nif
  delete_directory /local/ft

  create_directory $DOMINO_DATA_PATH $DOMINO_USER $DOMINO_GROUP $DIR_PERM 
  create_directory /local/translog $DOMINO_USER $DOMINO_GROUP $DIR_PERM 
  create_directory /local/daos $DOMINO_USER $DOMINO_GROUP $DIR_PERM
  create_directory /local/nif $DOMINO_USER $DOMINO_GROUP $DIR_PERM
  create_directory /local/ft $DOMINO_USER $DOMINO_GROUP $DIR_PERM

  INSTALL_DATA_TAR=$DOMDOCK_DIR/install_data_domino.taz

  if [ ! -e "$INSTALL_DATA_TAR" ]; then
    log_space "Install data [$INSTALL_DATA_TAR] does not exist - cannot create data directory!!"
    return 0
  fi 

  header "Extracting install data directory from [$INSTALL_DATA_TAR]" 
  
  tar xzvf "$INSTALL_DATA_TAR" -C "$DOMINO_DATA_PATH" >> $LOG_FILE 2>&1
  log
}

copy_files_for_addon ()
{
  PROD_NAME=$1
  VersionFile=$DOMDOCK_TXT_DIR/${PROD_NAME}_ver.txt
  InstalledFile=$DOMINO_DATA_PATH/${PROD_NAME}_ver.txt

  if [ ! -r $VersionFile ]; then
    log_space "No Version File found for add-on [$VersionFile]"
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
    log_space "Data already installed for $PROD_NAME $PROD_VER"
    return 0
  fi

  header "Copying new data files for $PROD_NAME $PROD_VER"

  INSTALL_DATA_TAR=$DOMDOCK_DIR/install_data_${PROD_NAME}_${PROD_VER}.taz

  if [ ! -e "$INSTALL_DATA_TAR" ]; then
    log_space "Install data [$INSTALL_DATA_TAR] does not exist - cannot copy files to data directory!!"
    return 0
  fi

  header "Extracting add-on install data directory from [$INSTALL_DATA_TAR]"

  tar xzvf "$INSTALL_DATA_TAR" -C $DOMINO_DATA_PATH >> $LOG_FILE 2>&1

  if [ "$PROD_NAME" = "traveler" ]; then

    # updating Traveler notes.ini parameters

    header "Updating Traveler notes.ini parameters"

    update_traveler_ini $DOMINO_DATA_PATH/notes.ini $DOMDOCK_DIR/traveler_install_notes.ini
  fi

  echo $PROD_VER > $InstalledFile

  return 0
}

# --- Main Logic ---

NOW=`date`

# check data update only at first container start

if [ -e $UPDATE_CHECK_STATUS_FILE ]; then
  UPDATE_CHECKED=`cat $UPDATE_CHECK_STATUS_FILE`
  exit 0
fi

echo $NOW > $UPDATE_CHECK_STATUS_FILE

header "$NOW"

copy_data_directory

log_space Checking for Data Directory Update

copy_files_for_major_version
copy_files_for_version fp
copy_files_for_version hf

copy_files_for_addon traveler

print_delim
log

exit 0
