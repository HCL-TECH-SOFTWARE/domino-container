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
git clone https://github.com/HCL-TECH-SOFTWARE/domino-container.git

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
Already prepared for you in the lab environment  

`WARNING: Don't specify a password to ensure nobody can try to login.`
We are going to login via sudo or use an authorized_key configuration if needed.


```
adduser notes -U

```

# HCL Domino Docker Image

The Domino Docker image is a ready to use standard image available on Flexnet for download.  
Your lab environment already has it downloaded to `/local/software`.


## Upload the Domino image to docker host

The image comes as a compressed tar and needs to be uploaded downloaded from Flexnet.  

For your convenience the HCL Domino Docker image is already uploaded to `/local/software`


```
docker load --input /local/software/Domino_12.0_DockerImage.tgz
```

Reference: https://help.hcltechsw.com/domino/12.0.0/admin/inst_dock_load_tar_archive.html


Congrats!  
This completes your Docker environment preparation.


## Run the Docker image

### Run Domino Docker in setup mode

```
docker run -it -p 8585:8585 --hostname marvel.domino-lab.net --name domino12_setup --cap-add=SYS_PTRACE --rm -v notesdata:/local/notesdata domino-docker:V1200_05142021prod --setup
```

Now open another window and check for a new volume automatically created for your server

```
docker volume ls
```

Also check the running container

```
docker ps 
```

You can also jump into the container from another window


```
docker exec -it domino12_setup bash 
```

Run commands inside the container

```
ps -ef

netstat -ant

exit
```


### Start the configured server


Now that the server is configured it can be started in background


```
docker run -d -p 80:80 -p 443:443 -p 1352:1352 --hostname marvel.domino-lab.net --name domino12 --cap-add=SYS_PTRACE -v notesdata:/local/notesdata domino-docker:V1200_05142021prod
```

But do we really want to to specify all the parameters manually on command line?  
There is a more convenient way to bring up Docker containers.


# Docker-Compose

`docker-compose` is a very convenient way to configure and manage multiple containers and bring them up as one service.  
You need to download it separately from the Docker website. The following command automates the process for you.


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
cat docker-compose.yml

vi docker-compose.yml

```

Tip: instead of `vi` we have `nano` and `mcedit` installed

```
yum install -y mc nano

mcedit docker-compose.yml

```

This example contains a server with a first Domino V12 One Touch configuration.


## Tag the image and start the container  


```
docker tag domino-docker:V1200_05142021prod hclcom/domino:latest

docker-compose up
```

Tip: You can also start the container in back-ground detached with `-d`


```
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


Configure the software location. The standard location would be inside the Git repository directory. But the software is downloaded to `local/software`

```
SOFTWARE_DIR=/local/software
```


## Built the image

The install script starts a temporary NGINX container and downloads the software directly into the build-container.    
Information about the software to download is located in the software.txt file, which is maintained by the product. This includes download filenames and also SHA256 hashes to verify the downloaded software for consistence and security reasons.


```
./build.sh domino
```


## Stop and disable Docker systemd service


```
systemctl stop docker


systemctl disable docker

```

