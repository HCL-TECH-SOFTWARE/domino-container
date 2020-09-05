# Supported Environments

The following environments have been tested and are the main environments the project works with.
Other Kubernetes based environments might work as well. Please provide feedback if you are running in other environments. But be aware that we cannot look into all environments on our own.


## Supported run-time environments

- Docker CE 18.09.0 and higher  
  on Linux/Docker Desktop on Mac, Docker Desktop on Windows (classic and WSL2)  
  (Optional with Docker Compose V1.26+)

- Podman 1.5.0+ *)

- Kubernetes (K8s) v1.18+

- RedHat OpenShift 4.x+

*) Note: If Podman and Docker are installed on the same machine, Podman is used by default. You can switch manually from Podman to Docker for the build and run-time environment using `DOCKER_CMD=docker` either in the configuration or exporting an environment variable in your shell.

## Supported build environments

- Docker CE 18.09.0 and higher
  on Linux/Docker Desktop on Mac, Docker Desktop on Windows building with a WSL sub-system

- Podman 1.5.0+ on Linux *)

*) Same Podman/Docker note applies


## Supported base images

- CentOS 7
- CentOS 8
- RedHat Universal Base Image (UBI) Version 8

## Recommended Linux Versions and Tips

Docker CE and Podman are available in most distributions. Some distributions come with Docker CE or Podman included. Before you install Docker CE or Podman, please check if your platform provides the required versions.

For example CentOS 7 comes with an old Docker version, which cannot be used.
Older RedHat and SLES releases might also have older Podman versions.
You should not try to run with earlier Docker/Podman versions than stated above, because those versions don't provided the needed feature set. 

- RHEL/CentOS 8 ship with a current version of Podman
- RHEL/CentOS 8 ships with an older containerd version which prevents Docker CE 19.x to be installed
- SLES 15 SP2 shipps with the current Docker version
- If your platform does not come with a current Docker version there is an official way to install Docker on most platforms https://docs.docker.com/engine/install/

### Recommended combinations (9/2020)

- RHEL/CentOS 7 with Docker 19.x installed from Docker website
- SLES 15 SP2 with Docker 19.x included in SLES
- RHEL/CentOS 8 with Podman 1.6.x
- Current version of Docker Desktop on Windows (run-time only)
- Current version of Docker Desktop with WSL2 sub-system to build the image
- Current version of Docker Desktop on Mac
- Current version of Kubernetes
- Current version of OpenShift

## References

- Docker Engine for Linux
  https://docs.docker.com/engine/install/

- Docker Compose
  https://docs.docker.com/engine/install/

- Docker Desktop with WSL2
  https://docs.docker.com/docker-for-windows/wsl/

- Docker Desktop Mac
  https://docs.docker.com/docker-for-mac/install/

- Podman
  https://podman.io/

- Kubernetes (K8s)
  https://kubernetes.io/

- RedHat OpenShift
  https://www.openshift.com/

- RedHat Universal Base Image (UBI)
  https://developers.redhat.com/products/rhel/ubi


