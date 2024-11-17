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
Additional software ( like HCL Traveler, Verse, Nomad Server) can be added as build options to a Domino container image.

All required HCL web-kits and fixes are downloaded from a software repository server instead of adding the source installation files to the image directly.
If no remote server is referenced a temporary local [NGINX container](https://hub.docker.com/_/nginx) is started at build time to act as a **software repository server**.

## Supported environments

The project is supported on Docker Desktop, Docker Server, Podman, Rancher Desktop, Kubernetes (K8s) and OpenShift.
See detailed information about [supported run-time and build environments](concept_environments.md)

## Where to get HCL Domino software

The project uses the official HCL web-kit installers to build container images from [My HCLSoftware Portal](https://my.hcltechsw.com/).

- All HCL customers with active maintenance should have a download account 
- The [Partner Pack](https://www.hcltechsw.com/resources/partner-connect/resources/partner-pack) provides the same access for HCL Business Partners

See how to [download software](howto_download-software.md) for details.

## How to download this project

The recommended method is to clone the download the GitHub project directly via git.  
An alternate way is to download the project via as a tar file from the repository page.

See Howto [Get Domino Container GitHub Repo](howto_github.md) for details.

## Building the image(s)

To build the latest available image

1. Download the required software packages to the 'software' directory
2. From the root folder of this repository issue the following command

```bash
./build.sh domino
```

The process will perform all required actions to create the image in the version requested. Usually it takes ~5 to ~8 minutes to build the image (depending on your CPU & disk performance).


## Building an image with additional add-ons

The community image offers building an image with additional add-on, which can be simply added to the build step. In previous versions HCL Traveler and Domino Leap have been implemented as add-on images on top of the Domino image in a layered approach.  
All add-on software can be directly added in a single build step.

```
-verse
-nomad
-traveler
-ontime
-leap
-capi
```

By default the latest version is selected. But different versions can be optionally specified for each component. Example: `-verse=3.1``


## New build menu

The project now offers a simple to use build menu, which offers the most common build options.
Invoking `build.sh` without any parameter opens the build menu.

The build menu can be also invoked via `menu` specifying additional options.

The versions of the add-ons are automatically selected from current software list.
Just select all desired components and start the build process via pressing a `b`.


```
HCL Domino Container Community Image
------------------------------------

 (D)  HCL Domino          [X]  14.0FP3
 (O)  OnTime              [ ]
 (V)  Verse               [ ]
 (T)  Traveler            [ ]
 (N)  Nomad Server        [ ]
 (L)  Language Pack       [ ]
 (R)  REST-API            [ ]
 (A)  C-API SDK           [ ]
 (E)  Domino Leap         [ ]

 Select software & Options,  [B] to build,  [0] to cancel?

```

Refer to Howto [Run Domino Container GitHub Repo](run_docker.md) how to run a Domino Container on Docker.
