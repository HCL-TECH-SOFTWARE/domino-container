# Install a SSH Client

## On Windows use Putty or better MobaXterm

Connect to the server using the private key .ppk specified in the SSH Advanced key settings

## On Linux or OSX use ssh

* Ensure the file is only readable by the user  
* specify root@ to ssh doesn't assume your local user
* specify the private key


## Install editor of your choice

Linux by default uses `vi` as the editor of choice

Instead of `vi` you could install  `nano` or  `mcedit`.

```
yum install -y mc nano

mcedit docker-compose.yml

```


```
chmod 400 id_escsa.pem
ssh root@master.domino-lab.net -i id_escsa.pem
```

## Prepare the local environment 

# Install latest Docker version from official Docker repository

This command takes a time and installs the current Docker version  with all dependencies.  
Don't PANIC! No output is generated for a while

```
curl -fsSL https://get.docker.com | bash

```

## Enable and start Docker

```
systemctl enable --now docker
```


## Check Docker Version and installation

* Check version
* Run the hello-world image in your first container

```
docker version

docker run --rm hello-world

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

## Domino Container repository

* Install Git
* Clone Domino Container repository

```
yum install -y git

mkdir -p /local/github
cd /local/github
git clone https://github.com/HCL-TECH-SOFTWARE/domino-container.git

cd domino-container
git checkout develop



# Build the Domino Community Image

Switch to the main directory

```
 cd /local/github/domino-docker/
```

Edit the configuraiton

```
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


### Run a Domino container


```
docker run -d -p 80:80 -p 443:443 -p 1352:1352 --hostname marvel.domino-lab.net --name domino12 --cap-add=SYS_PTRACE -v notesdata:/local/notesdata hclcom/domino:latest
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
docker exec -it domino12 bash
```

Run commands inside the container

```
ps -ef

netstat -ant

exit
```


# Docker-Compose

There is a more convenient way to bring up Docker containers.

`docker-compose` is a very convenient way to configure and manage multiple containers and bring them up as one service.
You need to download it separately from the Docker website. The following command automates the process for you.


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


This example contains a server with a first Domino V12 One Touch configuration.


```
docker-compose up
```

Tip: You can also start the container in back-ground detached with `-d`


```
docker-compose up -d

```


## Stop and disable Docker systemd service


```
systemctl stop docker
systemctl disable docker

```

