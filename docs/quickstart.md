---
layout: default
title: "Quickstart"
nav_order: 1
description: "HCL Domino Quickstart"
has_children: false
---

## Ensure you have a supported build environment

The project supports most Linux base environments including [Windows Subsystem for Linux 2 (WSL2)](https://docs.microsoft.com/en-us/windows/wsl/)

For details check [supported run-time and build environments](concept_environments.md)

## Install container environment

In case you never worked with container on your machine, make sure Docker or Podman is installed.
This project works with Docker and Podman, still our recommendation would be to use Docker, because it takes care about starting containers without creating a separate service per container.
In addition Docker Compose and other functionality works better on Docker.

For details about installing Docker see howto [Docker on Linux](howto_docker-linux.md)

If you have no container environment there is a easy to use convenience script to install Docker and perform the following scripts automatically.

See the [Domino Start Script GitHub page](https://nashcom.github.io/domino-startscript/install_container_env/) for details.


## Clone this project via Git

### Install Git software

Git is a very simple and convenient way to download from GitHub.
The install command depends on the platform (SUSE: zypper, Ubuntu: apt).
"yum" works for any Redhat/CentOS based distribution.

```
yum install git -y
```

On Ubuntu/Debian use

```
apt install git -y
```

### Create new main directory for the project

Create a directory where to download Git projects and switch to it.

Example:

```
mkdir -p /local/github
cd /local/github
```

### Clone the repository and switch to the directory

```
git clone https://github.com/HCL-TECH-SOFTWARE/domino-container.git 
cd domino-container
```

## Download software from  My HCLSoftware Portal

Before starting the build process, the required HCL web-kits have to be available on the build machine or a remote download location - if configured.  

See howto [download software](howto_download-software.md) for details downloading software from [My HCLSoftware Portal](https://my.hcltechsw.com/).

## Build the image

```
./build domino
```

## Run container Domino Container Script

The Nash!Com Domino container script allows you to operate your server. It supports Docker and Podman run-time environments.

### Install Domino Container script

Clone the [start script repository](https://github.com/nashcom/domino-startscript)

```
cd ..
git clone https://github.com/nashcom/domino-startscript.git
cd domino-startscript
./install_dominoctl
```

### Configure your container

The project provides a default configuration.
Usually the default configuration should work for your environment.
You might want to change the container name and other detailed settings.


```
dominoctl cfg
```

**Note:** The container script by default uses `vi` for editing.
If you prefer a different editor like `nano` or `mcedit` export an environment variable specifying an installed editor of your choice.
Tip: You can also add the variable to your bash profile.

```
export EDIT_COMMAND=nano
```

### Configure container setup

Usually environment variables are used for setup.
The following commands opens the environment file, configured for your container.

```
dominoctl env
```

## Start Domino container

After specifying the configuration and setup correctly, start the container with the Domino container script.

```
dominoctl start
```

### Domino live console

To start a Domino live console, run the console command.
The dominoctl script leverages and `exec` command into the container.
The long version of this command would be `dominoctl domino console`.

All console commands can be executed via `domino`.
This command passes command line parameters to the `domino` start script.

```
dominoctl console

```

## Domino Container Script Diagram

![domino_container script diagram](assets/images/svg/containerstartscript.svg)
