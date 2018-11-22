## Description

This directory contains Docker build scripts and tools required to successfully build a Docker image with Domino 10. 

## Images

Base Image - 

### Build a single image

### Build all images at once


## Build Arguments

### DownloadFrom
Default value : http://172.17.0.3

Defines the location of the software repository. By default the local repository ibmsoftware will be used, the IP address of the local repository will be obtained automatically and passed on to the build script.

```--build-arg DownloadFrom=http://172.17.0.3```

### DominoBasePackage
Default value : DOMINO_SERVER_V10.0_64_BIT_LINUX_.tar

Name of the Domino Server base image file. The build script will use this parameter for download and extracting the instalaltion package
```--build-arg DominoBasePackage=DOMINO_SERVER_V10.0_64_BIT_LINUX_.tar```

### DominoResponseFile

Default value : domino10_response.dat

Name of the response file that will be used for unattended Domino Server setup (phase 1). This file is part of the scripts that will be added to the image at build time. 

Example:
```--build-arg DominoResponseFile=domino10_response.dat```

### DominoMoveInstallData (optional)

Optional parameter to move the Domino Data directory to a directory other than where it has been installed to. This is useful when building images that will be used for upgrade scenarios.

```--build-arg DominoMoveInstallData=/local/templates```

### LocalInstallDir
Specifies the temporary directory that will be used to extract the Domino installation packages and start scripts. This is a temporary directory only - it will be removed when the build process is completed. 
```--build-arg LocalInstallDir=/tmp/install```


### DominoVersion

Default value : 10.0.0
to be documented

### DominoUserID
Default value : 1001

### DOMINO_LANG

Default value : en_US.UTF-8

Defines the user locale for the operating system account which Domino runs in. You can overwrite the default using
```--build-arg DOMINO_LANG=en_US.UTF-8```