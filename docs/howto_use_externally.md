---
layout: default
title: "Export or push image to registries"
nav_order: 6
description: "How to export or push image to registries"
parent: "Howto"
has_children: false
has_toc: false
---

# Introduction

Docker and Podman are both build and run-time platforms, which can be used for test or production to run images.
The image is stored in the local image registry and can be used from there to create a container from the image right away.

To use images outside our local build environment it needs to either exported or pushed to another registry.


## How to export a container image

Exporting container images is for example required to run on your favorite NAS with Intel/AMD x64 based container support.
But you might also want to export container images from one Docker environment to a different container environment if there is no direct way to push an image to a registry.

The container build script provides an easy to use save option, which can also used as part of the build process.


### Container project export options

To save the image as part of the build process used the following option

```
-save=<img>      exports the image after build. e.g. -save=domino-container.tgz
```

To export an image which is already built run the following command.

```
save <img> <my.tgz>   exports the specified image to tgz format
```

Example:

```
save hclcom/domino:latest domino.tgz
```


### Manual export

```
docker save hclcom/domino:latest | gzip > domino.tgz
```


### Importing container images

Importing container images leverages the `load` command.

```
docker load --input Domino_14.5_Container_Image.tgz
```


## How to push container images to a remote registry

To share container images you can push images from a local Docker/Podman environment to  remote registry.
The official Docker registry is one of the most well known and used registries.

**Important:** Because Domino is licensed software images should not be pushed to public registries.

You can also run a private registry for example the [Harbor registry](https://goharbor.io/) which is an enterprise grade free to use registry which can be installed on prem.


### Tagging and pushing images

1. First make sure you have write access to the target registry. You might need to log into the registry.

2. Then tag the image with the remote image name

3. Finally push the image to the remote registry


```
docker tag hclcom/domino:latest registry.example.loc/domino:latest
docker push registry.example.loc/domino:latest
```


### Pulling images from remote

Once you have pushed images, it can be pulled from remote on another machine.

```
docker pull registry.example.loc/domino:latest
```

Or you might just reference the image and the container run-time tries to pull it automatically.


### Leveraging a registry based image on Kubernetes(K8s)

K8s leverage container registries to pull images as well.
Usually you have to create a container pull secret for authentication and specify the container image in your deployment configuration.

