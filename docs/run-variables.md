
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
  - [DominoKyrFile](#dominokyrfile)
  - [DominoPemFile](#dominopemfile)
  - [SPECIAL_WGET_ARGUMENTS](#specialwgetarguments)

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

Intended to be used for deploying *.ntf files that will be used further on for auto-configuration of the Domino server.

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

### DominoKyrFile
Optional paramter to define an existing Domino SSL Key Ring file in KYR format with path and file name to be imported when starting a new container. 

Filename only: expects the file to be located inside of the Domino data directory
URL with filename: will download the file from the URL specified and use it within the container.

usage:
* DominoKyrFile=http://10.11.12.13/software/server_all.pem 

### DominoPemFile
Optional paramter to define an existing Domino SSL Key Ring file in PEM format with path and file name to be imported when starting a new container. 
The PEM file will be converted into *.kyr format.

Filename only: expects the file to be located inside of the Domino data directory
URL with filename: will download the file from the URL specified and use it within the container.
Supports basic authentication

usage:
* DominoPemFile=http://192.168.96.170/software/server_all.pem 
* DominoKyrFile=https://user:password@www.acme.com/software/cert.pem

### SPECIAL_WGET_ARGUMENTS
Optional parameter that will be passed on to wget. 
Useful when any file needs to be downloaded from an URL which is not using a trusted SSL certificate.

usage:
* SPECIAL_WGET_ARGUMENTS="--no-check-certificate"
