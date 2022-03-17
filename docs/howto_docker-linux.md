---
layout: default
title: "Docker on Linux"
nav_order: 3
description: "Docker on Linux"
parent: "Howto"
has_children: false
---

# Install Docker on Linux

Docker installations depend on the platform your are running.

Some platforms like Redhat have moved to [Podman](https://podman.io/) as their primary container build and run-time environment.  
The Domino Container project works with both platforms and auto detects, which container run-time is installed.

Some platforms still have up to date Docker versions in their software repositories.

The (Docker installation page)[https://docs.docker.com/engine/install/] lists how to install the Docker server on most popular distributions.

Docker provides a script to install Docker on Linux with one command.
The following command, downloads the script and runs it in a bash.

```
curl -sfL https://get.docker.com | bash -
```

On SUSE SLES and Leap you can use `zypper install docker` to install Docker.
On Ubuntu after updating to a current version `apt install docker.io` installs a current Docker server.

## Check the Docker Client and Server Version

Once installed, check the server and client version running.

```
docker version
```

## Next Steps

This completes the setup for your Docker environment.

Contine with [Quickstart](quickstart.md) to build and run your first container.
