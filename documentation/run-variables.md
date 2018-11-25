
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

Used by : 
* docker_prestart.sh

## Environment Variables

### isFirstServer 

Used by : 
* docker_prestart.sh

### AdminFirstName
First name of the Admin account that will be created by the server setup routine.

Used by : 
* docker_prestart.sh

### AdminIDFile

Used by : 
* docker_prestart.sh
  
### AdminLastName
Last name of the Admin account that will be created by the server setup routine.

Used by : 
* docker_prestart.sh

### AdminMiddleName

### AdminPassword
Password that will be used for the Admin account
Used by : 
* docker_prestart.sh
  
### CountryCode
ISO Countrycode

### DominoDomainName

Used by : 
* docker_prestart.sh

### HostName
Domino Server network host name

### OrgUnitIDFile

Used by : 
* docker_prestart.sh

### OrgUnitName

Used by : 
* docker_prestart.sh

### OrgUnitPassword

Used by : 
* docker_prestart.sh

### OrganizationIDFile

Used by : 
* docker_prestart.sh

### OrganizationName

Used by : 
* docker_prestart.sh

### OrganizationPassword

Used by : 
* docker_prestart.sh

### OtherDirectoryServerAddress

Used by : 
* docker_prestart.sh

### OtherDirectoryServerName

Used by : 
* docker_prestart.sh

### ServerIDFile

Used by : 
* docker_prestart.sh

### ServerName
Common Name of the Domino Server ID that will be created by the server setup.
Used by : 
* docker_prestart.sh
  
### SystemDatabasePath

Used by : 
* docker_prestart.sh

### ServerPassword

Used by : 
* docker_prestart.sh