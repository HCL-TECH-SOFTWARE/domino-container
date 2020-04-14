- [Introduction](#introduction)
- [Header](#header)
- [Elements](#elements)
- [Notes.ini](#notesini)
- [Database](#database)
  - [Database ACL](#database-acl)
  - [Database Agents](#database-agents)
  - [Database properties](#database-properties)
  - [Documents](#documents)
    - [Document fields](#document-fields)
- [Test Users](#test-users)
- [Mustache](#mustache)

# Introduction
The config.json file can be used to describe the Domino server configuration in order to be applied automatically at server startup.

File Format : JSON

For a brief introduction to the file format take a look at [this video](https://www.youtube.com/watch?v=1idSGncUi08)

<a href="http://www.youtube.com/watch?feature=player_embedded&v=1idSGncUi08
" target="_blank"><img src="http://img.youtube.com/vi/1idSGncUi08/0.jpg" 
alt="JSON crash course" width="240" height="180" border="10" /></a>

# Header
The header of the file is supposed to provide generic information about this configuration. It is used for documentation purpose only.

Optional elements:
* title - string, defining the name of this configuration. 
* owner - string, listing the author of this configuration.
* debug - boolean (true/false) for enabling debug output. Default = false

Example:
```json
    {
        "title": "My perfect server configuration",
        "owner": "Thomas Hampel",
        "debug": false
    }
```


# Elements
The following object structure is used at root level
* notesini
* databases
  * acl
  * agents
  * properties
  * documents
    * fields
* testusers
* (tbd)registration
  * (tbd)users
  * (tbd)servers
  * (tbd)certificates
  * (tbd)recertify


# Notes.ini
Object name "notesini"
Contains Notes.ini variable name and value in form of JSON name/value pairs.

Entry names will be translated to Notes.ini variable names and entry values translate to values.

Example:
```json
    "notesini": {
       "HTTPEnableMethods": "GET,POST,PUT,DELETE,HEAD",
       "ServerTasks": "Update,Replica,Router,AMgr,AdminP,http",
       "HTTPPublicURLs": "/iwaredir.nsf/*:.well-known*"
    }
```

# Database
Object name "databases" since there can be multiple databases on the system.
Contains multiple database entries in form of a JSON array.

Mandatory elements:
* filename - string containing file name and path, relative to the Domino data directory

Optional elements:
* create - boolean (true/false) indicating if the database shall be created from a template in case it does not already exist
* template - string, filename of the template that shall be used
* title - string containing the title of the database that will be applied
* signwithadminp - boolean (true/false) indicating if the database shall be signed by the current server ID using the AdminP task

Sub-level elements:
* acl
* agents
* properties
* documents

Example:
```json
    "databases": [
        {
            "create": true,
            "filename": "domcfg.nsf",
            "title": "Domino Web Server Configuration",
            "template": "domcfg5.ntf",
            "signwithadminp": true
        }
    ]
```

## Database ACL
Object name "acl" (singular) since there is only one ACL per database.
Contains multiple ACL entries in form of a JSON array
Mandatory elements:
* name - name of ACL entry. Will be created if it does not exist.
* level - Access level according to NotesACL class
* type - access type according to NotesACL class

Optional elements:
* flags - comma separated string of flags. Acceptable values are NotesACLEntry properties:
  * CanCreateDocuments
  * CanCreateLSOrJavaAgent
  * CanCreatePersonalAgent
  * CanCreatePersonalFolder
  * CanCreateSharedFolder
  * CanDeleteDocuments
  * CanReplicateOrCopyDocuments 
  * IsPublicReader
  * IsPublicWriter 
* roles - comma separated string with name of ACL roles that shall be assigned to the ACL entry.
Note: Role must exist in the ACL

Example:
```json
    "acl": [
        {
            "name": "-Default-",
            "level": "2",
            "type": "0"
        },
        {
            "name": "LocalDomainAdmins",
            "level": "6",
            "type": "0",
            "roles" : "Admin,SuperUser"
        }
    ]
```

## Database Agents
Object name : "agents" (multiple) 
Contains one or multiple agent definitions in form of a JSON array

Mandatory elements:
* name
* action - string defining what to do. Can be one of the following values: 
  * run
  * runonserver
  * sign
  * enable
  * (tbd) schedule

Example:
```json
    "agents" : [
        {
            "name" : "name-of-agent",
            "action" : "enable"
        },{
            "name" : "another-agent",
            "action" : "schedule"
        }
    ]
```

## Database properties
Object name : "properties" (multiple) defining the advanced database properties in form of JSON name/value pairs for a single database.

Database options according to https://help.hcltechsw.com/dom_designer/11.0.1/basic/H_SETOPTION_METHOD_DB.html

Property names are not case sensitive in this case.

Mandatory elements:
None

Optional elements:
* LZCOMPRESSION - boolean (true/false) uses LZ1 compression for attachments
* MAINTAINLASTACCESSED - boolean (true/false) maintains LastAccessed property
* MOREFIELDS - boolean (true/false) allows more fields in database
* NOHEADLINEMONITORS - boolean (true/false) doesn't allow headline monitoring
* NOOVERWRITE - boolean (true/false)) doesn't overwrite free space
* NORESPONSEINFO - boolean (true/false) doesn't support specialized response hierarchy
* NOTRANSACTIONLOGGING - boolean (true/false) disables transaction logging
* NOUNREAD - boolean (true/false) doesn't maintain unread marks
* OPTIMIZATION - boolean (true/false) enables document table bitmap optimization
* REPLICATEUNREADMARKSTOANY - boolean (true/false) replicates unread marks to all servers
and 
* USEDAOS - boolean (true/false)
* COMPRESSDESIGN - boolean (true/false)
* RESPONSETHREADHISTORY - boolean (true/false)
* REPLICATEUNREADMARKSNEVER - boolean (true/false)
* OUTOFOFFICEENABLED - boolean (true/false)
* NOSIMPLESEARCH - boolean (true/false)

Example:
```json
    "properties" : [
        {
            "usedaos" : true,
            "lzcompression" : true
        }
    ],
```

## Documents
Object name "documents" (multiple) as there most likely are be multiple documents in a single database.
Contains definition for documents in this database in form of a JSON array

Mandatory elements:
* fields - sub-level element described in another chapter

Optional elements:
* create - boolean (true/false) indicating if the document shall be created 
* computewithform - boolean (true/false) indicating if the document will be using all fields defined in the form 
* type - string, defining a known document type in the Domino directory. values can be one of the following
  * server
  * configuration
  * group

This example is updating the (current) server document to set the http homepage.

Example:
```json
    "documents": [
            {
                "create": true,
                "type": "server",
                "fields": [
                    {
                        "name": "HTTP_HomeURL",
                        "value": "/homepage"
                    }
                ]
            }
       ]
```
### Document fields
Object name "fields" (multiple)
Upstream object : document
Contains definition for fields and its values in this document in form of a JSON array

Mandatory elements:
* name - string defining the name of the field to be processed
* value - string 

Optional elements:
* append - boolean (true/false) indicating if the value shall be appended to an existing field. If set to false the current field value will be overwritten (if any). Defaults to false.
* isnames - boolean (true/false), declares the field to be of type NAMES. Defaults to false
* isreaders - boolean (true/false), declares the field to be of type READER/NAMES. Defaults to false 
* isauthors - boolean (true/false), declares the field to be of type AUTHOR/NAMES. Defaults to false
* isprotected - boolean (true/false), declares the field to protected so that only editors can modify the document. Default to false
* issigned - boolean (true/false), declares the field to signed when saving the document. Defaults to false

Example:
```json
    "fields": [
        {
            "name": "GroupType",
            "value": "0"
        },
        {
            "name": "Form",
            "value": "Group"
        },
        {
            "name": "ListName",
            "value": "Volt Authors"
        },
        {
            "append": true,
            "name": "Members",
            "value": "CN=Testuser Adams1/O=AMP",
            "isnames": true,
        },
        {
            "append": true,
            "name": "Members",
            "value": "CN=Testuser Adams2/O=AMP",
            "isnames": true,
        }
    ]
```

# Test Users
Object name "testusers" (multiple)
Allows the registration of users in the Domino Directory. All users will have the same first, lastname and password. A number is appended to the last name to create unique user names.

This example will create 30 test users, all named  Testuser Adams followed by a number. 
e.g. Testuser Adams1, Testuser Adams2, Testuser Adams3, and so on

Example:
```json
    "testusers": {
        "certifierPassword": "passw0rd",
        "count": 30,
        "lastName": "Adams",
        "firstName": "Testuser",
        "userPassword": "passw0rd"
     },
```

# Mustache
Object names and values in the JSON file can be replaced by environment variables using the mustache notation. Any value in double curly brackets {{}} will be replaced by the corresponding OS environment variable name

{{OSEnvironmentVariableName}}

All operating system environment variables that exist on the OS instance that Domino is running on can be used for this purpose.

Mandatory:
Variables in curly brackets must exist otherwise an error will be raised.

In the following example the firstname of the test users will be using the operating system host name environment variable. 

Example:
```json
    "testusers": {
        "certifierPassword": "passw0rd",
        "count": 30,
        "lastName": "Adams",
        "firstName": "{{hostname}}",
        "userPassword": "passw0rd"
     },
```