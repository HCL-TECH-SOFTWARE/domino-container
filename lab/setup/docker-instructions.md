# Install a SSH Client

## On Windows use Putty or better MobaXterm

Connect to the server using the private key .ppk specified in the SSH Advanced key settings

## On Linux or OSX use ssh

* Ensure the file is only readable by the user  
* specify root@ to ssh doesn't assume your local user
* specify the private key


```
chmod 400 id_escsa.pem
ssh root@master.domino-lab.net -i id_escsa.pem
```

## Prepare the local environment 

# Install Docker 20.10

This command takes a time and installs the current Docker 20.10 with all dependencies.  
Don't PANIC! No output is generated for a while

```
curl -fsSL https://get.docker.com | bash

```

## Enable and start Docker

```
systemctl enable --now docker
```

* Install Git
* Clone Domino Docker repository

```
yum install -y git

mkdir -p /local/github
cd /local/github
git clone https://github.com/IBM/domino-docker.git

cd domino-docker
git checkout develop

```

## Check Docker Version and installation

* Check version
* Run the hello-world image in your first container

```
docker version

docker run hello-world

```

## Run the CentOS Base image

```
docker run --rm -it centos:latest bash
```

## Create a normal user and group ( notes:notes )

Creates the user with ID 1000 (first free user)

WARNING: Don't specify a password to ensure nobody can try to login.  
We are going to login via sudo or use an authorized_key configuration if needed.


```
adduser notes -U

```

## Upload the Domino image to docker host

The image comes as a compressed tar and needs to be uploaded downloaded from Flexnet.  

For your convenience the HCL Domino Docker image is already uploaded to `/local/software`


```
docker load --input /local/software/Domino_12.0_DockerImage.tgz
```


Reference: https://help.hcltechsw.com/domino/earlyaccess/inst_dock_load_tar_archive.html


Congrats!  
This completes your Docker environment preparation.


# Docker-Compose Examples

The following files are Docker compose examples to run containers with different settings from the YML files provided.

## Install Docker-Compose

```
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

chmod +x /usr/local/bin/docker-compose

```

## Check Docker Compose version

```
 docker-compose version
```

## Switch to the example directory

```
cd /local/github/domino-docker/examples/docker-compose
```

Take look into the example

```
vi docker-compose.yml
```

Tip: instead of vi we have nano and mcedit installed

```
yum install -y mc nano

mcedit docker-compose.yml

```

Tag the image.  
And start the container.

```

docker tag domino-docker:V1200_05142021prod hclcom/domino:latest


docker-compose up

docker-compose up -d

```

# Domino Community Image

Switch back to the main directory

```
 cd /local/github/domino-docker/
```

Copy configuration and edit it.

```
./build.sh cpcfg

./build.sh cfg
```

Configure the remote download location


```
DOWNLOAD_FROM=http://registry.domino-lab.net:7777
```


## Built the image

The build process will use the remote download repository to get the Domino web kit install package(s).  
The install script loads the tar files directly from the remote location.  
Information about the software to download is located in the software.txt file, which is maintained by the product. This includes download filenames and also SHA1 hashes to verify the downloaded software for consistence and security reasons.

```
./build.sh domino 12.0.0
```


