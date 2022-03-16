---
layout: default
title: "Download Software"
nav_order: 2
description: "Howto Download Software from Flexnet"
parent: "Howto"
has_children: false
---

# Donwload software from Flexnet


The Container project is a build script leveraging HCL web-kits. Those web-kits cannot be re-distributed and all customers and partners have to download the software from HCL Flexnet.  
As for many other download portals Flexnet can be challenging.

The `build.sh` automatically determines the web-kits required and checks if the software is available at the configured location.  
All web-kits are referenced in a `software.txt` file. If software is missing the build script provides a download search link for Flexnet.

This link only works on customer accounts, because HCL partner accounts have limited search options.

The most convenient way to download from Flexnet is the following approach.

1. Log into the [HCL Flexnet software portal](https://hclsoftware.flexnetoperations.com/) with your account
2. Use the links provided by the build script to navigate to the right download
3. Copy the download URL with a right click action in your browser -- the link will not work when you login with this link directly.
4. Change in your Linux bash prompt to the specified directory. In our example: `/local/github/domino-container/software`
5. Use the download URL in a curl command as shown below.

Additional notes

- Specify the exact file name via `-o` option
- Add single quotes around the download URL, because it contains bash specific special chars
- The download URL will be valid for a couple of minutes only
- Running the `build.sh domino` once the software is downloaded, will start the build process launching a NGINX software container to provide a build process web-kit download
- You can use the `-checkonly` option to only check the software
- The build process verifies the SHA256 download hash. There is no need to verify it manually
- But there is also a `-verifyonly` option available to verify the software download


## Example download curl command

```
curl -L -o Domino_12.0.1_Linux_English.tar 'https://download.flexnetoperations.com/439214/1513/807/18572807/Domino_12.0.1_Linux_English.tar?ftpRequestID=2774729993&server=download.flexnetoperations.com&dtm=DTM20220313175049MjU0NzQ2NDUw&authparam=1647219050_c709a3e830fe6b67a7aa0dc57d7f59db&ext=.tar'
```

## Direct download from remote server

In case you have all the install packages located on a central server, you can point build process directly to the download location.  
The option `DOWNLOAD_FROM=https://mylocalsoftware.com` can be configured in build configuration.


## Example build command to list missing software

```
./build.sh domino

Checking software via [/local/github/domino-container/software/software.txt]

12.0.1              [NA] Domino_12.0.1_Linux_English.tar
https://hclsoftware.flexnetoperations.com/flexnet/operationsportal/DownloadSearchPage.action?search=Domino_12.0.1_Linux_English.tar+&resultType=Files&sortBy=eff_date&listButton=Search

12.0.1IF2           [NA] 1201HF50-linux64.tar
https://hclsoftware.flexnetoperations.com/flexnet/operationsportal/DownloadSearchPage.action?search=1201HF50-linux64.tar+&resultType=Files&sortBy=eff_date&listButton=Search

Correct Software Download Error(s) before building image [2]
Copy files to [/local/github/domino-container/software]

```
