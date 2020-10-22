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

# ServerName variable or Auto Config is the configuration trigger
if [ -z "$ServerName" ] && [ -z "$SetupAutoConfigure" ]; then
  echo "No Setup Environment Configuration -- Skipping setup"
  exit 0
fi

LOG_FILE=$DOMDOCK_LOG_DIR/domino_server_setup.log
CONSOLE_LOG=$DOMINO_DATA_PATH/IBM_TECHNICAL_SUPPORT
WGET_COMMAND="wget --connect-timeout=10 --tries=1 $SPECIAL_WGET_ARGUMENTS"
CURL_CMD="curl --silent --fail --connect-timeout 15 --max-time 300 $SPECIAL_CURL_ARGS"

dominosilentsetup=$DOMDOCK_DIR/SetupProfile.pds
dominoprofileedit="./java -cp cfgdomserver.jar lotus.domino.setup.DominoServerProfileEdit"

# In case this is an additional server in an existing environment switch to different pds file
# because variable isFirstServer can not be changed programmatically.

if [ "$isFirstServer" = "false" ]; then
  dominosilentsetup=$DOMDOCK_DIR/SetupProfileSecondServer.pds
fi


log()
{
  echo "$@" >> $LOG_FILE
}


log_space()
{
  echo  >> $LOG_FILE
  echo "$@" >> $LOG_FILE
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
  echo "$@" >> $LOG_FILE
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

  $CURL_CMD -o /dev/null --head "$DOWNLOAD_URL"
  if [ ! "$?" = "0" ]; then
    log "Error: Download file does not exist [$DOWNLOAD_FILE]"
    exit 1
  fi

  log "[download:$DOWNLOAD_FILE]"
  if [ -e "$DOWNLOAD_FILE" ]; then
    log "Replacing existing file [$DOWNLOAD_FILE]"
    rm -f "$DOWNLOAD_FILE"
  fi

  $CURL_CMD "$DOWNLOAD_URL" -o $DOWNLOAD_FILE

  if [ "$?" = "0" ]; then
    log "${HEADER}Successfully downloaded: [$DOWNLOAD_FILE]"
    return 0
  else
    log "$[HEADER]File [$DOWNLOAD_FILE] not downloaded correctly from [$DOWNLOAD_URL]"
    return 1
  fi
}


download_file_link()
{
  local S1=$1
  local S2=${!1}

  case "$S2" in

    http:*|https:*)
      local FILE_NAME=`basename $S2`
      export $1=$FILE_NAME
      download_file "$S2" "$FILE_NAME"

      if [ $? -eq 1 ]; then
        export $1=
      fi
      ;;

    *)
      export $1=$S2
      ;;
  esac
}


get_secret_via_http()
{
  if $CURL_CMD -o /dev/null --head "$DOWNLOAD_URL"; then
    log "Cannot download [$2]"
    exit 1
  fi

  export $1=`$CURL_CMD "$DOWNLOAD_URL"`
}

get_secret_via_file()
{
  local SECRET_FILE=`echo $2|cut -d":" -f2`
  if [ ! -r "$SECRET_FILE" ]; then
    log "File not found [$SECRET_FILE]"
    exit 1
  fi

  export $1=`cat $SECRET_FILE`
}

get_secret_var ()
{
  local S1=$1
  local S2=${!1}

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
      export $1=$S2
      ;;
  esac
}

replace_secret_vars()
{
  get_secret_var AdminPassword
  get_secret_var ServerPassword
  get_secret_var OrganizationPassword
  get_secret_var OrgUnitPassword
}

download_file_link()
{
  local S1=$1
  local S2=${!1}

  case "$S2" in
    http:*|https:*)
      export $1=`basename $S2`
      download_file "$S2" "$1"

      if [ $? -eq 1 ]; then
        export $1= 
      fi

      ;;
    *)
      export $1=$S2
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

  fname=`echo $DominoKyrFile | awk -F"." '{print $NF}'`
  ext=`echo $DominoKyrFile | awk -F"." '{print $NF}'`

  if [ -z "$ext" ]; then
    DominoKyrFile=
    DominoSthFile=
    return 0
  fi

  return 0
}


check_download_file_links()
{
  # Donwload ID files if they start with http(s):

  download_file_link OrganizationIDFile
  download_file_link OrgUnitIDFile
  download_file_link ServerIDFile
  download_file_link AdminIDFile
  download_file_link SafeIDFile
  download_file_link DominoTrialKeyFile

  download_file_link SetupAutoConfigureParams

  # Download kyr file 
  if [ -n "$DominoKyrFile" ]; then

    check_kyr_name

    download_file_link DominoKyrFile

    if [ -n DominoSthFile ]; then
      download_file_link DominoSthFile
    fi

    return 0
  fi

  if [ -n "$DominoPemFile" ]; then

    # Create keyring.kyr from PEM
    download_file_link DominoPemFile
    header "creating keyring from [$DominoPemFile]"

    $DOMDOCK_SCRIPT_DIR/create_keyring.sh "$DominoPemFile"
    rm -f "$DominoPemFile"
  fi

  return 0
}


