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

Create a directory where to download Git projects and switch to it.

Example:

```
mkdir -p /local/github
cd /local/github
```

Clone the repository and switch to the directory

```bash
git clone https://github.com/HCL-TECH-SOFTWARE/domino-container.git 
cd domino-container
```

Note:  
Leveraging Git repositories directly does allow to update the repository via `git pull`.  
Git also allows to swith between different branches of the project.  
The project uses a main and a develop branch. The develop branch should be only used by experienced administrators.
