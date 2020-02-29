## Description

This directory is used to host the installation packages that will be used inside of a Docker image. 

All packages required for building the corresponding image should be located in this folder without using any subfolders. You must download the software before building the image(s). File names are important so please keep the default file names.

##  Software Repository Server
The software repository server is used by the build scripts to download IBM software packages rather than adding them to the image. It is not required to start or stop this repository server manually, all actions are taken care of in the build scripts. However, we are providing the script ```software-repo.sh``` for manual handling in case its required.

### Hosting this software repository

To build the Docker images an Nginx server will be serving this folder so that it can be used as a source for automated software downloads. It is possible to host this repository elsewhere in your corporate environment as long as it is accessible via HTTP and the folder structure and file names remain the same.

### Using the Software Repository Server

Use the script ```software-repo.sh``` to start or stop an nginx container which will host this directory for HTTP access. The script also allows to obtain the IP address of the container using the command ```software-repo.sh ip```

When the software repository server is no longer needed you can shut down and remove the container using the command ```software-repo.sh stopremove```

## What to download

This directory is supposed to contain the original downloaded files from FlexNet download. 
Make sure to keep the file name unchanged otherwise build scripts will not work.
The build script shows missing donwload packages and points you to the right download location.

