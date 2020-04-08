# Config.json
The config.json file can be used to describe the Domino server configuration in order to be applied automatically at server startup.

# General information
File Format : JSON

# Structure

## header
* title - string
* owner - string
* debug - boolean

## Body Elements

* notesini - name value pairs
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


### Database
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

### Database ACL
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

### Database Agents
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

### Database properties
Object name : "properties" (multiple) defining the advanced database properties for a single database.

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

### Documents
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

### testusers
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

## Mustache
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