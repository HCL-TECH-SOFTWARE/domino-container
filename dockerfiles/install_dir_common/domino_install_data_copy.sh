#!/bin/bash

############################################################################
# Copyright Nash!Com, Daniel Nashed 2019, 2022 - APACHE 2.0 see LICENSE
# Copyright IBM Corporation 2015, 2019 - APACHE 2.0 see LICENSE
############################################################################

DOMINO_INSTDATA_BACKUP=$Notes_ExecDirectory/data1_bck
LOG_FILE=$DOMDOCK_LOG_DIR/data_update.log

# Include helper functions & defines
. /domino-container/scripts/script_lib.sh

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
  log_file "[$var] -> [$val]"
  UPD_INI=1
}

update_traveler_ini()
{
  file=$1
  upd_file=$2

  # change field separator
  BAK_IFS=$IFS
  IFS=$'\n'

  for x in $(grep "^NTS_" $upd_file) ; do
    var=$(echo "$x" | cut -d= -f1)
    val=$(echo "$x" | cut -d= -f2-)
    update_traveler_ini_var "$file" "$var" "$val"
  done

  # restore seperator
  IFS=$BAK_IFS
  BAK_IFS=
}

copy_files()
{
  if [ ! -e "$1" ]; then
    log_file "source directory does not exist [$1]"
    return 1
  fi

  if [ ! -e "$2" ]; then
    log_file "taget directory does not exist [$2]"
    return 2
  fi

  log_file "Copying files [$1] --> [$2]"
  cp -rvf "$1/" "$2" >> $LOG_FILE

  return 0
}

copy_files_for_major_version()
{
  VersionFile=$DOMDOCK_TXT_DIR/domino_ver.txt
  InstalledFile=$DOMINO_DATA_PATH/domino_ver.txt

  if [ ! -r $VersionFile ]; then
    return 1
  fi

  DOMINO_VERSION=$(cat $VersionFile)

  if [ -r $InstalledFile ]; then
    INSTALLED_VERSION=$(cat $InstalledFile)
  else
    INSTALLED_VERSION=""
  fi

  log_file "DOMINO_VERSION: [$DOMINO_VERSION]"
  log_file "INSTALLED_VERSION: [$INSTALLED_VERSION]"

  if [ "$DOMINO_VERSION" = "$INSTALLED_VERSION" ]; then
    log_file "Data already installed for $DOMINO_VERSION"
    return 0
  fi

  # Set NotesProgram notes.ini (required for Traveler, but should always point to the binary directoy)
  set_notes_ini_var $DOMINO_DATA_PATH/notes.ini "NotesProgram" "$Notes_ExecDirectory"

  # Avoid Domino Directory Design Update Prompt
  set_notes_ini_var $DOMINO_DATA_PATH/notes.ini "SERVER_UPGRADE_NO_DIRECTORY_UPGRADE_PROMPT" "1"

  # Allow server names with dots and undercores
  set_notes_ini_var $DOMINO_DATA_PATH/notes.ini "ADMIN_IGNORE_NEW_SERVERNAMING_CONVENTION" "1"

  # Ensure current ODS is used for V12 -> does not harm on earlier releases
  set_notes_ini_var $DOMINO_DATA_PATH/notes.ini "Create_R12_Databases" "1"

  log_file_header "Copying new data files for Version $DOMINO_VERSION"

  # Extracting new data files

  DOMDOCK_INSTALL_DATA_TAR=$DOMDOCK_DIR/install_data_domino.taz

  debug_show_data_dir "before unzip"

  tar -xvf "$DOMDOCK_INSTALL_DATA_TAR" --overwrite -C "$DOMINO_DATA_PATH" ./iNotes ./domino ./help ./panagenda ./xmlschemas ./aut ./rmeval ./Properties ./W32 "*.ntf" "*.nsf" "*.cnf" >> $LOG_FILE 2>&1

  debug_show_data_dir "after unzip"

  # Ensure directory can be read by group -> needed for root login
  chmod "$DIR_PERM" "$DOMINO_DATA_PATH"

  echo $DOMINO_VERSION > $InstalledFile

  return 0
}

copy_files_for_version()
{
  VersionFile=$DOMDOCK_TXT_DIR/domino_$1.txt
  InstalledFile=$DOMINO_DATA_PATH/domino_$1.txt

  if [ ! -r $VersionFile ]; then
    return 1
  fi

  if [ -r $InstalledFile ]; then
    INSTALLED_VERSION=$(cat $InstalledFile)
  else
    INSTALLED_VERSION=""
  fi

  DOMINO_VERSION=$(cat $VersionFile)

  log_file "DOMINO_VERSION: [$DOMINO_VERSION]"
  log_file "INSTALLED_VERSION: [$INSTALLED_VERSION]"

  if [ "$DOMINO_VERSION" = "$INSTALLED_VERSION" ]; then
    log_file "Data already installed for $DOMINO_VERSION"
    return 0
  fi

  log_file_header "Copying new data files for Version $DOMINO_VERSION"

  copy_files $DOMINO_INSTDATA_BACKUP/$DOMINO_VERSION/localnotesdata $DOMINO_DATA_PATH
  copy_files $DOMINO_INSTDATA_BACKUP/$DOMINO_VERSION/localnotesdataiNotes $DOMINO_DATA_PATH/iNotes
  copy_files $DOMINO_INSTDATA_BACKUP/$DOMINO_VERSION/localnotesdatadominojava $DOMINO_DATA_PATH/domino/java

  echo $DOMINO_VERSION > $InstalledFile

  return 0
}

