- [Intro](#intro)
- [Install Docker](#install-docker)
  - [Verify if Docker is running](#verify-if-docker-is-running)
- [Download the pre-built HCL Domino Volt Docker image](#download-the-pre-built-hcl-domino-volt-docker-image)
- [Import an existing image](#import-an-existing-image)
- [Host name / FQDN](#host-name--fqdn)
  - [Edit Hosts file](#edit-hosts-file)
  - [Create a volume](#create-a-volume)
  - [Run a new container with HCL Domino Volt.](#run-a-new-container-with-hcl-domino-volt)
- [Access the demo environment](#access-the-demo-environment)

# Intro
This guide describes how to build a HCL Domino Volt demo environment using a pre-built Docker image on your desktop computer.

# Install Docker
At first you need to install [Docker Desktop] (https://www.docker.com/products/docker-desktop) for the operating system of your desktop

* [MacOS](https://hub.docker.com/editions/community/docker-ce-desktop-mac/)
* [Windows](https://hub.docker.com/editions/community/docker-ce-desktop-windows)

## Verify if Docker is running
Once the installation is complete, open a command prompt and enter the following command to see if docker was installed successfully on your computer:

```bash
docker --version
```
The result should be something like:
Docker version 19.03.8, build afacb8b

# Download the pre-built HCL Domino Volt Docker image
tbd

# Import an existing image
Open a new terminal / command line window and navigate to the folder where you saved the download.

e.g.: 
* for MacOSX ```bash cd ~/Downloads```
* for Windows ```bash cd %UserProfile%/Downloads```

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
REPOSITORY                                                   TAG                 IMAGE ID            CREATED             SIZE
hclcom/volt         3d40cc94881c        11 hours ago        1.56GB
```

# Host name / FQDN
The HCL Domino Volt server needs a fully qualified host name in order to work correctly. Since your local computer might change its FQDN we will need to create a dummy hostname that can be used later on to run HCL Domino Volt.

Define what fully qualified host name to be used for this demo environment. In this example we will be using "volt.demo.com"

## Edit Hosts file
To redirect all requests to the host name defined earlier, edit the hosts file on your computer using this command:
* MacOSX : ```bash sudo nano /etc/hosts```
* Windows : ```bash notepad C:/Windows/System32/drivers/etc/hosts```
and add the following line:
127.0.0.1   volt.demo.com

## Create a volume
Create a new (empty) volume that will be used as Data directory
```bash
docker volume create domino_volt
```

## Run a new container with HCL Domino Volt.


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
    --name server1 \
    hclcom/volt:1.0.0.5
```

# Access the demo environment

open a web browser of your choice and navigate to 
https://volt.demo.com

