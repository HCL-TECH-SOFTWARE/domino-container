- [Intro](#intro)
- [Install Docker](#install-docker)
  - [Verify Docker is running](#verify-docker-is-running)
- [Host name / FQDN](#host-name--fqdn)
  - [Edit Hosts file](#edit-hosts-file)
- [Download a pre-built HCL Domino Volt Docker image](#download-a-pre-built-hcl-domino-volt-docker-image)
- [Import an existing image](#import-an-existing-image)
- [Create a persistent volume](#create-a-persistent-volume)
- [Run a new container with HCL Domino Volt.](#run-a-new-container-with-hcl-domino-volt)
- [Using the environment](#using-the-environment)
  - [Access HCL Domino Volt](#access-hcl-domino-volt)
  - [Stop](#stop)
  - [Start](#start)
- [Reset](#reset)
  - [Destroy the server instance](#destroy-the-server-instance)
  - [Remove the Docker image](#remove-the-docker-image)

# Intro
This guide describes how to build a HCL Domino Volt demo environment using a pre-built Docker image on your desktop computer.

# Install Docker
The demo environment is based on [Docker Desktop](https://www.docker.com/products/docker-desktop) which first needs to be installed. Choose the installer according to your operating system:

* [Linux](https://docs.docker.com/engine/install/ubuntu/)
* [MacOS](https://hub.docker.com/editions/community/docker-ce-desktop-mac/)
* [Windows](https://hub.docker.com/editions/community/docker-ce-desktop-windows)

## Verify Docker is running
Once the installation is complete, open a command prompt and enter the following command to see if docker was installed successfully on your computer:

```bash
docker --version
```
The result should be something like:
Docker version 19.03.8, build afacb8b

# Host name / FQDN
HCL Domino Volt server needs a fully qualified host name in order to work correctly. Since your local computer might change its FQDN we will need to create a dummy hostname that can be used later on to run HCL Domino Volt.

Define what fully qualified host name to be used for this demo environment.
In this example we will be using "volt.demo.com"
In case you would like to use a different host name, make sure to use it consistently in the following steps.

## Edit Hosts file
To redirect all requests to the host name defined earlier, edit the hosts file on your computer using this command:
* MacOSX : ```sudo nano /etc/hosts```
* Windows : ```notepad C:/Windows/System32/drivers/etc/hosts```

and add the following line:
```
127.0.0.1   volt.demo.com
```

# Download a pre-built HCL Domino Volt Docker image
Download the HCL Domino Volt Docker image from the link that you have received.
Do not change the file name and do not unpack the file.

# Import an existing image
Open a new terminal (MacOS) or command line window (Windows) and navigate to the folder where you saved the download.

e.g.: 
* for MacOSX : ```cd ~/Downloads```
* for Windows : ```cd %UserProfile%/Downloads```

To import the Docker image downloaded before type the following command
```bash
docker image load -i hclcomvolt1005.tar.gz
```

To verify if the import was successful, type:
```bash
docker image list
```
The result should look like this:
```
REPOSITORY     IMAGE ID            CREATED             SIZE     TAG
hclcom/volt    3d40cc94881c        11 hours ago        1.56GB   1.0.0.5
```

# Create a persistent volume
Create a new (empty) volume that will be used as Domino Data directory. It will host all applications created for this instance of Volt.
```bash
docker volume create domino_volt
```

# Run a new container with HCL Domino Volt.
To create a new Docker container based on the image imported earlier use the following command.

Please note:
* change AdminFirstName / AdminLastName and AdminPassword according to your needs.
* (optional) update the value of "-h" parameter in this command in case you want to use a [different host name](#host-name--fqdn). 

```bash
docker run -it -e "ServerName=Volt" \
    -e "OrganizationName=Amp" \
    -e "AdminFirstName=Thomas" \
    -e "AdminLastName=Hampel" \
    -e "AdminPassword=passw0rd" \
    -e "ConfigFile=config.json" \
    -h volt.demo.com \
    -p 80:80 \
    -p 443:443 \
    -p 1352:1352 \
    -v domino_volt:/local/notesdata \
    --stop-timeout=60 \
    --name volt \
    hclcom/volt:1.0.0.5
```
When starting up the container, a new Domino server is configured based on the parameters defined. Also a (locally trusted) SSL certificate is created automaticlly for the host name specified.

First time startup should take approx. 30 seconds before you can [access HCL Domino Volt](#access-hcl-domino-volt)

# Using the environment
Describes how to access HCL Domino Volt and how to start and stop the docker container.

## Access HCL Domino Volt
Open a web browser of your choice and navigate to 
https://volt.demo.com

Login with the username / password you have defined earlier where username is <AdminFirstName> and <AdminLastName> are combined.
Based on the variables used in the example above to initialize the container

username = Thomas Hampel
password = passw0rd

Note: When accessing the container for the first time it will take a few seconds after logging in to initialize the environment.

## Stop
In order to stop the Docker container use the following command:
```bash
docker stop volt
```
or use the user interface of Docker Desktop 

## Start
To start the existing Docker container again use this command:
```bash
docker start volt
```
or use the user interface of Docker Desktop 

# Reset

## Destroy the server instance
In order to start from scratch you can destroy the Docker container and all data contained on the docker volume created earlier.
To do this enter the following commands:
```bash
docker stop volt
docker container rm volt
docker volume rm domino_volt
```
Although the Docker container and the volume have been removed, the Docker image containing the base HCL Domino Volt still is available.
You can now start all over with [creating a new empty volume](#create-a-volume) and [running a new container](#run-a-new-container-with-hcl-domino-volt)

## Remove the Docker image
To remove the Docker image that was previously imported, first [destroy any existing volt instance](#destroy-the-server-instance) and then use this command to remove the image:
```bash
docker image rm hclcom/volt:1.0.0.5
```
