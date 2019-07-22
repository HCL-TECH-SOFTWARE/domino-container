#!/bin/sh
#
############################################################################
# (C) Copyright IBM Corporation 2015, 2019                                 #
#                                                                          #
# Licensed under the Apache License, Version 2.0 (the "License");          #
# you may not use this file except in compliance with the License.         #
# You may obtain a copy of the License at                                  #
#                                                                          #
#      http://www.apache.org/licenses/LICENSE-2.0                          #
#                                                                          #
# Unless required by applicable law or agreed to in writing, software      #
# distributed under the License is distributed on an "AS IS" BASIS,        #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. #
# See the License for the specific language governing permissions and      #
# limitations under the License.                                           #
#                                                                          #
############################################################################

# Configure server based on environment variables

if [ -z "$LOTUS" ]; then
  if [ -x /opt/hcl/domino/bin/server ]; then
    LOTUS=/opt/hcl/domino
  else
    LOTUS=/opt/ibm/domino
  fi
fi

if [ -z "$ServerName" ]; then
  echo "No Setup Environment Configuration. Skipping setup"
  exit 0
fi

WGET_COMMAND="wget --connect-timeout=20" 
dominosilentsetup=$DOMINO_DATA_PATH/SetupProfile.pds
dominoprofileedit="./java -cp cfgdomserver.jar lotus.domino.setup.DominoServerProfileEdit"

cd $Notes_ExecDirectory
echo $dominoprofileedit -AdminFirstName $AdminFirstName $dominosilentsetup

# in case this is an additional server in an existing environment switch to different pds file
# because variable isFirstServer can not be changed programmatically
[ ! -z "$isFirstServer" ] && if [ "false" = tr '[:upper:]' '[:lower:]' <<<"$isFirstServer"] ; then
  dominosilentsetup=$DOMINO_DATA_PATH/SetupProfileSecondServer.pds
fi

# download ID file if $ServerName contains a value that starts with "http"
download_file ()
{
  DOWNLOAD_URL=$1
  DOWNLOAD_FILE=$2

  if [ -z "$DOWNLOAD_FILE" ]; then
    log_error "No download file specified!"
    exit 1
  fi

  WGET_RET_OK=`$WGET_COMMAND -S --spider "$DOWNLOAD_URL" 2>&1 | grep 'HTTP/1.1 200 OK'`
  if [ -z "$WGET_RET_OK" ]; then
    echo "Download file does not exist [$DOWNLOAD_FILE]"
    return 0
  fi

  if [ -e "$DOWNLOAD_FILE" ]; then
    echo
    echo "Replacing existing file [$DOWNLOAD_FILE]"
    rm -f "$DOWNLOAD_FILE"
  fi

  $WGET_COMMAND "$DOWNLOAD_URL" 2>/dev/null

  if [ "$?" = "0" ]; then
    echo "Successfully downloaded: [$DOWNLOAD_FILE] "
    echo
    return 0
  else
    echo "File [$DOWNLOAD_FILE] not downloaded correctly"
    exit 1
  fi
}

# If server.id downlaod URL defined, download from remote location and set variable to server.id filename
case "$ServerIDFile" in
  http*)
    FileName=`basename $ServerIDFile`
    download_file "$ServerIDFile" "$FileName"
    ServerIDFile=$FileName
    ;;
esac

if [ -e "$ServerIDFile" ]; then
  echo ServerIDFile: [$ServerIDFile] exists
else
  echo ServerIDFile: [$ServerIDFile] does not exist!
fi 

