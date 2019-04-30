# Domino Docker 
This project contains build scripts for Docker images (Dockerfiles) and Docker related utilities for IBM Domino. There are separate folders within this repository that contain build scripts for IBM. This repository provides an IBM Domino Server with the latest fixes.

Main idea is to download and apply all required fixes/patches/updates from a software repository server instead of adding the source installation files to the image directly. For this reason this repo will start a temporary local nginx server at build time to act as a [software repository server](https://github.com/IBM/domino-docker/tree/master/software).

## How to build the image(s)
To build the latest available image 
1. Download the required [software packages](https://github.com/IBM/domino-docker/blob/master/software/README.md) to the 'software' directory
2. From the root folder of this repository issue the following command 
```bash
build domino
```
The process will perform all required actions to create the image in the version requested. Usually it takes less than 5 minutes to build the image.

## How to use this image
When a new container is created from the IBM Domino Docker image, it takes [environment variables](https://github.com/IBM/domino-docker/blob/master/documentation/run-variables.md) into account for auto-configuring the Domino server. Details on how to use those variables can be found [here](https://github.com/IBM/domino-docker/blob/master/documentation/run-variables.md)

* Domino Data directory needs to be a persistant volume.

## Docker for Windows
Before attempting to create an image, ensure that you are sharing the appropriate drive in the Docker for Windows settings:
![Windows drive settings](documentation/images/docker-windows-shared-drives.png)

### Manually creating a new container from an image
First create a new/empty persistent volume that will be used as the Domino Data directory later on. In this example we are calling it "dominodata_demo1".

```bash
docker volume create dominodata_demo1
```
Then run a new Domino server with the configuration details of your choice. Make sure to specify the base image name at the very end of this command

```bash
docker run -it -e "ServerName=Server1" \
    -e "OrganizationName=MyOrg" \
    -e "AdminFirstName=Thomas" \
    -e "AdminLastName=Hampel" \
    -e "AdminPassword=passw0rd" \
    -h wien.demo.com \
    -p 80:80 \
    -p 1352:1352 \
    -v dominodata_demo1:/local/notesdata \
    --name server1 \
    ibmcom/domino:10.0.0
```
For Docker for Windows edit the file run_windows.cmd and run this from the command line
## Runtime configuration

During ```docker run``` you can setup a volume that mounts property files into `/local/notesdata`

### Stopping the Application Server gracefully
Stopping a Domino server takes longer than the time a Docker server would expect by default, so it is recommended to specify the timeout parameter when stopping a container.

```docker stop --time=<timeout> <container-name>```

Example:

```docker stop --time=60 test```

## Issues
For issues relating specifically to the Dockerfiles and scripts, please use the [GitHub issue tracker](https://github.com/IBM/domino-docker/issues)

## Contributing
We welcome contributions following [our guidelines](https://github.com/IBM/domino-docker/blob/master/CONTRIBUTING.md).

## Community Support
Special Thanks go to the following people for having provided valuable input to this project

* [Ulrich Krause](https://www.eknori.de/2017-08-20/domino-on-docker/).
* Matteo Bisi's [Presentation](https://www.slideshare.net/mbisi/connect2016-1172-shipping-domino) and his [Github repo](https://github.com/matteobisi/docker)
* Daniel Nashed for donating his [startscript](https://www.nashcom.de/nshweb/pages/startscript.htm) under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0.html). 
* [Egor Margineanu](https://www.egmar.ro/) who also can be found on [Github](https://github.com/egmar)


## License
The Dockerfiles and associated scripts are licensed under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0.html). 

License for the products that can be installed within the images is as follows:

* IBM Domino Enterprise Server 10.0 under the [International Program License Agreement](https://www-03.ibm.com/software/sla/sladb.nsf/displaylis/FB664D0899DE8E7C8525832100805159?OpenDocument)
* IBM Domino Community Server under the [International License Agreement for Non-Warranted Programs](https://www-01.ibm.com/common/ssi/rep_ca/2/877/ENUSZP17-0552/ENUSZP17-0552.PDF)
 
With some modifications the following base images can be built:
* IBM Domino Utility Server
* IBM Domino Collaboration Express
* IBM Domino Messaging Express
  
Note that the IBM Domino is commercial software - the software licenses agreement does not permit further distribution of the docker image that was built using this script.