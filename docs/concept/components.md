---
layout: default
title: "Documentation of Components"
nav_order: 2
description: "Documentation of Components"
parent: "Concepts"
has_children: false
---

# Documentation of Components

## build.sh

This is the main start point for building docker images.
You can specify the image to build.

The following images are supported

- domino - Domino 12
- traveler - Traveler 12
- volt - HCL Domino Volt 1.x

We are constantly updating the software.txt repository file with current software releases.
Unless you specify a distinct version the current version will be installed and tagged as "latest".
 
Inside this script you can configure a remote download http target if you are hosting the downloaded software on a different machine.
You can also specify a download directoy on your Docker host which will be served by a temporary Docker container running a NGINX server to provide the software.

The following three options are available
1. Remote Download specified with example: `DOWNLOAD_FROM=http://192.168.1.1`
2. Local directory specified with example: `SOFTWARE_DIR=/local/software` hosted via NGINX server
3. Standard location in the software sub-directory hosted via NGINX server in temporary container

Before you start you have to download the required software packages.

## Directory "software"

This directory is the default directory to provide Domino software, which are downloaded by the Docker installation script.
The build script checks if your selected software is available on the defined software location and will prompt you which package to download if missing.
All HCL customers (and business partners with the [Partner Pack](https://www.hcltechsw.com/resources/partner-connect/resources/partner-pack) should have a download account for [HCL Flexnet software portal](https://hclsoftware.flexnetoperations.com/flexnet/operationsportal).
We try to point you to the right files on the Flexnet Download site where possible.


## Directory "dockerfiles"

This directory contains a sub-directory for each product that can be installed.

The domino directory contains all files needed to install a HCL Domino server

## Install directories "install_dir.."

These directories contain files and scripts to build ocker images.
Those files are copied to /tmp/install_dir during install process and are invoked by the build process.

# install_domino.sh

This file contains the install logic and performs the actual install of all components after downloading the software.

## software.txt

This file contains information about the download you have to download depending on what you install.
This file is used to find the right file to download by product and version. And is also used to verify the downloaded image via SHA256 hash.

The format of the file is as follows:

```
product|version|filename|product-code|sha256-hash
```

Example:
```
domino|12.0.1|Domino_12.0.1_Linux_English.tar|-|a9d561b05f7b6850ed1230efa68ea1931cfdbb44685aad159613c29fa15e5eea
```

## domino_docker_entrypoint.sh

[located in / owned by root]
This script is the main entry point started when the container is started.
It contains the logic to start and stop the server.
And it also contains the logic triggered at first server start to invoke the configuration of the server.

## docker_prestart.sh

[located in /domino-docker/scripts owned by root]
This script is invoked by the entry-point script to check which additional configuration is needed before the server is started for the first time.

## domino_install_data_copy.sh

[located in /domino-docker/scripts owned by root]
This script is invoked by the entry-point script to check if templates and other files have been updated by an image update.

## domino_docker_healthcheck.sh

[located in / owned by root]
This script is used to check the server health to update the status of the running container.
The current implementation just checks if the server process is running ( for Traveler if the traveler process is running).
You can customize this script for your needs. But usually server availability can be checked outside the server.

## start_script.tar

Nash!Com Domino start and management script which supports Docker and contains an installation routine which is Docker aware


