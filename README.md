# Domino Docker 
This project contains build scripts for Docker images (Dockerfiles) and Docker related utilities for IBM Domino. There are separate folders within this repository that contain build scripts for IBM sThis repository provides the to build an IBM Domino Server with latest fixes.

Main idea is to download and apply all required fixes/patches/updates from a software respository server instead of adding the source installation files to the image directly. For this reason this repo will start a temporary local nginx server at build time to act as a software repository server.

## How to build the image(s)
to be documented

## How to use this image
When a new container is started by using the IBM Domino Docker image, it takes the following environment variables into account for auto-configuring the Domino server:

* isFirstServer 
* AdminFirstName
* AdminIDFile
* AdminLastName
* AdminMiddleName
* AdminPassword
* CountryCode
* DominoDomainName
* HostName
* OrgUnitIDFile
* OrgUnitName
* OrgUnitPassword
* OrganizationIDFile
* OrganizationName
* OrganizationPassword
* OtherDirectoryServerAddress
* OtherDirectoryServerName
* ServerIDFile
* ServerName
* SystemDatabasePath
* ServerPassword

## Runtime configuration

During ```docker run``` you can setup a volume that mounts property files into /etc/websphere, such as:

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
Special Thanks go to the following people for having provided valuable input this project


* [Ulrich Krause](https://www.eknori.de/2017-08-20/domino-on-docker/).
* Matteo Bisi https://www.slideshare.net/mbisi/connect2016-1172-shipping-domino and his [Github repo](https://github.com/matteobisi/docker)
* Daniel Nashed for donating his [startscript](https://www.nashcom.de/nshweb/pages/startscript.htm)
* [Egor Margineanu](https://www.egmar.ro/) who also can be found on [Github](https://github.com/egmar)



## License
The Dockerfiles and associated scripts are licensed under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0.html). 

License for the products that can be installed within the images is as follows:

* IBM Domino Enterprise Server 10.0 under the [International Program License Agreement](https://www-03.ibm.com/software/sla/sladb.nsf/displaylis/FB664D0899DE8E7C8525832100805159?OpenDocument)
* IBM Domino Community Server under the [International License Agreement for Non-Warranted Programs](https://www-01.ibm.com/common/ssi/rep_ca/2/877/ENUSZP17-0552/ENUSZP17-0552.PDF)
 
With some modifications the following base images can be built
* IBM Domino Utility Server
* IBM Domino Collaboration Express
* IBM Domino Messaging Express

Note that this license does not permit further distribution.