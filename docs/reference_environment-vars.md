---
layout: default
title: "Runtime Variables"
nav_order: 2
parent: "Reference"
description: "Container environment variables"
has_children: false
---

# Introduction

Starting with Domino 12 the Community image uses Domino One-Touch variables instead of the legacy PDS file configuration.  
The variables used have been aligned with Domino One-Touch setup.

For details refer to the [HCL product documentation](https://help.hcltechsw.com/domino/12.0.0/admin/inst_onetouch.html)


## One-Touch parameters with additional functionality

### Download files

The following variables download files from remote files with http:// and https:// syntax.  
Files are downloaded and the name of the file will be used as the file name.  
The variable is replaced with the download file location on disk.  
After download the variable is replaced with the password downloaded or read from file.

```
- SERVERSETUP_ORG_CERTIFIERIDFILEPATH
- SERVERSETUP_ORG_ORGUNITIDFILEPATH
- SERVERSETUP_SERVER_IDFILEPATH
- SERVERSETUP_ADMIN_IDFILEPATH
- SERVERSETUP_SECURITY_TLSSETUP_IMPORTFILEPATH
```

### Remote password download

The following variables retrieve passwords from files or from remote http:// and https:// locations.  
After download the variable is replaced with the password downloaded or read from file.

```
- SERVERSETUP_ADMIN_PASSWORD
- SERVERSETUP_SERVER_PASSWORD
- SERVERSETUP_ORG_CERTIFIERPASSWORD
- SERVERSETUP_ORG_ORGUNITPASSWORD
- SERVERSETUP_SECURITY_TLSSETUP_IMPORTFILEPASSWORD
- SERVERSETUP_SECURITY_TLSSETUP_EXPORTPASSWORD
```

## Additional parameters

The following variables are complementing the One-Touch functionality

### SetupAutoConfigureParams

Download a JSON One-Touch file

### CustomNotesdataZip

Path and filename of a zip file containing files that will be extracted into the Domino Data directory.
Values starting with 'http' will be handled as URL. The file will be downloaded from this URL.

