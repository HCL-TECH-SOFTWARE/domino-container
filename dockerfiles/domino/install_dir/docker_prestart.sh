#!/bin/bash

############################################################################
# Copyright Nash!Com, Daniel Nashed 2019, 2020 - APACHE 2.0 see LICENSE
# Copyright IBM Corporation 2015, 2019 - APACHE 2.0 see LICENSE
############################################################################

# Configure server based on environment variables

if [ -z "$LOTUS" ]; then
  if [ -x /opt/hcl/domino/bin/server ]; then
    LOTUS=/opt/hcl/domino
  else
    LOTUS=/opt/ibm/domino
  fi
fi

# ServerName variable is the configuration trigger
if [ -z "$ServerName" ]; then
  echo "No Setup Environment Configuration. Skipping setup"
  exit 0
fi

LOG_FILE=$DOMDOCK_LOG_DIR/domino_server_setup.log
WGET_COMMAND="wget --connect-timeout=20" 
dominosilentsetup=$DOMINO_DATA_PATH/SetupProfile.pds
dominoprofileedit="./java -cp cfgdomserver.jar lotus.domino.setup.DominoServerProfileEdit"

# In case this is an additional server in an existing environment switch to different pds file
# because variable isFirstServer can not be changed programmatically.

if [ "$isFirstServer" = "false" ]; then
  dominosilentsetup=$DOMINO_DATA_PATH/SetupProfileSecondServer.pds
fi

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

secure_move_file()
{
  # Routine to move a file with proper error checks and warnings

  # Check if source file is present
  if [ ! -e "$1" ]; then
    log "Cannot rename [$1] - file does not exist"
    return 1
  fi

  # Check if target already exist and try to remove first
  if [ -e "$2" ]; then

    rm -f "$2" > /dev/null 2>&1

    if [ -e "$2" ]; then
      log "Cannot rename [$1] to [$2]  - target cannot be removed"
      return 1
    else
      log "Replacing file [$2] with [$1]"
    fi

  else
    log "Renaming file [$1] to [$2]"
  fi

  # Now copy file
  cp -f "$1" "$2" > /dev/null 2>&1

  if [ -e "$2" ]; then

    # Try to remove source file after copy
    rm -f "$1" > /dev/null 2>&1

    if [ -e "$1" ]; then
      log "Warning: cannot remove source file [$1]"
    fi

    return 0

  else
    log "Error copying file [$1] to [$2]"
    return 1
  fi

}

download_file ()
{
  local DOWNLOAD_URL=$1
  local DOWNLOAD_FILE=$2
  local HEADER=

  if [ ! -z "$3" ]; then
    HEADER="$3: " 
  fi

  if [ -z "$DOWNLOAD_FILE" ]; then
    log "Error: No download file specified!"
    exit 1
  fi

  WGET_RET_OK=`$WGET_COMMAND -S --spider "$DOWNLOAD_URL" 2>&1 | grep 'HTTP/1.1 200 OK'`
  if [ -z "$WGET_RET_OK" ]; then
    log "Error: Download file does not exist [$DOWNLOAD_FILE]"
    exit 1
  fi

  if [ -e "$DOWNLOAD_FILE" ]; then
    log "Replacing existing file [$DOWNLOAD_FILE]"
    rm -f "$DOWNLOAD_FILE"
  fi

  $WGET_COMMAND "$DOWNLOAD_URL" 2>/dev/null

  if [ "$?" = "0" ]; then
    log "${HEADER}Successfully downloaded: [$DOWNLOAD_FILE]"
    return 0
  else
    log "$[HEADER]File [$DOWNLOAD_FILE] not downloaded correctly from [$DOWNLOAD_URL]"
    exit 1
  fi
}

get_secret_via_http()
{
  WGET_RET_OK=`$WGET_COMMAND -S --spider "$2" 2>&1 | grep 'HTTP/1.1 200 OK'`
  if [ -z "$WGET_RET_OK" ]; then
    log "Fatal Error: Download file does not exist [$2] - Cannot read it into [$1]"
    exit 1
  fi

  SECRET_RET=`$WGET_COMMAND -qO- $2 2>/dev/null`
}

get_secret_via_file()
{
  local SECRET_FILE=`echo $2|cut -d":" -f2`
  if [ ! -r "$SECRET_FILE" ]; then
    log "Fatal Error: Cannot read file [$SECRET_FILE] into var [$1]"
    exit 1
  fi 

  SECRET_RET=`cat $SECRET_FILE`
  rm -f "$SECRET_FILE" 2>/dev/null
  if [ -e "$SECRET_FILE" ]; then
    log "Warning: Cannot remove Secret File [$SECRET_FILE]"
  fi
}

