---
layout: default
title: "Run via dominoctl"
nav_order: 2
description: "Howto run a container via dominoctl"
parent: "Run Image"
has_children: false
---

# About dominoctl

[Dominoctl](https://nashcom.github.io/domino-startscript/dominoctl/) is not part of the Domino Container project.
It is part of the Nash!Com start script project, which is used for the HCL Domino container project.

Similar to the Domino Start Script the **dominoctl** is intended to simplify configuration, start, stop and all other container operations.
If you are running a Domino container on Docker or Podman this script is a very good choice.
Please refer to the Nash!Com start script project for detailed information.

## How to configure and start a container

First install **dominoctl** as documented [here]([Dominoctl](https://nashcom.github.io/domino-startscript/dominoctl/)).

Once installed all container operations can be performed using **dominoctl**.

### Configure the container

The default container configuration should work for most first setups.
But opening the configuration might help understanding the settings.

By default the configuration scripts use `vi`. 
The editor can be changed in the configuration via `EDIT_COMMAND` variable or exporting `export EDIT_COMMAND=nano` for example.

```
dominoctl cfg
```

### Configure the Domino server

The Container image supports Domino OTS in multiple ways.
You can mount a OTS JSON file, download the file from remote.
The file can be a so called OTS template with placeholders for OTS setup variables.

**dominoctl** supports to interactively replace the variables.
Each variable is prompted with a default value.

```
dominoctl setup
```

To edit the generated OTS JSON file, invoke the command again.


### Start the Domino server

Now the server can be started using the start command.
The command issues a `docker run` command to create and start a new container and waits for the container to be started to issue a`docker cp` command to inject the OTS JSON file.
The container image is prepared to wait a couple of seconds for OTS files to be available before switching to listening mode for remote setup if no configuration is provided.


```
dominoctl start
```

### Jump into the running container

```
dominoctl bash
```