copy_data_directory()
{
  if [ -e "$DOMINO_DATA_PATH/notes.ini" ]; then
    log_file "Data directory already exists - nothing to copy."
    return 0
  fi


  if [ -e "$DOMINO_DATA_PATH" ]; then
    log_file "[$DOMINO_DATA_PATH] already exists"

  else
    log_file "Creating directories for user: [$DOMINO_USER] group: [$DOMINO_GROUP] perm: [$DIR_PERM]"
  fi

  debug_show_data_dir "Before create"

  create_directory $DOMINO_DATA_PATH $DOMINO_USER $DOMINO_GROUP $DIR_PERM
  create_directory /local/translog $DOMINO_USER $DOMINO_GROUP $DIR_PERM
  create_directory /local/daos $DOMINO_USER $DOMINO_GROUP $DIR_PERM
  create_directory /local/nif $DOMINO_USER $DOMINO_GROUP $DIR_PERM
  create_directory /local/ft $DOMINO_USER $DOMINO_GROUP $DIR_PERM

  debug_show_data_dir "After create"

  DOMDOCK_INSTALL_DATA_TAR=$DOMDOCK_DIR/install_data_domino.taz

  if [ ! -e "$DOMDOCK_INSTALL_DATA_TAR" ]; then
    log_file "Install data [$DOMDOCK_INSTALL_DATA_TAR] does not exist - cannot create data directory!!"
    return 0
  fi

  log_file_header "Extracting install data directory from [$DOMDOCK_INSTALL_DATA_TAR]"

  tar -xvf "$DOMDOCK_INSTALL_DATA_TAR" -C "$DOMINO_DATA_PATH" >> $LOG_FILE 2>&1

  log_file_delim
  debug_show_data_dir "after extract"
  log_file_delim

  # Just needed for first setup if not using our notes.ini

  # Set NotesProgram notes.ini (required for Traveler, but should always point to the binary directoy)
  set_notes_ini_var $DOMINO_DATA_PATH/notes.ini "NotesProgram" "$Notes_ExecDirectory"

  # Avoid Domino Directory Design Update Prompt
  set_notes_ini_var $DOMINO_DATA_PATH/notes.ini "SERVER_UPGRADE_NO_DIRECTORY_UPGRADE_PROMPT" "1"

  # Allow server names with dots and undercores
  set_notes_ini_var $DOMINO_DATA_PATH/notes.ini "ADMIN_IGNORE_NEW_SERVERNAMING_CONVENTION" "1"

  # Ensure current ODS is used for V12 -> does not harm on earlier releases
  set_notes_ini_var $DOMINO_DATA_PATH/notes.ini "Create_R12_Databases" "1"

  # Ensure directory can be read by group -> OpenShift has some issues with copying permissions
  log_file "Running chmod [$DIR_PERM] [$DOMINO_DATA_PATH] "
  chmod "$DIR_PERM" "$DOMINO_DATA_PATH" >> $LOG_FILE

  # Important for install data dirs from other images -> ensure the data version is set

  if [ ! -e "$DOMINO_DATA_PATH/domino_ver.txt" ]; then
    cat $DOMDOCK_TXT_DIR/domino_ver.txt > $DOMINO_DATA_PATH/domino_ver.txt
  fi
}

copy_files_for_addon()
{
  PROD_NAME=$1

  # Domino image has it's own logic
  if [ "$PROD_NAME" = "domino" ]; then
    return 0
  fi

  VersionFile=$DOMDOCK_TXT_DIR/${PROD_NAME}_ver.txt
  InstalledFile=$DOMINO_DATA_PATH/${PROD_NAME}_ver.txt

  if [ ! -r $VersionFile ]; then
    log_file "No Version File found for add-on [$VersionFile]"
    return 1
  fi

  if [ -r $InstalledFile ]; then
    INST_VER=$(cat $InstalledFile)
  else
    INST_VER=""
  fi

  PROD_VER=$(cat $VersionFile)

  if [ "$PROD_VER" = "$INST_VER" ]; then
    log_file "Data already installed for $PROD_NAME $PROD_VER"
    return 0
  fi

  log_file_header "Copying new data files for $PROD_NAME $PROD_VER"

  DOMDOCK_INSTALL_DATA_TAR=$DOMDOCK_DIR/install_data_addon_${PROD_NAME}.taz

  if [ ! -e "$DOMDOCK_INSTALL_DATA_TAR" ]; then
    log_file "Install data [$DOMDOCK_INSTALL_DATA_TAR] does not exist - Cannot copy files to data directory!!"
    return 0
  fi

  log_file "Extracting add-on install data directory from [$DOMDOCK_INSTALL_DATA_TAR]"

  tar -xvf "$DOMDOCK_INSTALL_DATA_TAR" -C $DOMINO_DATA_PATH >> $LOG_FILE 2>&1

  if [ "$PROD_NAME" = "traveler" ]; then

    # Updating Traveler notes.ini parameters

    log_file "Updating Traveler notes.ini parameters"

    update_traveler_ini $DOMINO_DATA_PATH/notes.ini $DOMDOCK_DIR/traveler_install_notes.ini
  fi

  echo $PROD_VER > $InstalledFile

  return 0
}

copy_files_for_all_addons()
{
  # Check for all add-ons

  PROD_LIST=$(find "$DOMDOCK_TXT_DIR" -maxdepth 1 -name "*_ver.txt" | cut -d"_" -f 1 | rev | cut -d"/" -f 1 | rev)

  for PROD in $PROD_LIST; do
    copy_files_for_addon $PROD
  done
}

# --- Main Logic ---

NOW=$(date)
log_file_header "$NOW"

copy_data_directory

log_file Checking for Data Directory Update

copy_files_for_major_version
copy_files_for_version fp
copy_files_for_version hf

copy_files_for_all_addons

log_file