get_secret_var ()
{
  local S1=$1
  local S2=${!1}
  SECRET_RET=

  if [ -z "$S1" ]; then return 0; fi
  if [ -z "$S2" ]; then return 0; fi

  case "$S2" in
    http:*|https:*)
      get_secret_via_http "$S1" "$S2"
      ;;

    file:*)
      get_secret_via_file "$S1" "$S2"
      ;;
    *)
      SECRET_RET=$S2
      ;;
  esac  
}

replace_secret_vars()
{
  get_secret_var AdminPassword
  AdminPassword=$SECRET_RET

  get_secret_var ServerPassword
  ServerPassword=$SECRET_RET

  get_secret_var OrganizationPassword
  OrganizationPassword=$SECRET_RET

  get_secret_var OrgUnitPassword
  OrgUnitPassword=$SECRET_RET

  unset SECRET_RET
}

download_file_link()
{
  local S1=$1
  local S2=${!1}
  RET_DOWNLOADED_FILE=

  case "$S2" in
    http:*|https:*)
      RET_DOWNLOADED_FILE=`basename $S2`
      download_file "$S2" "$RET_DOWNLOADED_FILE" "$1"
      ;;
    *)
      RET_DOWNLOADED_FILE=$S2
      ;;
  esac
}

check_kyr_name()
{
  # check if kyr file has .kyr extension and generate matching .sth file
  local fname
  local ext

  if [ -z "DominoKyrFile" ]; then
    DominoSthFile=
    return 0
  fi

  fname=`echo $DominoKyrFile | awk -F"." '{print $1}'`
  ext=`echo $DominoKyrFile | awk -F"." '{print $2}'`

  if [ -z "$ext" ]; then
    DominoKyrFile=$DominoKyrFile.kyr
  fi

  DominoSthFile=$fname.sth

  return 0
}

check_download_file_links()
{
  # Donwload ID files if they start with http(s):
  download_file_link OrganizationIDFile
  OrganizationIDFile=$RET_DOWNLOADED_FILE

  download_file_link OrgUnitIDFile
  OrganizationIDFile=$RET_DOWNLOADED_FILE

  download_file_link ServerIDFile
  ServerIDFile=$RET_DOWNLOADED_FILE

  download_file_link AdminIDFile
  AdminIDFile=$RET_DOWNLOADED_FILE

  download_file_link SafeIDFile
  SafeIDFile=$RET_DOWNLOADED_FILE

  # Download kyr file 
  if [ ! -z "$DominoKyrFile" ]; then

    check_kyr_name

    download_file_link DominoKyrFile
    DominoKyrFile=$RET_DOWNLOADED_FILE

    download_file_link DominoSthFile
    DominoSthFile=$RET_DOWNLOADED_FILE
  fi

  return 0
}

# --- Main Logic ---

NOW=`date`
header "$NOW"

# Switch to data directory for downloads
cd $DOMINO_DATA_PATH 

# If CustomNotesdataZip file downlaod URL defined, download from remote location and unzip 
download_file_link CustomNotesdataZip
CustomNotesdataZip=$RET_DOWNLOADED_FILE

# Expand & delete ZIP
if [ ! -z "$CustomNotesdataZip" ]; then
  if [ -r "$CustomNotesdataZip" ]; then
    log "Extracting custom notesdata file [$CustomNotesdataZip]"

    log "---------------------------------------"
    unzip -o "$CustomNotesdataZip"
    rm -f "$CustomNotesdataZip"
    log "---------------------------------------"
  else
    log "Custom notesdata [$CustomNotesdataZip] not found!"
  fi
fi

# Replace secret variables with file content or http download
replace_secret_vars

# Download ID files if http download specified
check_download_file_links

# Rensure server.id name is always default name and rename if needed
if [ -e "$ServerIDFile" ]; then
  if [ ! "$ServerIDFile" = "server.id" ]; then
    secure_move_file "$ServerIDFile" "server.id"
  fi
fi

# Ensure it is set, even not specified
ServerIDFile=server.id

# Switch to executable directory for setup
cd $Notes_ExecDirectory

