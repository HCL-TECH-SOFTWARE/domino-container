# Management Script 

This Domino Docker script is intended to simplify your Domino on Docker environment.
It can be used build, run and maintain your Domino on Docker environment.

The "dockerscript" is also a good example how to derive your own image from the standard image.
It comes with a flexible configuration and provides and easy interface for container/image related Docker commands.
This is the logical extension of the Domino start script and works hand in hand with the Domino start script.

It is also a good example how to interact with Docker when you don't have a Docker management solution in place.
You can use the script as a reference also how to query information from the images and containers.

The inspect/info command queries a lot of information from the running Domino servers.

This management script can be used to create custom images and to run them.

----------
## Basics

For each container there are two files that belong together. One containing the configuration and variables, and one for the script itself:

- management script : "docker_"
- configuration file : "config_"

Both file names will refer to each other using the custom string right of "_".

### Example: 
- "docker_123" will use the configuration from "config_123"
- "docker_paul" will use the configuration from "config_paul"


----------

## Quick Config

You just need to build the image and run the container. It will be derived from the image.
The default configuration should work for first tests. But you should check the configuration
and change the naming accordingly (the default configuration contains "Acme").

To ensure you are deriving from the right Domino Docker image, you have to check the "dockerscript"
for the "FROM" statement. This is usually set to something like "FROM ibmcom/domino:latest".
There are multiple example files for different targets like Domino, Domino CE or Traveler.

Afterwards build and run the image.
```bash
docker_domino build
docker_domino run
```

----------

## Components

Currently there are a couple of additional files for testing and demonstration purposes.
This abstract describes the main components of the Domino Docker script.

### docker_domino

This is the main script logic and the central entry point for all operations.
For available commands see the "Commands" abstract.

The script contains a standard configuration which is used when no configuration file is present.


### config_domino

This file contains the configuration for the docker_domino script.
The name has to match the last part of the docker_domino script.
In case you want to run multiple instances you can clone the files and have multiple instances.
For example docker_domino-ce, config_domino-ce. See more "Run multiple instances" section for details.

For configuration details check the next section.


### dockerfile

This dockerfile is deriving from a Docker Domino image and allows customization.
The main logic is performed by the install.sh which is executed from the dockerfile.


### install_dir

This directory contains scripts and files which are copied into the image during installation.
There is a directory for server-tasks and extension-managers which will be automatically installed via install.sh.


#### install_dir/install.sh

The install.sh file contains the main logic used to install the image.
The Docker script invokes this script for installation.
This script can be customized for your own logic.


## Configuration parameters

The following configuration is used to customize your Docker container.
Most of the default configuration should work for you.


### DOCKER_CONTAINER

This parameter defines the name of the container.
It is used in all commands and can be customized -- specially when you need multiple containers.

Example: nashcom-domino


### DOCKER_IMAGE_NAME

This parameter defines the name of the image that is generated (build) and used (run).

Example: nashcom/domino


### DOCKER_IMAGE_VERSION

This parameter defines the image version.
Example: 10.0.0


### DOCKER_FILE

This parameter is used to configure the dockerfile which is used.
The script comes with a ready to use sample dockerfile which you can modify for your needs.

Default: dockerfile

### DOCKER_HOSTNAME

This parameter can be used to configure the hostname for the container.

Example: nsh-domino

### DOMINO_SHUTDOWN_TIMEOUT

Stopping a Domino server usually takes longer than the standard shutdown timeout (10 seconds)
which Docker waits on shutdown before killing the processes.
This parameter is used with the docker stop command. The parameter is --time=timeout-value.

Default: 60

### DOCKER_NETWORK

You can change the network to host network instead of using NAT.
By default this parameter is disabled and NAT is used.

Option: --network=host


### DOCKER_PORTS

You can define which ports are exposed for your container.
By default NRPC, HTTP and HTTPS are exposed.

Default: "-p 1352:1352 -p 80:80 -p 443:443"

For multiple instances on the same Docker host you have to bind the port to an
dedicated IP by specifying an IP with the host.

Example: "-p 192.168.100.100:1352:1352 -p 192.168.100.100:80:80 -p 192.168.100.100:443:443"


### DOCKER_VOLUMES

You have to specify at least one static volume for your Docker container which will contain your data directory.
On first run the /local/notesdata directory will be copied to the volume.

You can also add other volumes for example for translog and DAOS.

Default: "-v notesdata:/local/notesdata"

## Commands

The following commands are currently available.

### build

builds a current image -- even image tags might not have changed to ensure OS patches are installed


### run [live]

runs a container -- will initiate a container if not present ('live' shows start script output, alias 'runit')

### start [live]

start an existing container (the 'live' option shows start script output)

### stop  [live]

stops container (the 'live' option shows start script output)

### status

shows container status (running, exited, notexisting)

### inspect|info

shows information about container and image

### logs

shows container logs (output from entry point script/start script)

### attach

attach to entry point script which is running inside the Docker container.

### domino

pass a command to start script (e.g. domino nsd, domino console).
"domino console" will launch the interactive Domino console (Domino Start Script).

### bash

invokes a bash in the running container

### remove|rm

removes the container (if not running)

### removeimage|rmi

removes the current container (you have to remove the container first)

### update

updates the container if referenced image has changed (stops Domino, stops the container, runs a new image)


### version

shows script version information

----------
## Run multiple instances

When running multiple instances you have to define separate docker_domino and configuration files.
In addition you have specify different container names in each of the configuration files.
You also have to specify a separate IP addresses per container and separate volumes!
Having multiple containers per hosts adds complexity to your environment.
The script allows this deployment scenario. But it's recommended to use a Docker management/deployment solution.
