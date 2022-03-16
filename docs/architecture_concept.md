---
layout: default
title: "Conceptual details"
nav_order: 3
description: "Conceptual details"
parent: "Architecture"
has_children: false
---

# Conceptual details

## Installation-Time

- When the image is build, all install data is contained in the installation image.
- All software installers (web-kits) write to the `/local/notesdata` which is part of the image.

All installers (FP, HF, add-on installer e.g. Traveler) can create and update files.

Those files are stored in compressed tar file, to be expanded on first setup or update.

## Run-Time - Create notesdata

Containers are designed to

- have static data in the image
- have changing data in separate data [volumes](https://docs.docker.com/storage/volumes/) which are assigned at run-time.


When a new volume is assigned, existing data in the image where the volume is mounted, is usually copied to the volume.
This ensures that install data like templates, iNotes directory or Traveler directory are available on the `/local/notesdata` volume at first container start.

This works great until a server is updated. A new image will start installation from scratch and all updated install data will be again up to date in the image.
But when you create a new container for updating your server instance, the `/local/notesdata` volume already contains data and will not be updated!

## Updating Install Data

This makes updating a server more complex because even a FP/IF/HF could bring update templates or more often a new iNotes/forms update.

The `/entrypoint.sh` script takes care of those updates automatically at next start-up using `/domino-container/domino_install_data_copy.sh` script.
The logic checks which files have been changed and updates this files by copying them from the image to the data volume.

For Domino FP/IF/HF updates the binary directory contains a directory `opt/hcl/domino/notes/latest/linux/data1_bck` with updated install-data for each version/FP/IF/HF.

During install the current installed version is written to two separate version status files 
in `/domino-container` and `/local/notesdata` (e.g. `/domino-container/domino_fp.txt` and `/local/notesdata/domio_fp.txt` ).
At first install those files are equal. But if a server is updated and the data volume cannot be changed at install time.
The update routine ensures that FP updates are applied before HF updates (there are separate files for FPs, HFs and for add-on software).

A similar logic is used for add-on applications like Traveler.
For Traveler the `/local/notesdata/traveler directory` is stored in a tar during install and stored in the container image.
If the versions don't match at start-up, the data copy script will extract the tar into the server's data directory, before launching the server.  
After updating the data the version file in the notesdata volume is updated to reflect the updates data.  
This ensures install data patches will update the data directory of already deployed data volumes.

All updates are logged into `/tmp/domino-container/data_update.log`.