[ ! -z "$AdminFirstName" ] && $dominoprofileedit -AdminFirstName "$AdminFirstName" $dominosilentsetup
[ ! -z "$AdminIDFile" ] && $dominoprofileedit -AdminIDFile "$AdminIDFile" $dominosilentsetup
[ ! -z "$AdminLastName" ] && $dominoprofileedit -AdminLastName "$AdminLastName" $dominosilentsetup
[ ! -z "$AdminMiddleName" ] && $dominoprofileedit -AdminMiddleName "$AdminMiddleName" $dominosilentsetup
[ ! -z "$AdminPassword" ] && $dominoprofileedit -AdminPassword "$AdminPassword" $dominosilentsetup
[ ! -z "$CountryCode" ] && $dominoprofileedit -CountryCode "$CountryCode" $dominosilentsetup
[ ! -z "$DominoDomainName" ] && $dominoprofileedit -DominoDomainName "$DominoDomainName" $dominosilentsetup
[ ! -z "$HostName" ] && $dominoprofileedit -HostName "$HostName" $dominosilentsetup
[ ! -z "$OrgUnitIDFile" ] && $dominoprofileedit -OrgUnitIDFile "$OrgUnitIDFile" $dominosilentsetup
[ ! -z "$OrgUnitName" ] && $dominoprofileedit -OrgUnitName "$OrgUnitName" $dominosilentsetup
[ ! -z "$OrgUnitPassword" ] && $dominoprofileedit -OrgUnitPassword "$OrgUnitPassword" $dominosilentsetup
[ ! -z "$OrganizationIDFile" ] && $dominoprofileedit -OrganizationIDFile "$OrganizationIDFile" $dominosilentsetup
[ ! -z "$OrganizationName" ] && $dominoprofileedit -OrganizationName "$OrganizationName" $dominosilentsetup
[ ! -z "$OrganizationPassword" ] && $dominoprofileedit -OrganizationPassword "$OrganizationPassword" $dominosilentsetup
[ ! -z "$OtherDirectoryServerAddress" ] && $dominoprofileedit -OtherDirectoryServerAddress "$OtherDirectoryServerAddress" $dominosilentsetup
[ ! -z "$OtherDirectoryServerName" ] && $dominoprofileedit -OtherDirectoryServerName "$OtherDirectoryServerName" $dominosilentsetup
[ ! -z "$ServerIDFile" ] && $dominoprofileedit -ServerIDFile "$ServerIDFile" $dominosilentsetup
[ ! -z "$ServerName" ] && $dominoprofileedit -ServerName "$ServerName" $dominosilentsetup
[ ! -z "$SystemDatabasePath" ] && $dominoprofileedit -SystemDatabasePath "$SystemDatabasePath" $dominosilentsetup
[ ! -z "$ServerPassword" ] && $dominoprofileedit -ServerPassword "$ServerPassword" $dominosilentsetup

header "Silent Setup Settings"
$dominoprofileedit -dump $dominosilentsetup >> $LOG_FILE
log

header "Starting Domino Server Silent Setup"

cd $DOMINO_DATA_PATH 
$LOTUS/bin/server -silent $dominosilentsetup 

if [ -z `grep -i "ServerSetup=" $DOMINO_DATA_PATH/notes.ini` ]; then
  log_space "Silent Server Setup unsuccessful -- check [$DOMINO_DATA_PATH/setuplog.txt] for details"
else
  log_space "Silent Server Setup done"
fi

# Add notes.ini variables if requested
if [ ! -z "$Notesini" ]; then
  echo $Notesini >> $DOMINO_DATA_PATH/notes.ini
  
  header "Adding notes.ini Settings"
  echo $Notesini >> $LOG_FILE
  log
fi

# If config.json file downlaod URL defined, download from remote location and set variable to downloaded filename

download_file_link ConfigFile
ConfigFile=$RET_DOWNLOADED_FILE

if [ ! -z "$ConfigFile" ]; then
  if [ -e "$ConfigFile" ]; then

    header "Using [$ConfigFile] for Server Configuration"

    $LOTUS/bin/java -jar ./DominoUpdateConfig.jar "$ConfigFile" >> $LOG_FILE
    log 
  else
    log "ConfigFile [$ConfigFile] not found!"
  fi
fi

if [ ! -e keyfile.kyr ]; then
  header "Creating Domino Key Ring File from local CA"
  ./create_ca_kyr.sh
fi


# .oO Neuralizer .oO
# Cleaning up environment variabels & history to reduce exposure of sensitive data

unset RET_DOWNLOADED_FILE
unset isFirstServer
unset AdminFirstName
unset AdminIDFile
unset AdminLastName
unset AdminMiddleName
unset AdminPassword
unset CountryCode
unset DominoDomainName
unset HostName
unset OrgUnitIDFile
unset OrgUnitName
unset OrgUnitPassword
unset OrganizationIDFile
unset OrganizationName
unset OrganizationPassword
unset OtherDirectoryServerAddress
unset OtherDirectoryServerName
unset ServerIDFile
unset ConfigFile 
unset SafeIDFile
unset ServerName
unset ServerPassword
unset SystemDatabasePath
unset Notesini

if [ -e ~/.bash_history ]; then
  cat /dev/null > ~/.bash_history
fi

history -c

exit 0
