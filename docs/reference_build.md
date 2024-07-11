---
layout: default
title: "Build Commands"
nav_order: 1
parent: "Reference"
description: "Container build commands"
has_children: false
---

# Build Command Documentation

The `build.sh` command is used as the main entry point for building Domino images including add-on software like Traveler, Verse and Domino Leap.
Using the build command line and configuration file the build operation can be customized.

The only required parameter is the product to install.

Example: Build the latest Domino container image:

```
./build.sh domino
```

## Build Configuration File

The build configuration can be used to define the download location for HCL software.

- `DOWNLOAD_FROM=http://192.168.96.170/software`  
  Defines a remote location to download software from.
  This could be any type of HTTP/HTTPS resource for example a Nexus server.
  

- `SOFTWARE_DIR=/local/software`  
  You can also copy all required software download to a directory and specify the download location.
  The build process automatically starts a temporary Docker container leveraging [NGINX container](https://hub.docker.com/_/nginx) the data for the Docker build process.

- `LinuxYumUpdate=no`  
  Disable updating Linux in the build process

- `SPECIAL_CURL_ARGUMENTS="--no-check-certificate"`  
  Additional parameters to pass to the CURL download command.
  For example disable certificate check for untrusted sources

## Build Command Line

The fist option is always the product to install.
It can be followed by a specific version to install.
Note: If you specify an explicit version, the "latest" tag is not set automatically.

Example:
``` 
./build.sh domino 14.0 FP1
```

### Configuration Options

- **cfg**  
  Opens the build configuration

- **cpcfg**  
  Copies the configuration document to a standard location  
  (specified via DOMINO_DOCKER_CFG_DIR, default: /local/cfg)


### Build specific Options

- **-checkonly**  
  Checks only if all software is available without starting the build process. This is helpful to prepare a build.

- **-verifyonly**  
  Checks if all software is availabe and the checksum matches.

- **-nocheck** / **-check**  
  Explicitly enables or disables checking if all software exists (default: yes)

- **-noverify** / **-verify**  
  Explicitly enables verification of software (default: no)

- **-nolinuxupd** / **-linuxpd**  
  Overwrites default for updating the downloaded Linux image during build.  
  By default updates are installed by any build operation and images are build without leveraging cache to ensure the image is up to date.

- **-from=imagename**  
  Use a specific base image for installation.  
  This can be a prebuild environment or an alternate Linux base image  
  There are a couple of pre-defined images, which can be referenced by their short name

- **-tag=imagename**  
  Tag image additionally with this tag after build

- **-push=imagename**  
  Tag image and push it after build

### Software Options

- **-leap=version**  
  Installs specified Domino Leap version.  
  If invoked without version parameter, latest version will be installed

- **-capi=version**  
  Installs specified C-API SDK version.  
  If invoked without version parameter, latest version will be installed

- **-startscript=version**  
  Installs specified Start Script version.  
  By default the latest start script included in the project will be installed.  
  Useful when switching to specific or custom start script version.
  

### Reference: Build Usage

```
HCL Domino Container Build Script
---------------------------------
Version 2.3.0
(Running on docker Version 26.1.1)


Usage: build.sh { domino | safelinx } version fp hf

-checkonly       checks without build
-verifyonly      checks download file checksum without build
-(no)check       checks if files exist (default: yes)
-(no)verify      checks downloaded file checksum (default: no)
-(no)url         shows all download URLs, even if file is downloaded (default: no)
-(no)linuxupd    updates container Linux  while building image (default: yes)
cfg|config       edits config file (either in current directory or if created in home dir)
cpcfg            copies standard config file to config directory (default: /root/.DominoContainer/build.cfg)

-tag=<image>     additional image tag
-push=<image>    tag and push image to registry
-autotest        test image after build
testimage=<img>  test specified image
-scan            scans a container image with Trivy for known vulnerabilities (CVEs)
-scan=<file>     scans a container with Trivy and writes the result to a file
                 file names ending with .json result in a JSON formatted file (CVE count is written to console)
menu             invokes the build menu. the build menu is also invoked when no option is specified
-menu=<file>     uses the specified menu name. Default is no menu file is specfied: default.conf

Options

-conf            uses the default.conf file to build an image (see menu for details)
-conf=<file>     uses the specified file to build an image
-from=<image>    builds from a specified build image. there are named images like 'ubi' predefined
-imagename=<img> defines the target image name
-imagetag=<img>  defines the target image tag
-save=<img>      exports the image after build. e.g. -save=domino-container.tgz
-tz=<timezone>   explictly set container timezone during build. by default Linux TZ is used
-locale=<locale> specify Linux locale to install (e.g. de_DE.UTF-8)
-lang=<lang>     specify Linux glibc language pack to install (e.g. de,it,fr). Multiple languages separated by comma
-pull            always try to pull a newer base image version
-openssl         adds OpenSSL to Domino image
-borg            adds borg client and Domino Borg Backup integration to image
-verse           adds Verse to a Domino image
-nomad           adds the Nomad server to a Domino image
-traveler        adds the Traveler server to a Domino image
-leap            adds the Domino Leap to a Domino image
-capi            adds the C-API sdk/toolkit to a Domino image
-domlp=xx        adds the specified Language Pack to the image
-restapi         adds the Domino REST API to the image
-ontime          adds OnTime from Domino V14 web-kit to the image
-tika            updates the Tika server to the Domino server
-k8s-runas       adds K8s runas user support
-linuxpkg=<pkg>  add on or more Linux packages to the container image. Multiple pgks are separated by blank and require quotes
-startscript=x   installs specified start script version from software repository
-custom-addon=x  specify a tar file with additional Domino add-on sofware to install format: (https://)file.taz#sha256checksum
-software=<dir>  explicitly specify SOFTWARE_DIR and override cfg file

SafeLinx options

-nomadweb        adds the latest Nomad Web version to a SafeLinx image
-mysql           adds the MySQL client to the SafeLinx image
-mssql           adds the Mircosoft SQL Server client to the SafeLinx image

Special commands:

save <img> <my.tgz>   exports the specified image to tgz format (e.g. save hclcom/domino:latest domino.tgz)

Examples:

  build.sh domino 14.0 fp1
  build.sh traveler 12.0.2

```