wait_for_string()
{
  local MAX_SECONDS=
  local FOUND=
  local COUNT=$4
  local seconds=0

  if [ -z "$1" ]; then
    return 0
  fi

  if [ -z "$2" ]; then
    return 0
  fi

  if [ -z "$3" ]; then
    MAX_SECONDS=10
  else
    MAX_SECONDS=$3
  fi

  if [ -z "$4" ]; then
    COUNT=1
  fi

  log
  log "Waiting for [$2] in [$1] (max: $MAX_SECONDS sec)"

  while [ "$seconds" -lt "$MAX_SECONDS" ]; do

    FOUND=`grep -e "$2" "$1" 2>/dev/null | wc -l`

    if [ "$FOUND" -ge "$COUNT" ]; then
      return 0
    fi

    sleep 2
    seconds=`expr $seconds + 2`
    if [ `expr $seconds % 10` -eq 0 ]; then
      echo " ... waiting $seconds seconds"
    fi

  done

}


# --- Main Logic ---

NOW=`date`
header "$NOW"

# Switch to data directory for downloads
cd $DOMINO_DATA_PATH 

# If CustomNotesdataZip file downlaod URL defined, download from remote location and unzip 
download_file_link CustomNotesdataZip

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


# Get Git Repo if configured into /local/git (temporary for setup)

if [ ! -z "$GitSetupRepo" ]; then
  if [ -e /usr/bin/git ]; then
    /usr/bin/git clone "$GitSetupRepo" /local/git 
    if [ -e /local/git/notesdata ]; then
      cp -R /local/git/notesdata/* /local/notesdata 
    fi
  else
    log "skipping Git Repo -- No git installed!"
  fi
fi

# Git setup script can be used to run commands to copy and modify files

if [ ! -z "$GitSetupScript" ]; then
  if [ -x "$GitSetupScript" ]; then
    log "Executing [$GitSetupScript]"
    log "---------------------------------------"
    $GitSetupScript
    log "---------------------------------------"
  fi
fi


# Replace secret variables with file content or http download
replace_secret_vars

# Download ID files if http download specified
check_download_file_links

# Ensure server.id name is always default name and rename if needed
if [ -e "$ServerIDFile" ]; then
  if [ ! "$ServerIDFile" = "server.id" ]; then
    secure_move_file "$ServerIDFile" "server.id"
  fi
fi

# Ensure it is set, even not specified
ServerIDFile=server.id

# Ensure trial key is named "trial_account.txt"
if [ -e "$DominoTrialKeyFile" ]; then
  if [ ! "$DominoTrialKeyFile" = "trial_account.txt" ]; then
    secure_move_file "$DominoTrialKeyFile" "trial_account.txt"
  fi
fi

if [ ! -e keyfile.kyr ]; then

  if [ -z "$SkipKyrCreate" ]; then
    header "Creating Domino Key Ring File from local CA"
    $DOMDOCK_SCRIPT_DIR/create_ca_kyr.sh
  fi
fi

if [ -n "$SetupAutoConfigure" ]; then

  if [ -z "$HostName" ]; then
    if [ -x /usr/bin/hostname ]; then
      export HostName=`hostname`
    else
      export HostName=`cat /proc/sys/kernel/hostname`
    fi
  fi

  log  "SetupAutoConfigureParams: [$SetupAutoConfigureParams]"
  echo "SetupAutoConfigureParams: [$SetupAutoConfigureParams]"

  cd $DOMINO_DATA_PATH 
  header "Starting Domino Server Auto Setup"
  $LOTUS/bin/server -a $SetupAutoConfigureParams &

  # Wait until server started before last configuration steps

  wait_for_string $CONSOLE_LOG "Server started on physical node" 30 

  # Remove json config file
  if [ -n "$SetupAutoConfigureParams" ]; then
    remove_file $SetupAutoConfigureParams
  fi

else

  header "Starting Domino Server Silent Setup"

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

  cd $DOMINO_DATA_PATH 
  $LOTUS/bin/server -silent $dominosilentsetup 
fi

header "Done"

if [ -z `grep -i "ServerSetup=" $DOMINO_DATA_PATH/notes.ini` ]; then
  log_space "Server Setup unsuccessful -- check [$DOMINO_DATA_PATH/setuplog.txt] for details"
else
  log_space "Server Setup done"
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

if [ ! -z "$ConfigFile" ]; then
  if [ -e "$ConfigFile" ]; then

    header "Using [$ConfigFile] for Server Configuration"

    $LOTUS/bin/java -jar ./DominoUpdateConfig.jar "$ConfigFile" >> $LOG_FILE
    log 
  else
    log "ConfigFile [$ConfigFile] not found!"
  fi
fi

# .oO Neuralizer .oO
# Cleaning up environment variabels & history to reduce exposure of sensitive data

# Remove temporary git download
if [ -e /local/git ]; then
  rm -rf /local/git
fi

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

unset SetupAutoConfigure
unset ServerType
unset AdminUserIDPath
unset CertifierPassword
unset DomainName
unset OrgName

if [ -e ~/.bash_history ]; then
  cat /dev/null > ~/.bash_history
fi

history -c

exit 0
