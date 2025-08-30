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

## Ensure only one container environment is installed.

Even the container project could handle both container environments to be installed, it is highly recommended to have only one run-time installed.
If Podman is installed, it is used by default. There is a switch to use Docker instead.
Either `export USE_DOCKER=yes` or configure it via `./build.sh cfg`.

## Official Docker installation

To install Docker use the official Docker documentation to ensure to get a recent version.
Docker provides repositories for most distributions.
Follow the steps for [Install Docker Engine](https://docs.docker.com/engine/install/).

An alternate way to install is to use the Docker convenience script provided by Docker.
It can be automatically downloaded and executed.

```
curl -fsSL https://get.docker.com | bash -
```

## Nash!Com Convenience script to install the complete environment

The Domino Start Script project provides a
[Container build environment convenicence script](https://nashcom.github.io/domino-startscript/install_container_env/)
to install the whole environment including GitHub repositories and leverages the Docker install convenience script as part of the installation.


## Check the Docker Client and Server Version

Once installed, check the server and client version running.

```
docker version
```

## Next Steps

This completes the setup for your Docker environment.

Continue with [Quickstart](quickstart.md) to build and run your first container.
