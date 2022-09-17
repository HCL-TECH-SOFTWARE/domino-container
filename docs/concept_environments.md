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


# Supported run-time environments

- Docker CE 20.10+
  on Linux/Docker Desktop on Mac, Docker Desktop on Windows
  (Optional with Docker Compose V1.26+)

- Podman 3.3.0+ *)

- Kubernetes (K8s) v1.20+

- RedHat OpenShift 4.x+

*) Note: If Podman and Docker are installed on the same machine, Podman is used by default.
You can switch manually from Podman to Docker for the build and run-time environment using
`CONTAINER_CMD=docker` either in the configuration or exporting an environment variable in your shell.

# Supported build environments

- Docker CE 20.10 and higher on Linux
- Docker Desktop on Mac
- Docker Desktop on Windows building with a WSL2 sub-system
- Podman 3.3.0+ on Linux *)
- Rancher Desktop 1.5+ with Docker back-end

*) Same Podman / Docker note applies


# Supported base images

- RedHat Universal Base Image (UBI) 8.6 + 9.x
- CentOS Stream 8.x + 9.x
- RockyLinux 8.x + 9.x
- AlmaLinux 8.x
- VMware PhotonOS 4
- SUSE Leap 15.3+
- SUSE Enterprise 15.3+
- Oracle Linux 8
- Amazon Linux

# Experimental base images

- Ubuntu 22.x
- Debian 11.x


# Recommended Linux Versions and Tips

Docker CE and Podman are available in most distributions.
Some distributions come with Docker CE or Podman included.
Before you install Docker CE or Podman, please check if your platform provides the required version.

- RHEL 8 / CentOS Stream 8+ ship with a current version of Podman
- SUSE SLES / Leap 15.3+ a shipps with a current Docker version
- If your platform does not come with a current Docker version there is an official [Docker Linux setup documentation](https://docs.docker.com/engine/install/)

# Recommended combinations (9/2022)

## Build and run-time environments

- RHEL/CentOS Stream 8/9 with Docker 20.x or Podman 3.3.0+
- SUSE SLES / Leap 15.3+ with Docker 20.x or Podman 3.3.0+
- Current Rancher Desktop (Docker environment)
- Current version of Docker Desktop with WSL2 sub-system to build the image
- Current version of Docker Desktop on Mac

## Run-time environments

- Current version of Docker Desktop on Windows
- k3s Rancher
- Current Rancher Desktop
- Current version of Kubernetes
- Current versions of OpenShift


# Tested base images

The following Linux base images have been tested.  
Current default base image is **CentOS Stream 8**.  
Resulting image size differs by base image.  
The smalles base images are based on PhotonOS

**Note:**  
Many base images use a kernel 5.x already.  
The 5.x kernel is officially supported starting with Domino 12.0.2.
Ensure the base operating systems is also running a comparable 5.x kernel.

Short names below can be used with the `build.sh -from=image` option.  
For example build based on **Redhat UBI** : `./build.sh domino -from=ubi`

Note: When not specifying a major version, the major version default could change and result in a newer major kernel version!


| Short Name    | Name                    | Image Name                          | Kernel Ver |
| ------------- | ----------------------- | ----------------------------------- | ---------- |
| ubi           | RedHat UBI default      | registry.access.redhat.com/ubi      | depends    |
| rocky         | Rocky Linux default     | rockylinux/rockylinux               | depends    |
| leap          | SUSE Leap default       | opensuse/leap                       | depends    |
| alma          | Alma Linux default      | almalinux/almalinux                 | 4.x        |
| ubi8          | RedHat UBI 8            | registry.access.redhat.com/ubi8     | 4.x        |
| centos8       | CentOS Stream 8         | quay.io/centos/centos:stream8       | 4.x        |
| rocky8        | Rocky Linux 8           | rockylinux/rockylinux:8             | 4.x        |
| alma8         | Alma Linux 8            | almalinux/almalinux:8               | 4.x        |
| amazon        | Amazon Linux            | amazonlinux                         | 4.x        |
| oracle        | Oracle Linux 8          | oraclelinux:8                       | 4.x        |
| ubi9          | RedHat UBI 9            | registry.access.redhat.com/ubi9     | 4.x        |
| centos9       | CentOS Stream 9         | quay.io/centos/centos:stream9       | 5.x        |
| rocky9        | Rocky Linux 9           | rockylinux/rockylinux:9             | 5.x        |
| leap15.3      | SUSE Leap 15.3          | opensuse/leap:15.3                  | 5.x        |
| leap15.4      | SUSE Leap 15.4          | opensuse/leap:15.4                  | 5.x        |
| bci           | SUSE Enterprise default | registry.suse.com/bci/bci-base      | 5.x        |
| bci15.3       | SUSE Enterprise 15.3    | registry.suse.com/bci/bci-base:15.3 | 5.x        |
| bci15.4       | SUSE Enterprise 15.4    | registry.suse.com/bci/bci-base:15.4 | 5.x        |
| photon        | VMware Photon OS 4.0    | photon                              | 5.x        |


# References

- [Docker Engine for Linux](https://docs.docker.com/engine/install/)
- [Docker Compose](https://docs.docker.com/compose/)
- [Docker Desktop with WSL2](https://docs.docker.com/docker-for-windows/wsl/)
- [Docker Desktop Mac](https://docs.docker.com/docker-for-mac/install/)
- [Podman](https://podman.io/)
- [K3S Lightweight Kubernetes](https://k3s.io/)
- [Kubernetes (K8s)](https://kubernetes.io/)
- [RedHat OpenShift](https://www.openshift.com/)
- [Rancher Desktop](https://rancherdesktop.io/)
