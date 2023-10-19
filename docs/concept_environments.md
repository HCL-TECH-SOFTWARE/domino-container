---
layout: default
title: "Supported Environments"
nav_order: 2
parent: "Concept & Overview"
description: "Support environments to run and build the container"
has_children: false
---

# Supported Environments

The following environments have been tested and are the main environments the project works with.
Other Kubernetes based environments might work as well. Please provide feedback if you are running in other environments.
But be aware that we cannot look into all distributions and run-time environments.


## Supported run-time environments

- Docker CE 20.10+
  on Linux/Docker Desktop on Mac, Docker Desktop on Windows
  (Optional with Docker Compose V1.26+)

- Podman 3.3.0+ *)

- Kubernetes (K8s) v1.20+

- RedHat OpenShift 4.x+

*) Note: If Podman and Docker are installed on the same machine, Podman is used by default.
You can switch manually from Podman to Docker for the build and run-time environment using
`CONTAINER_CMD=docker` either in the configuration or exporting an environment variable in your shell.

## Supported build environments

- Docker CE 20.10 and higher on Linux
- Docker Desktop on Mac
- Docker Desktop on Windows building with a WSL2 sub-system (for example Ubuntu 22.04)
- Podman 3.3.0+ on Linux *)
- Rancher Desktop 1.5+ with Docker back-end

*) Same Podman / Docker note applies


## Recommended Linux Versions and Tips

Docker CE and Podman are available in most distributions.
Some distributions come with Docker CE or Podman included.
Before you install Docker CE or Podman, please check if your platform provides the required version.

- RHEL 8 / CentOS Stream 8+ ship with a current version of Podman
- SUSE SLES / Leap 15.3+ a ships with a current Docker version
- If your platform does not come with a current Docker version there is an official [Docker Linux setup documentation](https://docs.docker.com/engine/install/)

## Recommended combinations (10/2023)

### Build and run-time environments

- RHEL/CentOS Stream 9 with Docker 20.x or Podman 3.3.0+
- SUSE SLES / Leap 15.3+ with Docker 20.x or Podman 3.3.0+
- Current Rancher Desktop (Docker environment)
- Current version of Docker Desktop with WSL2 sub-system to build the image
- Current version of Docker Desktop on Mac

### Run-time environments

- Current version of Docker Desktop on Windows
- k3s Rancher
- Current Rancher Desktop
- Current version of Kubernetes
- Current versions of OpenShift

### Supported base images

The following Linux base images have been tested.  
Current default base image is **CentOS Stream 9**.  
Usually there is no need to change 

Resulting image size differs by base image and how current the base image is.  
The currently smallest and most up to date base image is VMware Photon OS 5

**Note:**  
Starting with Domino V14 a 5.14+ kernel is required
The 5.x kernel is officially supported starting with Domino 12.0.2.
Ensure the base operating systems is running a kernel compatible with the Domino version running inside the container

Short names below can be used with the `build.sh -from=image` option.  
For example build based on **Redhat UBI** : `./build.sh domino -from=ubi`


The project shifted to the current major version for all base image images of each distribution.

Please note that SUSE currently does not provide any Linux version, supporting glibc 2.34 or higher, which is required to run Domino V14.
The next Service Pack is expected mid 2024.

| Short Name    | Name                            | Image Name                          | glibc Ver |
| ------------- | ------------------------------- | ----------------------------------- | ----------|
| centos        | CentOS Stream 9                 | quay.io/centos/centos:stream9       | 2.34      |
| ubi           | Red Hat Enterprise Linux 9.x    | registry.access.redhat.com/ubi9     | 2.34      |
| photon        | VMware Photon OS/Linux          | photon                              | 2.36      |
| rocky         | Rocky Linux 9.x                 | rockylinux/rockylinux:9             | 2.34      |
| alma          | AlmaLinux 9.x                   | almalinux:9                         | 2.34      |
| amazon        | Amazon Linux 2023               | amazonlinux                         | 2.34      |
| oracle        | Oracle Linux Server 9.x         | oraclelinux:9                       | 2.34      |
| ubuntu        | Ubuntu 22.04.x LTS              | ubuntu                              | 2.35      |
| debian        | Debian GNU/Linux 12             | debian                              | 2.36      |
| leap          | openSUSE Leap 15.x              | opensuse/leap:15                    | 2.31      |
| bci           | SUSE Linux Enterprise Server 15 | registry.suse.com/bci/bci-base:15.5 | 2.31      |


## References

- [Docker Engine for Linux](https://docs.docker.com/engine/install/)
- [Docker Compose](https://docs.docker.com/compose/)
- [Docker Desktop with WSL2](https://docs.docker.com/docker-for-windows/wsl/)
- [Docker Desktop Mac](https://docs.docker.com/docker-for-mac/install/)
- [Podman](https://podman.io/)
- [K3S Lightweight Kubernetes](https://k3s.io/)
- [Kubernetes (K8s)](https://kubernetes.io/)
- [RedHat OpenShift](https://www.openshift.com/)
- [Rancher Desktop](https://rancherdesktop.io/)
