
- [Introduction](#introduction)
- [Special](#special)
  - [Notesini](#notesini)
- [Environment Variables](#environment-variables)
  - [isFirstServer](#isfirstserver)
  - [AdminFirstName](#adminfirstname)
  - [AdminIDFile](#adminidfile)
  - [AdminLastName](#adminlastname)
  - [AdminMiddleName](#adminmiddlename)
  - [AdminPassword](#adminpassword)
  - [CountryCode](#countrycode)
  - [CustomNotesdataZip](#customnotesdatazip)
  - [ConfigFile](#configfile)
  - [DominoDomainName](#dominodomainname)
  - [HostName](#hostname)
  - [OrgUnitIDFile](#orgunitidfile)
  - [OrgUnitName](#orgunitname)
  - [OrgUnitPassword](#orgunitpassword)
  - [OrganizationIDFile](#organizationidfile)
  - [OrganizationName](#organizationname)
  - [OrganizationPassword](#organizationpassword)
  - [OtherDirectoryServerAddress](#otherdirectoryserveraddress)
  - [OtherDirectoryServerName](#otherdirectoryservername)
  - [ServerIDFile](#serveridfile)
  - [ServerName](#servername)
  - [SystemDatabasePath](#systemdatabasepath)
  - [ServerPassword](#serverpassword)

## Introduction
This article describes the different variables that can be passed to the container when using Docker RUN

## Special
### Notesini
A list of Notes.ini variables and values that will be added to the Notes.ini file directly before the first server startup.

Default value : (empty)

Used by : 
* docker_prestart.sh

## Environment Variables

### isFirstServer 
Defines if this is the first server of the domain or not. 
Values :
* true
* false 

Default value : true

Used by : 
* docker_prestart.sh

### AdminFirstName
First name of the Admin account that will be created by the server setup routine.

Used by : 
* docker_prestart.sh

### AdminIDFile
Path and file name of NotesID file of the Domino administrator.

Used by : 
* docker_prestart.sh
  
### AdminLastName
Last name of the admin account that will be created by the server setup routine.

Used by : 
* docker_prestart.sh

### AdminMiddleName
Middle name of the admin account that will be created by the server setup routine.

Default value : (empty)

Used by : 
* docker_prestart.sh

### AdminPassword
Password that will be used for the Admin account

Used by : 
* docker_prestart.sh
  
### CountryCode
ISO Countrycode

Default value : (empty)

Used by : 
* docker_prestart.sh

### CustomNotesdataZip
Path and filename of a zip file containing files that will be extracted into the Domino Data directory.
Values starting with 'http' will be handled as URL. The file will be downloaded from this URL.

Intended to be used for deploying *.ntf and config.json file that will be used further on for auto-configuration of the Domino server.

### ConfigFile
File name of the JSON file that will be used for automated server configuration.

Usage:
- file name only : file is expected to be located in the Domino data directory.
- path and file name : path and file name will be used
- Values starting with 'http' will be handled as URL. The file will be downloaded from this URL.

Useful in combination with CustomNotesdataZip since the zip file will be extracted before searching for the JSON config file. e.g.: ConfigFile=config.json

### DominoDomainName
Name of the Domino domain

Used by : 
* docker_prestart.sh

### HostName
Domino Server network host name

Used by : 
* docker_prestart.sh

### OrgUnitIDFile
Path and file name of an existing organization unit certifier ID file.

Used by : 
* docker_prestart.sh

### OrgUnitName
Name of the organization unit (OU). An OrgUnit Certifier ID will be created from scratch if this is the first server of the domain.

Used by : 
* docker_prestart.sh

### OrgUnitPassword
Password of the organization unit certifier ID file.

Used by : 
* docker_prestart.sh

### OrganizationIDFile
Path and file name of an existing organization / root certifier ID file.

Used by : 
* docker_prestart.sh

### OrganizationName
Name of the root certifier. A certifier ID will be created from scratch if this is the first server of the domain.

Used by : 
* docker_prestart.sh

### OrganizationPassword
Password of the organization / root certifier.

Used by : 
* docker_prestart.sh

### OtherDirectoryServerAddress
Network address (IP or FQDN) of the Domino server from which the installation process can obtain a replica of the Domino Directory (names.nsf)

Used by : 
* docker_prestart.sh

### OtherDirectoryServerName
Hierarchical name of the Domino server from which the installation process can obtain a replica of the Domino Directory (names.nsf)

Used by : 
* docker_prestart.sh

### ServerIDFile
Path and file name of an existing server ID file.

Default value : (empty)

Used by : 
* docker_prestart.sh

### ServerName
Common Name of the Domino Server - if this is the first server of the Domain the ID file will be created by the server setup otherwise you have to supply the ServerIDFile. 

Used by : 
* docker_prestart.sh
  
### SystemDatabasePath

Used by : 
* docker_prestart.sh

### ServerPassword
Password of the server id file (if any)

Default value : (empty)
 
Used by : 
* docker_prestart.sh