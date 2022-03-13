---
layout: default
title: "Concept & Overview"
nav_order: 1
description: "HCL Domino Container"
has_children: true
---

[Quickstart](https://ibm.github.io/domino-docker/quickstart){: .btn }
[View it on GitHub](https://github.com/IBM/domino-docker){: .btn }

---

# Domino Container

This project contains build scripts for HCL Domino Docker/Container images via [dockerfiles](https://docs.docker.com/engine/reference/builder/).
The repository provides the utilities to build HCL Domino Server with the latest software or specific version in a Docker/Container image.
There are separate folders within this repository for Domino add-on HCL products like Traveler and HCL Domino Volt as well.

All required HCL web-kits and fixes are downloaded from a software repository server instead of adding the source installation files to the image directly.
If no remote server is referenced a temporary local [NGINX container](https://hub.docker.com/_/nginx) is started at build time to act as a **software repository server**.

## Supported environments

The project is supported on Docker Desktop, Docker Server, Podman, Rancher Desktop, Kubernetes (K8s) and OpenShift.
See detailed information about [supported run-time and build environments](supported-environments.md)

## Where to get HCL Domino software

The project uses the official HCL web-kit installers to build container images download from the official HCL Flexnet repository.

- All HCL customers with active maintenance should have a download account for [HCL Flexnet software portal](https://hclsoftware.flexnetoperations.com/flexnet/operationsportal)
- HCL Business Partners with the [Partner Pack](https://www.hcltechsw.com/resources/partner-connect/resources/partner-pack) can download software in a similar way

## How download this project

If you are directly connected to the GitHub server the recommended method to download this project is to use a git client, which is part of any Linux distribution.

Example: Install for Redhat/CentOS based platforms via yum

```
yum install git -y
```

Create a directory where to download Git projects and switch to it.

Example:

```
mkdir -p /local/github
cd /local/github
```

Clone the repository and switch to the directory

```bash
git clone https://github.com/IBM/domino-docker.git
cd domino-docker
```

Note:  
Leveraging Git repositories directly does allow to update the repository via `git pull`.  
Git also allows to swith between different branches of the project.  
The project uses a main and a develop branch. The develop branch should be only used by experienced administrators.


## How to build the image(s)

To build the latest available image
1. Download the required software packages to the 'software' directory
2. From the root folder of this repository issue the following command

```bash
./build domino
```

The process will perform all required actions to create the image in the version requested. Usually it takes 5 to 8 minutes to build the image (depending on your CPU & disk performance).

Other options available:

* ```./build traveler``` - Traveler on Domino
* ```./build volt``` - Volt on Domino

## How to use this image
When a new container is created from the HCL Domino Docker image, it takes [environment variables](run-variables.md) into account for auto-configuring the Domino server.
Details on how to use those variables can be found [here](run-variables.md)

The Domino data directory needs to be a persistent volume. On Docker it will be automatically created.
You can also use an existing volume. All volume types your container infrastructure supports can be used.

### Creating a new container from an image manually

Run a new Domino server with the configuration details of your choice.
Make sure to specify the base image name at the very end of this command

```bash
docker run -it \
     -e "SetupAutoConfigure: 1 \
     -e "SERVERSETUP_SERVER_TYPE: first \
     -e "SERVERSETUP_ADMIN_FIRSTNAME: John \
     -e "SERVERSETUP_ADMIN_LASTNAME: Doe \
     -e "SERVERSETUP_ADMIN_PASSWORD: domino4ever \
     -e "SERVERSETUP_ADMIN_IDFILEPATH: admin.id \
     -e "SERVERSETUP_ORG_CERTIFIERPASSWORD: domino4ever \
     -e "SERVERSETUP_SERVER_DOMAINNAME: DominoDemo \
     -e "SERVERSETUP_ORG_ORGNAME: Domino-Demo \
     -e "SERVERSETUP_SERVER_NAME: domino-demo-v12 \
     -e "SERVERSETUP_NETWORK_HOSTNAME: domino.acme.com \
    -h domino.acme.com \
    -p 80:80 \
    -p 1352:1352 \
    -v dominodata_demo:/local/notesdata \
    --stop-timeout=60 \
    --name domino12 \
    hclcom/domino:latest
```

## Runtime configuration

During ```docker run``` you can setup a volume that mounts property files into `/local/notesdata`

### Stopping the Application Server gracefully

Stopping a Domino server takes longer than the time a Docker server would expect by default (**10 seconds**), the recommended way is to add the parameter `--stop-timeout` already when starting the container.
If the container was started with the parameter ```--stop-timeout=``` then you may stop the container using the following command:

```docker stop <container-name>```

If the container was started without specifying the parameter `--stop-timeout=` then use the following command to stop the container gracefully

```docker stop --time=<timeout> <container-name>```

Example:

```docker stop --time=60 test```


## License
The Dockerfiles and associated scripts are licensed under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0.html). 

License for the products that can be installed within the images is as follows:
* HCL Domino Enterprise Server 12 under the [HCL License Agreement](https://www.hcltechsw.com/wps/portal/resources/license-agreements)
* HCL Domino Volt under the [HCL License Agreement](https://www.hcltechsw.com/wps/portal/resources/license-agreements)
* HCL Notes Traveler under the [HCL License Agreement](https://www.hcltechsw.com/wps/portal/resources/license-agreements)

Note that HCL Domino and add-on products are commercial software - The software licenses agreement does not permit further distribution of the docker image that was built using this script.
