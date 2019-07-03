
- [Introduction](#Introduction)
- [Special](#Special)
  - [Notesini](#Notesini)
- [Environment Variables](#Environment-Variables)
  - [isFirstServer](#isFirstServer)
  - [AdminFirstName](#AdminFirstName)
  - [AdminIDFile](#AdminIDFile)
  - [AdminLastName](#AdminLastName)
  - [AdminMiddleName](#AdminMiddleName)
  - [AdminPassword](#AdminPassword)
  - [CountryCode](#CountryCode)
  - [DominoDomainName](#DominoDomainName)
  - [HostName](#HostName)
  - [OrgUnitIDFile](#OrgUnitIDFile)
  - [OrgUnitName](#OrgUnitName)
  - [OrgUnitPassword](#OrgUnitPassword)
  - [OrganizationIDFile](#OrganizationIDFile)
  - [OrganizationName](#OrganizationName)
  - [OrganizationPassword](#OrganizationPassword)
  - [OtherDirectoryServerAddress](#OtherDirectoryServerAddress)
  - [OtherDirectoryServerName](#OtherDirectoryServerName)
  - [ServerIDFile](#ServerIDFile)
  - [ServerName](#ServerName)
  - [SystemDatabasePath](#SystemDatabasePath)
  - [ServerPassword](#ServerPassword)

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