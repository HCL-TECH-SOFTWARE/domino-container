---
layout: default
title: "Download Software"
nav_order: 2
description: "Howto Download Software from My HCLSoftware Portal"
parent: "Howto"
has_children: false
---


# Automatic download from My HCLSoftware Portal (MHS)

The container image build supports automatic downloads leveraging the [Domino Download Script](https://nashcom.github.io/domino-startscript/domdownload/) which is part of the OpenSource Nash!Com Start Script project.

Once installed the build.sh script automatically detects the `domdownload` script to download missing software before starting the build process.
This new option leverages the download API provided by MHS.

## Installing the Domino Download Script (Recap)

```bash
git clone https://github.com/nashcom/domino-startscript.git
cd domino-startscript
chmod +x domdownload.sh
./domdownload.sh install
```

This will add the download script to `/usr/local/bin/domdownload` (Note: no `.sh` extension) on your system path and also install, if not found, the command line tools `curl` (network tool, used to fetch files from URLs) and `jq` (JSON commandline processor) 

For the full details or alternate approaches, see [Domino Download Script](https://nashcom.github.io/domino-startscript/domdownload/#how-to-get-started)


# Manual download from My HCLSoftware Portal

1. Log into the [My HCLSoftware Portal](https://my.hcltechsw.com/) with your account
2. Copy the download URL with a right click action in your browser
3. If not direct download is possible, transfer the manually downloaded file to the software folder
4. In case the build machine has direct access to the internet, [Curl](https://curl.se/) can be used to directly from this pre-authenticated temporary download link.


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
