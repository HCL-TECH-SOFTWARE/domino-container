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

if [ -z "$ServerName" ]; then
  echo "No Setup Environment Configuration. Skipping setup"
  exit 0
fi

dominosilentsetup=/local/notesdata/SetupProfile.pds
dominoprofileedit="./java -cp cfgdomserver.jar lotus.domino.setup.DominoServerProfileEdit"

cd /opt/ibm/domino/notes/latest/linux/
echo $dominoprofileedit -AdminFirstName $AdminFirstName $dominosilentsetup

[ ! -z "$isFirstServer" ] && $dominoprofileedit -isFirstServer $isFirstServer $dominosilentsetup
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

cd /local/notesdata 
touch setuplog.txt 
/opt/ibm/domino/bin/server -silent $dominosilentsetup /local/notesdata/setuplog.txt

# add notes.ini variables if requested
if [ ! -z "$Notesini" ]; then
	echo $Notesini >> /local/notesdata/notes.ini
	unset Notesini
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
unset ServerName
unset SystemDatabasePath
unset ServerPassword

cat /dev/null > ~/.bash_history && history -c

exit 0
