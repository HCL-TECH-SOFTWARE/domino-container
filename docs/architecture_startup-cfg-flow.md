---
layout: default
title: "Startup & Config Flow"
nav_order: 2
description: "Startup and Configuration Flow"
parent: "Architecture"
has_children: false
---

# Domino Docker Startup and Configuration Flow

This document describes the general setup and update flow used.
The main entry point is called by the container platform and will remain active while the server is running.
It is controlling all setup and update operations if a new server is started or a server is running for the first time with a new/updated image.
The following abstract is mainly intended for understanding the general flow. Please refer to other sections for details about environment variables in detail.

## /entrypoint.sh

Main entry point to run the Domino server.
The logic also takes care of server setup and updates the server without separate parameters specified.
This logic is performed automatically based on the version variables in the container and the image.

This project leverages the Nash!Com Domino on Linux/Unix start script, from which also the `entrypoint-sh` logic is derived.
The start script is not only useful for start/stop operations, but also provides additional functionality like
generating NSDs, managing logs, creating NSDs, accessing the remote console and many more.
Refer to the Nash!Com start script [documentation](https://nashcom.github.io/domino-startscript/) for details.

You can customize the start script configuration either by overwriting `/etc/sysconfig/rc_domino_config`
or passing all not explicitly configured parameters via environment variables
(all variables start with `DOMINO_`. Leveraging the start script offers admins the same functionality they already know from Domino on Linux and AIX.

The following steps are performed by the entry-point script and helper scripts:

- Setup environment (path, umask, user, etc.)

- Check if we have a LOGONNAME else we need to patch `/etc/passwd` via `nuid2pw` (only required for K8s deployments with special user-id requirements)

  Note: Important if specifying a UID or running on a platform that needs a separate user per Pod and doesn't take care about it on it's own (K8s).

- Run `/domino-container/scripts/domino_install_data_copy.sh` (setup & update data directory see below)


- Check if server is configured (notes.ini `ServerSetup=` is empty)

  - if not configured run -> `/domino-container/scripts/domino_prestart.sh`

  - If still not configured start setup via listening mode


- Start domino running the start script `rc_domino_script`


## domino_install_data_copy.sh

This script is intended for first data directory deployment or update

Checks if `/local/notesdata/notes.ini` already exists. if not executes the following logic:

- Creates directories depending on how the container volumes are mounted
  (Directories are recreated if empty and not a mount point)

- Extracts install `/domino-container/install_data_domino.taz` to `/local/notesdata`
  this is the first deployment for a new container.


- Checks if version has been updated and copies new templates etc.
- The check is performed via version files in the data directory and in the container to compare if "image file version = version in the data volume"


## domino_prestart.sh

Automatic configuration in Domino 12 leverages OneTouch Setup.
Earlier versions used a special PDS file automation configuration.
Domino OneTouch Setup is the recommended way since Domino 12 to automatically setup a Domino server.
Older servers will always run into the standard remote configuration mode via `server -listen 1352`.

This script is used for additional operations before a OneTouch Setup is invoked.

- If specified downloads and extracts `$CustomNotesdataZip` into `/local/notesdata`

- Download files and get password variables

- ( e.g. `server.id`, organization password, trial license file etc)


## Default configuration if no OneTouch Setup is specified

If no configuration is found and no OneTouch Setup is specified the server will launch the remote setup listening on port 1352.

The server will be automatically started with `server -listen 1352` as a fall-back.
