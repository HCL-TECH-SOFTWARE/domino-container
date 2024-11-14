---
layout: default
title: "Community image benefits"
nav_order: 5
parent: "Concept & Overview"
description: "Community image benefits vs. HCL pre-build image"
has_children: false
---


The ready to use container image is built by HCL based on the Domino and Traveler web-kits using the same community build script.
But there are a couple of benefits using the open source container image build script on your own.

The build script in the project is easy to use and provides [MHS software download](https://my.hcltechsw.com/) automation and comes with a build menu.

Below are some differences and benefits when building the container image on your own.
A standard vendor build image can't provide the same flexibility and has to focus on the functionality of the product itself.

When running the open source container image you are running the same HCL provided software with the same level of support.
It's just built on your own in your own environment with software packages downloaded from the MHS instead of using the pre-cooked standard image.

Specially container environments require flexibility building and enhancing images.


## Differences and benefits using the community image

- Building the image on your own ensures you have the latest Redhat UBI image 9.x version included. HCL only updates the image at release time.

- The container image supports Domino add-on packages like the Domino Leap, the REST API and the language pack.

- It allows to install the latest version of all add-on products of HCL Verse, Nomad Server, Traveler, REST API, Domino Leap as soon they are available.

- You can build an all in one image or separate images for different server types.

- The HCL container image only supports the English locale. The community image allows to build with any locale support and adds your build machines locale as the default.

- The community image comes with full timezone support. The HCL Container image is intended to run in UTC locale.

- A shipping container image can only include the bare minimum software needed to run the application. To install additional software you would need to create your own container build environment and build a derived image.

- The community project supports to define your own add-on packages, which can be installed during the build process.

- By default the community image is built on the latest Redhat UBI 9.x minimum only selecting the packages needed for Domino and adds a couple of additional useful packages.

- The HCL image is built on the bigger Redhat UBI 9.1 standard image. See details in Redhat blog post [Introducing the Red Hat Universal Base Image ](https://www.redhat.com/en/blog/introducing-red-hat-universal-base-image).

- The community image also supports to build on other Domino supported base images. This allows full flexibility and also helps you on software testing if you want to run Domino on a different Linux flavor. See [Supported base images](https://opensource.hcltechsw.com/domino-container/concept_environments/#supported-base-images) for details.

- If you are a C-API developer you can create a build container which allows you to build for different Domino versions using different versions of the C-API SDK. When selecting the C-API option the container provides a ready to use build environment.

- In case you need additional Linux packages, the container build script allows to specify those packages when building the image.
