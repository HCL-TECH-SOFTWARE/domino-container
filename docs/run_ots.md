---
layout: default
title: "OTS integration"
nav_order: 3
description: "Domino Container OTS integration"
parent: "Run Image"
has_children: false
---

# Domino Container OTS integration

Since Domino 12.0 One Touch Setup (OTS) is the preferred and fully automated way to deploy Domino.
The container project fully supports OTS in a couple of ways.

## Pass environment variables to the container at first startup

This is the most simple approach but would end up with sensitive information inside the container environment variables.
Environment variable setup is a very simple and basic configuration option without providing the full potential of OTS available with JSON files

## Use a OTS JSON file to configure the container at first startup

Tthe container image also supports passing a OTS JSON file to the container in multiple ways.

The JSON OTS file can be either a full JSON file. Or a file containing Domino OTS environment variable definitions replaced on the fly when the container is started.
Still the same security concern remain when passing environment variables to be replaced in the JSON file.

The recommended way is to pass a complete JSON file without place-holder variables to the container. 
For an additional server configuration which does not need to provide sensitive data like certifier or admin passwords, passing environment variables is still a valid approach. 

The OTS file and also the OTS template file can be passed in different ways to the container at startup.

### 1. Mount a file into the container

- On Docker this would be a volume mount
- On Kubernetes it would be config map or secret mounted into the container

Be aware that the file remains in place for the complete run-time.


### 2. Get the file copied into the container at startup and have OTS remove the file when it is processed

- Domino Container control for example uses this approach copying the file into the container at startup
- A One Touch template can be downloaded from a remote HTTPS location specified in an environment variable.


## Location of OTS files in the running container at first startup

1. The container image first checks if a OTS file is present at the following location:

**/local/notesdata/DominoAutoConfig.json**


Customization via environment variable: `DOMINO_AUTO_CONFIG_JSON_FILE`

2. If no OTS file is found the container checks for an OTS template file


**/local/notesdata/DominoAutoConfigTemplate.json**

Customization via environment variable: `DOMINO_AUTO_CONFIG_TEMPLATE_JSON_FILE`


3. The OTS template can be also downloaded from remote by specifying the following environment variable like in the following example:

```
SetupAutoConfigureTemplateDownload=https://myserver./ots-template.json
```

## Note

One Touch Setup by default tries to delete configuration files after they are processed to ensure no sensitive data is left on the server.
But this only works if the file is added in a way that the container can delete it.
Mounts on Docker and Secrets/ConfigMaps on Kubernetes are usually read-only

