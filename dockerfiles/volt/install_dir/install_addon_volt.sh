#!/bin/bash

############################################################################
# Copyright Nash!Com, Daniel Nashed 2019, 2020 - APACHE 2.0 see LICENSE
############################################################################

PROD_NAME=volt

DOMDOCK_DIR=/domino-docker
DOMDOCK_LOG_DIR=/domino-docker
DOMDOCK_TXT_DIR=/domino-docker
DOMDOCK_SCRIPT_DIR=/domino-docker/scripts
DOMINO_DATA_PATH=/local/notesdata
DOMINO_INI_PATH=$DOMINO_DATA_PATH/notes.ini
INSTALL_ADDON_DATA_TAR=$DOMDOCK_DIR/install_data_addon_${PROD_NAME}.taz
LOG_FILE=$DOMDOCK_LOG_DIR/addon_{$PROD_NAME}_data_update.log


get_notes_ini_var ()
{
  # $1 = filename
  # $2 = ini.variable

  ret_ini_var=""
  if [ -z "$1" ]; then
    return 0
  fi

  if [ ! -r "$1" ]; then
    echo "cannot read [$1]"
    return 0
  fi

  if [ -z "$2" ]; then
    return 0
  fi

  ret_ini_var=`awk -F '(=| =)' -v SEARCH_STR="$2" '{if (tolower($1) == tolower(SEARCH_STR)) print $2}' $1 | xargs`
  return 0
}

set_notes_ini_var()
{
  # updates or sets notes.ini parameter
  file=$1
  var=$2
  new=$3

  if [ ! -w "$file" ]; then
    echo "cannot write [$file]"
    return 0
  fi

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

add_list_ini()
{
  # appends entry to ini list 
  file=$1
  var=$2
  param=$3

  get_notes_ini_var "$file" "$var"

  if [ -z "$ret_ini_var" ]; then
    set_notes_ini_var "$file" "$var" "$param"
    # echo "entry [$param] set"
    return 1
  fi

  for CHECK_ENTRY in `echo "$ret_ini_var" | awk '{print tolower($0)}' | tr "," "\n"` ; do
    if [ $CHECK_ENTRY = "$param" ]; then
      # echo "entry [$param] already set"
      return 0
    fi
  done

  set_notes_ini_var "$file" "$var" "$ret_ini_var,$param"
  # echo "entry [$param] added"

  return 1
}

remove_list_ini()
{
  # remove entry to ini list
  file=$1
  var=$2
  param=$3
  found=
  newlist=

  get_notes_ini_var "$file" "$var"

  if [ -z "$ret_ini_var" ]; then
    # echo "entry [$var] empty"
    return 0
  fi

  for CHECK_ENTRY in `echo "$ret_ini_var" | awk '{print tolower($0)}' | tr "," "\n"` ; do
    if [ $CHECK_ENTRY = "$param" ]; then
      found=YES
    else
      if [ -z "$newlist" ]; then
        newlist="$CHECK_ENTRY"
      else
        newlist="$newlist,$CHECK_ENTRY"
      fi
    fi
  done

  if [ -z "$found" ]; then
    # echo "entry [$param] not found"
    return 0
  fi
 
  set_notes_ini_var "$file" "$var" "$newlist"
  # echo "entry [$param] removed"

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

  if [ ! -z "$OWNER" ]; then
    chown $OWNER:$GROUP "$TARGET_FILE"
  fi

  if [ ! -z "$PERMS" ]; then
    chmod "$PERMS" "$TARGET_FILE"
  fi

  return 0
}

remove_directory ()
{
  if [ -z "$1" ]; then
    return 1
  fi

  if [ ! -e "$1" ]; then
    return 2
  fi

  rm -rf "$1"

  if [ -e "$1" ]; then
        echo " --- directory not completely deleted! ---"
        ls -l "$1"
        echo " --- directory not completely deleted! ---"
  fi

  return 0
}

remove_file ()
{
  if [ -z "$1" ]; then
    return 1
  fi

  if [ ! -e "$1" ]; then
    return 2
  fi

  rm -rf "$1"
  return 0
}


set_java_options_file ()
{

  get_notes_ini_var "$DOMINO_INI_PATH" "JavaOptionsFile"

  if [ -z "$ret_ini_var" ]; then
    JAVA_OPTIONS_FILE="$DOMINO_DATA_PATH/javaOptions.txt"
    set_notes_ini_var "$DOMINO_INI_PATH" "JavaOptionsFile" "$JAVA_OPTIONS_FILE"
  else
    JAVA_OPTIONS_FILE="$ret_ini_var"
  fi

  touch "$JAVA_OPTIONS_FILE"
  set_notes_ini_var "$JAVA_OPTIONS_FILE" "-Dvolt.serverURI" "$DOMINO_VOLT_URL"
}

# --- Main Install Logic ---


set_notes_ini_var "$DOMINO_INI_PATH" "HTTPEnableMethods" "GET,POST,PUT,DELETE,HEAD"

set_notes_ini_var $DOMINO_INI_PATH ServerTasks "Update,Replica,Router,AMgr,AdminP"
set_notes_ini_var $DOMINO_INI_PATH SetupLeaveServertasks "1"
add_list_ini $DOMINO_INI_PATH servertasks http

if [ -r "$INSTALL_ADDON_DATA_TAR" ]; then
  tar xzvf "$INSTALL_ADDON_DATA_TAR" --overwrite -C $DOMINO_DATA_PATH
fi

# disabled --> set_java_options_file


if [ -z "$DOMINO_HOST_NAME" ]; then
  DOMINO_HOST_NAME=`hostname`
fi

if [ -z "$DOMINO_VOLT_URL" ]; then
  DOMINO_VOLT_URL="https://$DOMINO_HOST_NAME/volt-apps"
fi

cd /local/notesdata
/opt/hcl/domino/bin/nshdocker -VoltUri "$DOMINO_VOLT_URL"

echo
echo "Volt configuration done"
echo

