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

- Docker CE 18.09+
  on Linux/Docker Desktop on Mac, Docker Desktop on Windows
  (Optional with Docker Compose V1.26+)

- Podman 1.5.0+ *)

- Kubernetes (K8s) v1.18+

- RedHat OpenShift 4.x+

*) Note: If Podman and Docker are installed on the same machine, Podman is used by default.
You can switch manually from Podman to Docker for the build and run-time environment using
`CONTAINER_CMD=docker` either in the configuration or exporting an environment variable in your shell.

## Supported build environments

- Docker CE 18.09 and higher on Linux
- Docker Desktop on Mac
- Docker Desktop on Windows building with a WSL2 sub-system
- Podman 1.5.0+ on Linux *)
- Rancher Desktop 1.0+ with Docker back-end

*) Same Podman / Docker note applies


## Supported base images

- RedHat Universal Base Image (UBI) 8
- CentOS Stream 8.x
- CentOS Stream 9.x
- RockyLinux 8.x
- AlmaLinux 8.x
- VMware PhotonOS
- SUSE Leap 15.3
- Oracle Linux 8
- Amazon Linux


## Recommended Linux Versions and Tips

Docker CE and Podman are available in most distributions.
Some distributions come with Docker CE or Podman included.
Before you install Docker CE or Podman, please check if your platform provides the required version.

- RHEL 8 / CentOS Stream 8 ship with a current version of Podman
- SUSE SLES / Leap 15.3 a shipps with a current Docker version
- If your platform does not come with a current Docker version there is an official [Docker Linux setup documentation](https://docs.docker.com/engine/install/)

## Recommended combinations (3/2022)

### Build and run-time environments

- RHEL 8 /CentOS Stream 8 with Docker 20.x installed from Docker website
- SUSE SLES / Leap 15.3 with Docker 20.x included
- RHEL 8 / CentOS Stream 8 with Podman
- Current Rancher Desktop (Docker environment)
- Current version of Docker Desktop with WSL2 sub-system to build the image
- Current version of Docker Desktop on Mac

### Run-time environments

- Current version of Docker Desktop on Windows
- k3s Rancher
- Current Rancher Desktop
- Current version of Kubernetes
- Current version of OpenShift


### Tested base images

The following Linux base images have been tested.  
Current default base image is **CentOS Stream 8**.  
Resulting image size differs by base image.  
The smalles base images are based on PhotonOS

**Note:**  
Many base images use a kernel 5.x already.  
The kernel is not yet supported by Domino.  
Ensure the base operating systems is also running a comparable 5.x kernel.

Short names below can be used with the `build.sh -from=image` option.  
For example build based on **Redhat UBI8** : `./build.sh domino -from=ubi`


| Short Name    | Name                  | Image Name                    | Kernel Ver |
| ------------- | --------------------- | ----------------------------- | ---------- |
| ubi           | RedHat UBI            | redhat/ubi8                   | 4.x        |
| centos8       | CentOS Stream 8       | quay.io/centos/centos:stream8 | 4.x        |
| rocky         | Rocky Linux 8         | rockylinux/rockylinux         | 4.x        |
| alma          | Alma Linux 8          | almalinux/almalinux:8         | 4.x        |
| amazon        | Amazon Linux          | amazonlinux                   | 4.x        |
| oracle        | Oracle Linux 8        | oraclelinux:8                 | 4.x        |
| centos9       | CentOS Stream 9       | quay.io/centos/centos:stream9 | 5.x        |
| leap          | SUSE Leap 15.3        | opensuse/leap                 | 5.x        |
| photon        | VMware Photon OS      | photon                        | 5.x        |


## References

- [Docker Engine for Linux](https://docs.docker.com/engine/install/)
- [Docker Compose](https://docs.docker.com/engine/install/)
- [Docker Desktop with WSL2](https://docs.docker.com/docker-for-windows/wsl/)
- [Docker Desktop Mac](https://docs.docker.com/docker-for-mac/install/)
- [Podman](https://podman.io/)
- [K3S Lightweight Kubernetes](https://k3s.io/)
- [Kubernetes (K8s)](https://kubernetes.io/)
- [RedHat OpenShift](https://www.openshift.com/)
- [Rancher Desktop](https://rancherdesktop.io/)
