---
layout: default
title: "Download Software"
nav_order: 2
description: "Howto Download Software from My HCLSoftware Portal"
parent: "Howto"
has_children: false
---

# Download software from Flexnet or My HCLSoftware Portal (MHS)


The Container project is a build script leveraging HCL web-kits. Those web-kits cannot be re-distributed and all customers and partners have to download the software from HCL Flexnet or the My HCLSoftware Portal.  

The `build.sh` automatically determines the web-kits required and checks if the software is available at the configured location.  
All web-kits are referenced in a `software.txt` file.
The build script by default lists all missing web-kits. 


# Automatic download from My HCLSoftware Portal (MHS)

The container image build supports automatic downloads leveraging the [Domino Download Script](https://nashcom.github.io/domino-startscript/domdownload/) which is part of the OpenSource Nash!Com Start Script project.

Once installed the build.sh script automatically detects the `domdownload` script to download missing software before starting the build process.
This new option leverages the download API provided by MHS.


# Manual download from MY HCLSoftware Portal

1. Log into the [My HCLSoftware Portal](https://my.hcltechsw.com/) with your account
2. Copy the download URL with a right click action in your browser
3. If not direct download is possible, tranfer the manually downloaded file to the software folder
4. In case the build machine has direct access to the internet curl can be used to directly from this pre-authenticated temporary download link.


## Additional notes

- Specify the exact file name via `-o` option
- Add single quotes around the download URL, because it contains bash specific special chars
- The download URL will be valid for 60 minutes
- Running the `build.sh domino` once the software is downloaded, will start the build process launching a NGINX software container to provide a build process web-kit download
- You can use the `-checkonly` option to only check the software
- The build process verifies the SHA256 download hash. There is no need to verify it manually
- But there is also a `-verifyonly` option available to verify the software download


# Direct download from remote server

In case you have all the install packages located on a central server, you can point build process directly to the download location.  
The option `DOWNLOAD_FROM=https://mylocalsoftware.com` can be configured in build configuration.


