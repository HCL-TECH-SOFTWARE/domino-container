---
layout: default
title: "Container volumes"
nav_order: 6
parent: "Concept & Overview"
description: "Container volumes"
has_children: false
---

Containers provide a read only image of pre-installed Linux and Domino software.
When running a container the writable areas in a container like `/tmp` are lost when you recreate a container.

Therefore containers on Docker/Podman and also [Kubernetes](https://kubernetes.io) (K8s) allow to mount so called volumes into a running container.
This document mainly focuses on [Docker](https://www.docker.com/) and [Podman](https://docs.podman.io). K8s uses a slightly different concept creating [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/).

For detailed information about volumes checkout the [Docker Volumes documentation](https://docs.docker.com/engine/storage/volumes/).

This document describes the basic concept and important information to run Domino inside a container.
Podman and Docker use the same concept. The following information applies to Docker, Podman, [Rancher Desktop](https://rancherdesktop.io/) and similar environments. 

## Docker Volumes vs. Native Volumes

The so called "**Docker Volumes**" are managed by the container run-time for you.
They are specified with a volume mount statement and in case they don't exist the container run-time will create them at first container startup.
Docker volumes are managed using [volume commands](https://docs.docker.com/reference/cli/docker/volume/) to create, list, update and delete volumes.

The container run-time also takes care about setting the right owner.
If you are starting with containers or want to run a test server you might want to start over often (for example for testing), a container run-time managed volume might be the best choice for you.

"**Native volumes**" look very similar from container point of view. But in contrast to a container run-time managed volume, it points to a host directory or disk.
This allows better control and is the recommended way for larger production servers.

When specifying a volume name only (example: `-v domino_local:/local` ) the container-runtime handles the volume as a named volume.
For a full path `-v /local:/local` the container run-time handles the volume mount as a native volume.

## Mapping volumes

In both cases the volume is mapped into the container.
The simple directory mapping ins the `/local` mapping.

For a larger server the container image supports mounting separate volumes for `notesdata`, `translog`, `NIF` and `FT`.

### Examples:

Docker volume for /local

```
-v domino_local:/local
```

This type of configuration should be a good starting point for first Domino container hands on experience.

Native volume for /local/notesdata mapping to the host directory

```
-v /local/notesdata:/local/notesdata
```

## Owner and Permissions for Native Volumes

In contrast to the container volumes, native volumes are mapped enforcing their Linux level security.
A container is a lightweight virtualization environment mapping resources from host to a container.

### Domino containers uses user/group 1000:1000

The Domino container uses Linux user id (`uid:1000`) and group id (`gid:1000`) mapped to user and group `notes:notes`.
User and group are often written in this `uid:gid` notation. `1000:1000` is a recommended convention used for containers.
Running as root is generally avoided and not supported by Domino also for native Linux/UNIX environments.

In a Linux host environment `1000:1000` is the usually the first user and group created when creating your first user on a Linux machine.
Depending on how the machine is setup user and group `1000:1000` might not be mapped to a user or have a different user name and group than `notes:notes` associated with it (in `/etc/passwd`).

The mapping between host and containers is based on ID level not by name.
This means the owner of all mounted native data volumes must be `1000:1000`.

A common practice is to use the same user name on host and container level for `1000:1000`.


### Special considerations for SELinux

[SELinux](https://en.wikipedia.org/wiki/Security-Enhanced_Linux) provides another layer of security, which even prevents `root` executing certain operations if not authorized.
If a Linux host enforces SELinux and the container run-time is configured with a SELinux policy, those policy also affect resources used inside the container.

When specifying a container volume ensure to append the `:Z` label if SELinux is enabled.

For details see [Docker documentation Configure the selinux label](https://docs.docker.com/engine/storage/bind-mounts/#configure-the-selinux-label).

Example:

```
-v /local/notesdata:/local/notesdata:Z
```


## Troubleshooting Native Volumes

### Find out about the user and group mapped to

The first example shows a the 1:1 mapping between host.
In the second example you can see that the user and group `notes:notes` are not mapped to `1000:1000`.

The `id` command is very helpful to find out the mapping. But you can also look directly into `/etc/passwd` and `/etc/group` where the user and group mapping is defined.
Changing the `uid:gid` by hand is not recommended. But the `usermod` and `groupmod` commands could be used to change it.
But if you have a mismatch and want to change it, you should first check with your Linux administration team.
The names don't need to match, but the `uid:gid` has to match.

In the example below `1000:1000` is mapped to `ubuntu:ubuntu`, which is a common setup in some environments.

```
id 1000
uid=1000(notes) gid=1000(notes) groups=1000(notes)
```

```
id 1000
uid=1000(ubuntu) gid=1000(ubuntu) groups=1000(ubuntu),4(adm),27(sudo)
```

```
id notes
uid=1002(notes) gid=1002(notes) groups=1002(notes)
```

### Checking mounted volumes

The `docker inspect container-name` command can be used to dump information about the running container and it's configuration.
In the JSON output data a whole section represents the mount information.
To find out more details and to explain your current configuration for troubleshooting, share the output of the `docker inspect` command.


### Changing owner of container data

The `chown` command to change the owner can take the user and group in number notation.
The following command works independent of the user name and group name just with the IDs.
Just keep in mind the user listed for the directory might not be shown as `notes:notes` depending on the mapping.

```
chown -R 1000:1000 /local
```
