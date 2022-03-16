---
layout: default
title: "Domino Start Script"
nav_order: 3
parent: "Reference"
description: "Domino Start Script"
has_children: false
---

# Domino Start Script for Docker Containers

## Introduction

This project leverages the Nash!Com Domino starts script inside the container to run and maintain the container.

The start script is separate [GitHub project](https://github.com/nashcom/domino-startscript)
with it's own [documentation](https://nashcom.github.io/domino-startscript/).

## How the start script is used

The `entrypoint.sh` script is started when the container is launched.
This script takes care of managing the lifetime of the container and invokes the start script to run the Domino server.

Once the Domino server is started with the start script, you can leverage the `domino` command inside the container to interact with the Domino server.

One very important and popular command is the `domino console` command, providing a live console to a Domino server.

For a complete reference check [Domino Start Script Commands](https://nashcom.github.io/domino-startscript/startscript/commands/)