[ ! -z "$AdminFirstName" ] && $dominoprofileedit -AdminFirstName $AdminFirstName $dominosilentsetup
[ ! -z "$AdminIDFile" ] && $dominoprofileedit -AdminIDFile $AdminIDFile $dominosilentsetup
[ ! -z "$AdminLastName" ] && $dominoprofileedit -AdminLastName $AdminLastName $dominosilentsetup
[ ! -z "$AdminMiddleName" ] && $dominoprofileedit -AdminMiddleName $AdminMiddleName $dominosilentsetup
[ ! -z "$AdminPassword" ] && $dominoprofileedit -AdminPassword $AdminPassword $dominosilentsetup
[ ! -z "$CountryCode" ] && $dominoprofileedit -CountryCode $CountryCode $dominosilentsetup
[ ! -z "$DominoDomainName" ] && $dominoprofileedit -DominoDomainName $DominoDomainName $dominosilentsetup
[ ! -z "$HostName" ] && $dominoprofileedit -HostName $HostName $dominosilentsetup
[ ! -z "$OrgUnitIDFile" ] && $dominoprofileedit -OrgUnitIDFile $OrgUnitIDFile $dominosilentsetup
[ ! -z "$OrgUnitName" ] && $dominoprofileedit -OrgUnitName $OrgUnitName $dominosilentsetup
[ ! -z "$OrgUnitPassword" ] && $dominoprofileedit -OrgUnitPassword $OrgUnitPassword $dominosilentsetup
[ ! -z "$OrganizationIDFile" ] && $dominoprofileedit -OrganizationIDFile $OrganizationIDFile $dominosilentsetup
[ ! -z "$OrganizationName" ] && $dominoprofileedit -OrganizationName $OrganizationName $dominosilentsetup
[ ! -z "$OrganizationPassword" ] && $dominoprofileedit -OrganizationPassword $OrganizationPassword $dominosilentsetup
[ ! -z "$OtherDirectoryServerAddress" ] && $dominoprofileedit -OtherDirectoryServerAddress $OtherDirectoryServerAddress $dominosilentsetup
[ ! -z "$OtherDirectoryServerName" ] && $dominoprofileedit -OtherDirectoryServerName $OtherDirectoryServerName $dominosilentsetup
[ ! -z "$ServerIDFile" ] && $dominoprofileedit -ServerIDFile $ServerIDFile $dominosilentsetup
[ ! -z "$ServerName" ] && $dominoprofileedit -ServerName $ServerName $dominosilentsetup
[ ! -z "$SystemDatabasePath" ] && $dominoprofileedit -SystemDatabasePath $SystemDatabasePath $dominosilentsetup
[ ! -z "$ServerPassword" ] && $dominoprofileedit -ServerPassword $ServerPassword $dominosilentsetup

echo "Silent setup of server with the following settings:"
$dominoprofileedit -dump $dominosilentsetup

cd $DOMINO_DATA_PATH 
touch setuplog.txt 
$LOTUS/bin/server -silent $dominosilentsetup $DOMINO_DATA_PATH/setuplog.txt

# add notes.ini variables if requested
if [ ! -z "$Notesini" ]; then
  echo $Notesini >> $DOMINO_DATA_PATH/notes.ini
  unset Notesini
fi

# If CustomNotesdataZip file downlaod URL defined, download from remote location and unzip 
case "$CustomNotesdataZip" in
  http*)
    FileName=`basename $CustomNotesdataZip`
    download_file "$CustomNotesdataZip" "$FileName"
    CustomNotesdataZip=$FileName
    ;;
esac

if [ ! -z "$CustomNotesdataZip" ]; then
  if [ -e "$CustomNotesdataZip" ]; then
    echo Extracting custom notesdata file [$CustomNotesdataZip]

    echo "---------------------------------------"
    unzip -o "$CustomNotesdataZip"
    rm -f "$CustomNotesdataZip"
    echo "---------------------------------------"
  else
    echo "Custom notesdata [$CustomNotesdataZip] not found!"
  fi
fi

# If config.json file downlaod URL defined, download from remote location and set variable to downloaded filename
case "$ConfigFile" in
  http*)
    FileName=`basename $ConfigFile`
    download_file "$ConfigFile" "$FileName"
    ConfigFile=$FileName
    ;;
esac

if [ ! -z "$ConfigFile" ]; then
  if [ -e "$ConfigFile" ]; then
    echo Using [$ConfigFile] for server configuration 

    echo "---------------------------------------"
    $LOTUS/bin/java -jar ./DominoUpdateConfig.jar "$ConfigFile"
    echo "---------------------------------------"
  else
    echo "ConfigFile [$ConfigFile] not found!"
  fi
fi

# cleaning up environment variabels as they might contain sensitive data
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
unset ServerName
unset SystemDatabasePath
unset ServerPassword

cat /dev/null > ~/.bash_history && history -c

exit 0
