---
layout: default
title: "Docker on WSL2"
nav_order: 5
description: "Docker on WSL2"
parent: "Howto"
has_children: false
---

# Introduction

Microsoft offers [WSL2](https://docs.microsoft.com/en-us/windows/wsl/) a very interesting Linux integration platform,
which is very convenient and flexible for local build and run-time environments.
It can be used as build and run-time environment for Domino on Docker.

The most flexible setup is to run one of the standard Linux distributions and install a Docker Linux host on the WSL2 instance.
WSL2 is also used in current Docker Desktop installations. Important for a build environment is any Docker or Podman installation with Bash support.

# Requirements

Ensure you run at least

- Windows 10 version 2004 or higher
- Windows 11
- Windows 2022
- Windows 2025

# Install WSL2

Today WSL2 should be the default for each new installation.
In case you are running the older WSL version, you have to switch to WSL2.
Refer to details in the reference link below.

```
wsl --install
```

# Install Linux Distribution

Once WSL2 is installed, WSL can list all available Linux distributions.


## List available images

```
wsl --list --online
```


## Example installing Ubuntu

The default distribution is Ubuntu. Make sure you select a LTS version to ensure long term support.

```
wsl --install -d Ubuntu-24.04
```

Once Ubuntu is installed, it can be launched in multiple ways:

- Desktop/taskbar icon
- `wsl` command line
- Software like [MobaXterm](https://mobaxterm.mobatek.net/) with WSL integration


## Create a new user

When the container is launched for the first time, it asks to create a new user.
For a Domino on Docker environment the best first user is `notes`.

On Ubuntu the `root` user can be switched to via `sudo su -` specifying your `notes` user password.

```
sudo su -
```

## Update Ubuntu

The installed WSL Linux instance is not up to date after installation.

```
apt update
apt upgrade
```


## Install Docker Server

Ubuntu does not provide the latest Docker versions.

It is recommended to use the official Docker documentation to ensure to get a recent version.
Follow the steps for [Install Docker Engine](https://docs.docker.com/engine/install/).

An alternate way to install is to use the Docker convenience script provided by Docker.
It can be automatically downloaded and executed.

```
curl -fsSL https://get.docker.com | bash -
```

The latest Ubuntu WSL images support systemd. Earlier versions did not support systemd and required work-arounds to start the Docker daemon.
In current Ubuntu versions The Docker server is installed as a systemd services automatically.


## Install JQ

JQ is the standard tool for working with JSON files.  
The domino_container scripts leverage JQ, which is included in all major distributions including Ubuntu.

```
apt install jq
```


## Clone Docker Container Project

```
mkdir -p /local/github
cd /local/github
git clone https://github.com/HCL-TECH-SOFTWARE/domino-container.git 
```

## Clone Start Script project & Install Nash!Com Domino Container Control Script

**dominoctl** provides an easy way to configure, run and manage Domino containers.
Check [Domino container control (dominoctl)](https://nashcom.github.io/domino-startscript/dominoctl/) documentation for details.


To clone the GitHub project invoke the following command:

```
cd /local/github
git clone https://github.com/nashcom/domino-startscript.git
```

To install or update dominoctl run the following command

```
/local/github/domino-startscript/install_dominoctl
```


## Check the Docker Client and Server Version

```
docker version
```


## Next Steps

This completes the setup for your Docker environment.

Contine with [Quickstart](quickstart.md) to build and run your first container.


## Reference

[Microsoft WSL2 install documentation](https://docs.microsoft.com/en-us/windows/wsl/install).

