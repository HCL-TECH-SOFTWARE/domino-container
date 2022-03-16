---
layout: default
title: "Concept & Overview"
nav_order: 1
description: "HCL Domino Container"
has_children: true
---

[Quickstart](quickstart.md){: .btn }
[View it on GitHub](https://github.com/HCL-TECH-SOFTWARE/domino-container){: .btn }

---

# Domino Container

This project contains build scripts for HCL Domino Docker/Container images via [dockerfiles](https://docs.docker.com/engine/reference/builder/).
The repository provides the utilities to build HCL Domino Server with the latest software or specific version in a Docker/Container image.
There are separate folders within this repository for Domino add-on HCL products like Traveler and HCL Domino Volt as well.

All required HCL web-kits and fixes are downloaded from a software repository server instead of adding the source installation files to the image directly.
If no remote server is referenced a temporary local [NGINX container](https://hub.docker.com/_/nginx) is started at build time to act as a **software repository server**.

## Supported environments

The project is supported on Docker Desktop, Docker Server, Podman, Rancher Desktop, Kubernetes (K8s) and OpenShift.
See detailed information about [supported run-time and build environments](concept_environments.md)

## Where to get HCL Domino software

The project uses the official HCL web-kit installers to build container images download from the official HCL Flexnet repository.

- All HCL customers with active maintenance should have a download account for [HCL Flexnet software portal](https://hclsoftware.flexnetoperations.com/flexnet/operationsportal)
- HCL Business Partners with the [Partner Pack](https://www.hcltechsw.com/resources/partner-connect/resources/partner-pack) can download software in a similar way

See how to [download software](howto_download-software.md) for details.

## How to download this project

We recommend to download the GitHub project directly via git.  
An alternate way is to download the project via ZIP file from the respository page.

See Howto [Get Domino Container GitHub Repo](howto_github.md) for details.

## Building the image(s)

To build the latest available image

1. Download the required software packages to the 'software' directory
2. From the root folder of this repository issue the following command

```bash
./build domino
```

The process will perform all required actions to create the image in the version requested. Usually it takes ~5 to ~8 minutes to build the image (depending on your CPU & disk performance).

Once you have built the Domino base image, you can build add-on images on top if it.  
The add-on application is another layer on top of the Domino image.

Add-on images always need to be derived from the Domino base image.

There are currently two add-on images available:

* ```./build traveler``` - Traveler on Domino
* ```./build volt``` - Volt on Domino

Refer to Howto [Run Domino Container GitHub Repo](run_docker.md) how to run a Domino Container on Docker.
