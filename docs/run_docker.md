---
layout: default
title: "Run on Docker"
nav_order: 1
description: "Howto run Domino Container Images on Docker"
parent: "Run Image"
has_children: false
---

## How run this image on Docker

When a new container is created from the HCL Domino Container image, it takes [environment variables](reference_environment-vars.md) into account for auto-configuring the Domino server.
Details on how to use those variables can be found [here](reference_environment-vars.md)

The Domino data directory needs to be a persistent volume. On Docker it will be automatically created.
You can also use an existing volume. All volume types your container infrastructure supports can be used.

### Creating a new container from an image manually

Run a new Domino server with the configuration details of your choice.
Make sure to specify the base image name at the very end of this command.

Note: For values containing blanks use quotes around the whole env parameter!

```bash
docker run -it \
     -e SetupAutoConfigure=1 \
     -e SERVERSETUP_SERVER_TYPE=first \
     -e SERVERSETUP_ADMIN_FIRSTNAME=John \
     -e SERVERSETUP_ADMIN_LASTNAME=Doe \
     -e SERVERSETUP_ADMIN_PASSWORD=domino4ever \
     -e SERVERSETUP_ADMIN_IDFILEPATH=admin.id \
     -e SERVERSETUP_ORG_CERTIFIERPASSWORD=domino4ever \
     -e SERVERSETUP_SERVER_DOMAINNAME=DominoDemo \
     -e SERVERSETUP_ORG_ORGNAME=Domino-Demo \
     -e SERVERSETUP_SERVER_NAME=domino-demo-v12 \
     -e SERVERSETUP_NETWORK_HOSTNAME=domino.acme.com \
    -h domino.acme.com \
    -p 80:80 \
    -p 1352:1352 \
    -v dominodata_demo:/local/notesdata \
    --stop-timeout=60 \
    --name domino12 \
    hclcom/domino:latest
```

## Runtime configuration

During ```docker run``` you can setup a volume that mounts property files into `/local/notesdata`

### Stopping the Application Server gracefully

Stopping a Domino server takes longer than the time a Docker server would expect by default (**10 seconds**), the recommended way is to add the parameter `--stop-timeout` already when starting the container.
If the container was started with the parameter ```--stop-timeout=``` then you may stop the container using the following command:

```docker stop <container-name>```

If the container was started without specifying the parameter `--stop-timeout=` then use the following command to stop the container gracefully

```docker stop --time=<timeout> <container-name>```

Example:

```docker stop --time=60 test```
