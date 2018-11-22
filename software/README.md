## Description

This directory is used to host the installation packages that will be used inside of a Docker image. 

Each folder is supposed to contain the packages required for the corresponding image. You must download the software before building the image(s). File names are important.

##  Software Repository Server
The software repository server is used by the build scripts to download IBM software packages rather than adding them to the image. It is not required to start or stop this repository server manually, all actions are taken care of in the build scripts. However, we are providing the script ```software-repo.sh``` for manual handling in case its required.

### Hosting this software repository

To build the Docker images an Nginx server will be serving this folder so that it can be used as a source for automated software downloads. It is possible to host this repository elsewhere in your corporate environment as long as it is accessible via HTTP and the folder structure and file names remain the same.

### Using the Software Repository Server

Use the script ```software-repo.sh``` to start or stop an nginx container which will host this directory for HTTP access. The script also allows to obtain the IP address of the container using the command ```software-repo.sh ip```

When the software repository server is no longer needed you can shut down and remove the container using the command ```software-repo.sh stopremove```

## Where to download
Software packages can be downloaded from the following locations. 
* [Passport Advantage](https://www-01.ibm.com/software/passportadvantage/pao_customer.html)
* [Fix Central](https://www-945.ibm.com/support/fixcentral)
For testing a [trial version](https://www-01.ibm.com/marketing/iwm/tnd/preconfig.jsp?id=2016-05-21+05%3A25%3A52.674466R) will do as long as the file name will be changed accordingly

## Domino 10
For an overview of software packages that need to be provided to build the Domino 10 docker images please refer to [Domino10](https://github.com/IBM/domino-docker/tree/master/software/domino10)