# Domino Docker 
This project contains build scripts for Docker images (dockerfiles) and Docker related utilities for HCL Domino. There are separate folders within this repository that contain build scripts for other HCL products like Traveler and HCL Domino Volt. This repository provides the utilities to build an HCL Domino Server with the latest fixes in a Docker image.

Main idea is to download and apply all required fixes/patches/updates from a software repository server instead of adding the source installation files to the image directly. For this reason this repo will start a temporary local nginx server at build time to act as a [software repository server](software).


## Supported environments

The project is supported on Docker Desktop, Docker Server, Podman, Kubernetes (K8s) and OpenShift.
See detailed information about [supported run-time and build environments](docs/supported-environments.md)

## Where to get HCL Domino software

The Docker scripts work with software you download from HCL. So the Docker image is build with a dockerfile installing software from HCL.  
All HCL customers (and business partners with the [Partner Pack](https://www.hcltechsw.com/resources/partner-connect/resources/partner-pack) should have a download account for [HCL Flexnet software portal](https://hclsoftware.flexnetoperations.com/flexnet/operationsportal).


## How to build the image(s)
To build the latest available image 
1. Download the required [software packages](software/README.md) to the 'software' directory
2. From the root folder of this repository issue the following command 
```bash
./build domino
```
The process will perform all required actions to create the image in the version requested. Usually it takes less than 8 minutes to build the image (depending on your CPU & disk performance).

Other options available:
* ```build traveler``` - Traveler on Domino
* ```build volt``` - Volt on Domino
 
## How to use this image
When a new container is created from the HCL Domino Docker image, it takes [environment variables](docs/run-variables.md) into account for auto-configuring the Domino server. Details on how to use those variables can be found [here](docs/run-variables.md)

Domino Data directory needs to be a persistent volume. On Docker it will be automatically created. You can also use an existing volume. All volume types your container infrastructure supports can be used.

### Management Script
The folder [Management](master/management) contains a script that simplifies the managing your containers. The Linux bash script is supposed to run on the Docker host.

For details see the documentation of the [Management Script](management.md)

### Manually creating a new container from an image
First create a new/empty persistent volume that will be used as the Domino Data directory later on. In this example we are calling it "dominodata_demo1".
In most cases you can just specify a volume and Docker will create the volume for you.

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
    --stop-timeout=60 \
    --name server1 \
    hclcom/domino:11.0.1
```

### Running HCL Domino Volt on Docker

Fist choose an external host name that will be used to access this container. 
In the example below we are using 'volt.demo.com'
Note: When using a non-existing DNS name, make sure you update your local hosts file to route 'volt.demo.com' to 127.0.0.1 on your machine.

Run a new Domino server with the configuration details of your choice. 
The persisten `dominodata_volt` will be created automatically on your local Docker host.

!Important!
* Volt requires the host name to be specified using the -h parameter.
* Make sure to specify the base image name at the very end of this command

```bash
docker run -it -e "ServerName=Volt" \
    -e "OrganizationName=Amp" \
    -e "AdminFirstName=Thomas" \
    -e "AdminLastName=Hampel" \
    -e "AdminPassword=passw0rd" \
    -h volt.demo.com \
    -p 80:80 \
    -p 1352:1352 \
    -v dominodata_volt:/local/notesdata \
    --stop-timeout=60 \
    --name volt \
    hclcom/volt
```

It takes up to 60 seconds to start the container. You will be able to access HCL Domino Volt using https://volt.demo.com 
An (untrusted) SSL certificate is automatically created within the container for the host name specified above.

## Runtime configuration

During ```docker run``` you can setup a volume that mounts property files into `/local/notesdata`

### Stopping the Application Server gracefully
Stopping a Domino server takes longer than the time a Docker server would expect by default (10 seconds), the recommended way is to add the parameter "--stop-timeout" already when starting the container. If the container was started with the parameter ```--stop-timeout=``` then you may stop the container using the following command:

```docker stop <container-name>```

If the container was started without specifying the parameter ```--stop-timeout=``` then use the following command to stop the container gracefully

```docker stop --time=<timeout> <container-name>```

Example:

```docker stop --time=60 test```


## Issues
For issues relating specifically to the Dockerfiles and scripts, please use the [GitHub issue tracker](issues)

## Contributing
We welcome contributions following [our guidelines](CONTRIBUTING.md).

## Community Support
Special Thanks go to the following people for having provided valuable input to this project

* [Ulrich Krause](https://www.eknori.de/2017-08-20/domino-on-docker/).
* Matteo Bisi's [Presentation](https://www.slideshare.net/mbisi/connect2016-1172-shipping-domino) and his [Github repo](https://github.com/matteobisi/docker)
* Daniel Nashed for donating his [startscript](https://www.nashcom.de/nshweb/pages/startscript.htm) under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0.html). 
* [Egor Margineanu](https://www.egmar.ro/) who also can be found on [Github](https://github.com/egmar)


## License
The Dockerfiles and associated scripts are licensed under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0.html). 

License for the products that can be installed within the images is as follows:
* HCL Domino Volt 1.0 under the HCL License Agreement (https://www.hcltechsw.com/wps/portal/resources/license-agreements)
* HCL Notes Traveler 11.0 under the HCL License Agreement (https://www.hcltechsw.com/wps/portal/resources/license-agreements)
* HCL Domino Enterprise Server 11.0 under the HCL License Agreement (https://www.hcltechsw.com/wps/portal/resources/license-agreements)
* IBM Domino Enterprise Server 10.0 under the [International Program License Agreement](https://www-03.ibm.com/software/sla/sladb.nsf/displaylis/FB664D0899DE8E7C8525832100805159?OpenDocument)
 
 
Note that the HCL Domino and add-on products are commercial software - the software licenses agreement does not permit further distribution of the docker image that was built using this script.
