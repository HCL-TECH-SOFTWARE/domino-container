---
layout: default
title: "Get GitHub project"
nav_order: 1
description: "How to Get Domino Container GitHub Project"
parent: "Howto"
has_children: false
---

## How to download the Domino Container GitHub Project

If you are directly connected to the GitHub server the recommended method to download this project is to use a git client, which is part of any Linux distribution.

Example: Install for Redhat/CentOS based platforms via yum

```
yum install git -y
```

Example: Install for Ubuntu/Debian based platforms via apt

```
apt install git -y
```

Create a directory where to download Git projects and switch to it.

Example:

```
mkdir -p /local/github
cd /local/github
```

Clone the repository and switch to the directory

```
git clone https://github.com/HCL-TECH-SOFTWARE/domino-container.git 
cd domino-container
```

### Download as a tar file

When downloading the GitHub repository avoid the ZIP download link.
because the ZIP format does not preserve file permissions.

A better way is to download the GitHub repository as a so called **tarball**.
The resulting tar file can be extracted preserving file system permissions.

When downloading via browser, Git generates a file name for you. The URL would look like this: 

https://github.com/HCL-TECH-SOFTWARE/domino-container/tarball/main

For a command-line download curl is the recommended way as listed below.

```
curl -sL https://github.com/HCL-TECH-SOFTWARE/domino-container/tarball/main -o domino-container.tar.gz
```


### Downloading behind a proxy

In a corporate environment a direct connection to the internet might not be an option.
The Git client uses the standard Linux proxy settings when connecting to the internet.


Note:  
Leveraging Git repositories directly allows to update the repository via `git pull`.  
Git also allows to switch between different branches of the project.  
The project uses a main and a develop branch. The develop branch should be only used by experienced administrators.
