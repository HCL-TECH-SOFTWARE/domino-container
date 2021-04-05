#!/bin/bash

#
# Domino V12 + Borg Auto Build
# ----------------------------
# Script to install & build a Domino Image: CentOS + Domino V12 + Borg on CentOS 8 with Podman
#


# Update CentOS 
# ------------- 
# This updates your CentOS server to the latest patches, which is always a good starting point 

yum -y update 


# Install Git & Borg Backup 
# ------------------------- 
# Next next commands add the epel packages to the yum repository and install Borg Backup and the Git client used in the next step

yum install -y epel-release 
yum install -y git borgbackup 


# Download Domino Docker Community project 
# ---------------------------------------- 
# The following lines create a local directory, clone the Docker Domino Git repository and switch to the "develop" branch 

mkdir -p /local/github 
cd /local/github 
git clone https://github.com/IBM/domino-docker.git 
cd domino-docker 
git checkout develop 


# Install Domino Container script 
# ------------------------------- 
# The container script is part of the start script, which is included in the Domino Docker project. 
# It is an easy to use script to manage containers with Docker and Podman. 
# The install commands copies all required components automatically. 
# Tip: If you have an earlier version you always can run this command to update the script 

./start_script/install_domino_container 


# Install Podman 
# -------------- 
# The domino container script contains an option to install Podman automatically including the jq tool, which is used to parse JSON data 

domino_container install 


# Configure the Domino container to enable Borg Backup 
# ---------------------------------------------------- 
# This step tells the Domino container script to enable the Borg Backup functionality. 
# Mainly enables the /dev/fuse device in the container and allows to mount it for restore operations 

echo "BORG_BACKUP=yes" >> /etc/sysconfig/domino_container 


# Configure Domino Docker build environment 
# ----------------------------------------- 
# By default the build script looks for the Domino web-kit in the software directory. 
# 
# Depending on your environment you might have hosted the Domino 12 Beta 3 Web Kit on a central server. 
# In this case you can use the DOWNLOAD_FROM to automatically configure the location of the files.
# 
# If not DOWNLOAD_FROM is specified the build script starts a temporary download container used by the build container.
# You can run the script also on a remote machine your DOWNLOAD_FROM on your build server is pointing to.
#
# Script: domino-docker/software./software-repo.sh
# Usage:  software-repo.sh { start | stop | ip | stopremove }
#
# For you convenience uncomment one of the following options

mkdir -p /local/cfg 

# mv /tmp/Domino_12.0_Linux_Beta3_English.tar /local/github/domino-docker/software 
# echo "SOFTWARE=/local/software > /local/cfg/build_config 
# echo "DOWNLOAD_FROM=http://download.acme.loc:7777" > /local/cfg/build_config 


# Build the Domino V12 image including Borg Backup support 
# -------------------------------------------------------- 
# Building the Domino image is a simple one step process, leveraging the Domino silent installer. 
# A build container is started to build the Domino image. 
# The result is a ready to go image including Borg Backup. 
# The install process installs Domino, Borg Backup, related tools and scripts 

./build.sh -borg domino 12.0.0BETA3 latest 



