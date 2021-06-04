# Description

This directory contains Docker build scripts and tools required to successfully build a Docker image with Domino 10 or later.

![Docker Entrypoint Flow](https://raw.githubusercontent.com/IBM/domino-docker/master/docs/images/entrypoint-flow.png)

## Images

### Base Image

### Build a single image

To build a specific image:

1. (optional) Start the software repository

```bash
cd software
./software-repo.sh start
cd ..
```

2. Build image(s) as needed

the build argument 'DownloadFrom' represents the server hosting the software repository with the file names specified below

```bash
cd domino10
docker build -t ibmcom/domino:10.0.0 -f Dockerfile-domino10-centos.txt . --build-arg DownloadFrom=http://yourserver.com:port/directory
cd ..
cd verse
docker build -t ibmcom/verse:1.0.5 -f Dockerfile-verse105-centos.txt . --build-arg downloadfrom=http://yourserver.com:port/directory
```

### Build all images at once

## Build Arguments

### DownloadFrom

Default value : `http://172.17.0.3`

Defines the location of the software repository. By default the local repository ibmsoftware will be used, the IP address of the local repository will be obtained automatically and passed on to the build script.

`--build-arg DownloadFrom=http://172.17.0.3`

### DominoBasePackage

Default value : `DOMINO_SERVER_V10.0_64_BIT_LINUX_.tar`

Name of the Domino Server base image file. The build script will use this parameter for download and extracting the instalaltion package

`--build-arg DominoBasePackage=DOMINO_SERVER_V10.0_64_BIT_LINUX_.tar`

### DominoResponseFile

Default value : not set and determined by the install script depending on the Domino version

Name of the response file that will be used for unattended Domino Server setup (phase 1). This file is part of the scripts that will be added to the image at build time.

> Example: `--build-arg DominoResponseFile=domino10_response.dat`

### DominoMoveInstallData (optional)

Optional parameter to move the Domino Data directory to a directory other than where it has been installed to. This is useful when building images that will be used for upgrade scenarios.

> Example: `--build-arg DominoMoveInstallData=/local/templates`

### LocalInstallDir

Specifies the temporary directory that will be used to extract the Domino installation packages and start scripts. This is a temporary directory only - it will be removed when the build process is completed.

> Example: `--build-arg LocalInstallDir=/tmp/install`

### DominoVersion

Default value : 10.0.0

### DominoUserID

Default value : 1001

### DOMINO_LANG

Default value : en_US.UTF-8

Defines the user locale for the operating system account which Domino runs in. You can overwrite the default using

> Example: `--build-arg DOMINO_LANG=en_US.UTF-8`
