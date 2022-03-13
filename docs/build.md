---
layout: default
title: "Runtime Variables"
nav_order: 3
description: "Container environment variables"
has_children: false
---

# Build Command Documentation

The `build.sh` command is used as the main entry point for building Domino, Traveler and Volt images.
In most of the cases default parameters should be fine. But the build command line and configuration file can be used to customize the build process.

Standard build example to build the latest Domino version from the configured source:

``` 
./build.sh domino 
```

## Build Configuration File


The build configuration can be used to define the download location for HCL software.

- `DOWNLOAD_FROM=http://192.168.96.170/software`  
  Defines a remote location to download software from. This could be any type of HTTP/HTTPS resource for example a Nexus server
  

- `SOFTWARE_DIR=/local/software`  
  You can also copy all required software download to a directory and specify the download location.
  The build process automatically starts a temporary Docker container leveraging NGINX to server the data for the Docker build process.

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
./build.sh domino 12.0.1 IF1
```

Command line options can be used to modify the build process. 

- `cfg`  
  Opens the build configuration

- `cpcfg`  
  Copies the configuration document to a standard location  
  (specified via DOMINO_DOCKER_CFG_DIR, default: /local/cfg)

- `-checkonly`  
  Checks only if all software is available without starting the build process. This is helpful to prepare a build.

- `-verifyonly`  
  Checks if all software is availabe and the checksum matches.

- `-nocheck / -check`  
  Explicitly enables or disables checking if all software exists (default: yes)

- `-noverify / -verify`  
  Explicitly enables verification of software (default: no)

- `-nolinuxupd / -linuxpd`  
  Overwrites default for updating the downloaded Linux image during build.The default setting is `yes` and can be modified in the cfg. 

- `-from=imagename`  
  Use a specific base image for installation.
  This can be a prebuild environment or an alternate Linux base image

- `latest...`  
  Defines a custom latest Tag which is used to tag the image.  
  For example latest_ubi8

- `_...`  
  Custom version tag. This option is appended to the tag used
  For example _V1201_custombuild

### Build Usage

``` 
Usage: build.sh { domino | traveler | volt } version fp hf

-checkonly      checks without build
-verifyonly     checks download file checksum without build
-(no)check      checks if files exist (default: yes)
-(no)verify     checks downloaded file checksum (default: no)
-(no)url        shows all download URLs, even if file is downloaded (default: no)
-(no)linuxupd   updates container Linux  while building image (default: yes)
cfg|config      edits config file (either in current directory or if created in /local/cfg)
cpcfg           copies the config file to config directory (default: /local/cfg/build_config)
``` 




