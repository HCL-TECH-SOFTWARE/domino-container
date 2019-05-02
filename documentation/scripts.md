# Documentation of Components

## build.sh

This is the main start point for building docker images.
You can specify the image to build.

Currently supported are the following images

- domino - Domino 10.0.1 with current fix pack
- domino-ce - Domino 10.0.1 Community edition with current fixpack
- traveler - Traveler 10.0.1.x with current fixepack
 
Inside this script you can also configure a download http target if you are hosting the downloaded software on a different machine
You can also specify a download directoy on your Docker host which will be served by a temporary Docker image running a NGINX server to provide the software

So there are 3 choices
1. Remote Download specified with example: DOWNLOAD_FROM=http://192.168.1.1
2. Local directory specified with example: SOFTWARE_DIR=/local/software hosted via NGINX server
3. Standard location in the software sub-directory hosted via NGINX server

Before you start you have to download the required software packages.

## Directory "Software" 

This directory is the default directory to provide Domino software, which are downloaded by the Docker installation script.

The readme files contain the software list and download links for downloading from Passport Advantage or from Bluemix fro the Community Edition

## Directory "dockerfiles"  

This directory contains a sub-directory for each product that can be installed.

The domino directory contains all files needed to install a Domino or Domino CE server

build_domino.sh  / build_domino-ce.sh

Build file used to build the Domino / Domino CE server.
This script invokes the actual docker build command

dockerfile

This is the dockerfile used for Domino / Domino CE.
The dockerfile is based on centos:latest.
It contains just the basic logic required for a dockerfile.
All install logic is covered in a separate install script.

## Directory "instal_dir"

This directory contains files and scripts to build the Docker image.
Those files are copied to /tmp/install_dir during install process and are invoked by the build process.

install_domino.sh

This file contains the install logic and performs the actual install of all components after downloading the software.

## software.txt

This file contains information about the download you have to download depending on what you install.
This file is used to find the right file to download by product and version. And is also used to verify the downloaded image via SHA256 hash.

The format of the file is as follows:

product|version|filename|product-code|sha256-hash

Example:
```bash
domino|10.0.1|DOM_SVR_V10.0.1_64_BIT_Lnx.tar|CNXL9EN|57a19f56da492740d50457bcb3eec6f2b5410e8e122608c19e1886cf3fb36515
```

## software_dir_sha256.txt

Helper file which contains the checksums build by sha256sum.
The content of this file is added to software.txt

## domino_install_data_prep.sh

Helper script to compact install databases and templates (brings them to current ODS, enables compression and releases free space).

## domino_docker_entrypoint.sh

[located in / owned by root]
This script is the main entry point started when the container is started.
It contains the logic to start and stop the server.
And it also contains the logic triggered at first server start to invoke the configuration of the server.

## docker_prestart.sh

[located in / owned by root]
This script is invoked by the entry-point script to check which additional configuration is needed before the server is started for the first time.

## domino_install_data_copy.sh

[located in / owned by root]
This script is invoked by the entry-point script to check if templates and other files have been updated by an image update.

## domino_docker_healthcheck.sh

[located in / owned by root]
This script is used to check the server health to update the status of the running container.
The current implementation just checks if the server process is running ( for Traveler if the traveler process is running).
You can customize this script for your needs. But usually server availability can be checked outside the server.

## start_script.tar

Nash!Com Domino start and management script which supports Docker and contains an installation routine which is Docker aware

## domino10_response.dat

Response file used for silent server installation

SetupProfile.pds
signWithAdminP.sh
DatabaseSigner.jar

Used to configure the Domino Server (see separate documentation)


## Directory "dockerfiles/traveler"

This directory is very similar to the domino directory and ins used to install a Traveler server based on an existing Domino image.
It uses very similar logic but is less complex than the Domino install logic, because it just leverages the base that The Domino images builds. 