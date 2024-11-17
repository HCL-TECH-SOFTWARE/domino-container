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

To install Docker use the official Docker documentation to ensure to get a recent version.
Docker provides repositories for most distributions.
Follow the steps for [Install Docker Engine](https://docs.docker.com/engine/install/).

An alternate way to install is to use the Docker convenience script provided by Docker.
It can be automatically downloaded and executed.


```
curl -fsSL https://get.docker.com | bash -
```

## Check the Docker Client and Server Version

Once installed, check the server and client version running.

```
docker version
```

## Next Steps

This completes the setup for your Docker environment.

Contine with [Quickstart](quickstart.md) to build and run your first container.
