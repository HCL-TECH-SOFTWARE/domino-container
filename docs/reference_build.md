---
layout: default
title: "Build Commands"
nav_order: 1
parent: "Reference"
description: "Container build commands"
has_children: false
---

# Build Command Documentation

The `build.sh` command is used as the main entry point for building Domino, Traveler and Volt images.
Using the the build command line and configuration file the build operation can be customized.

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
./build.sh domino 12.0.1 FP1
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
  There are a couple of predfined images, which can be referenced by their short name

- **-tag=imagename**  
  Tag image additionally with this tag after build

- **-push=imagename**  
  Tag image and push it after build

### Software Options

- **-volt=version**  
  Installs specified HCL Volt version.  
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
Usage: build.sh { domino | traveler | volt } version fp hf

-checkonly      checks without build
-verifyonly     checks download file checksum without build
-(no)check      checks if files exist (default: yes)
-(no)verify     checks downloaded file checksum (default: no)
-(no)url        shows all download URLs, even if file is downloaded (default: no)
-(no)linuxupd   updates container Linux  while building image (default: yes)
cfg|config      edits config file (either in current directory or if created in home dir)
cpcfg           copies standard config file to config directory (default: /root/DominoDocker/build.cfg)

-tag=<image>    additional image tag
-push=<image>   tag and push image to registry

Add-On options

-from=<image>   builds from a specified build image. there are named images like 'ubi' predefined
-openssl        adds OpenSSL to Domino image
-borg           adds borg client and Domino Borg Backup integration to image
-verse          adds the latest verse version to a Domino image
-capi           adds the C-API sdk/toolkit to a Domino image
-k8s-runas      adds K8s runas user support
-startscript=x  installs specified start script version from software repository

Examples:

  build.sh domino 12.0.1 if1
  build.sh traveler 12.0.1
```
