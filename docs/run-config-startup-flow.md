
# Domino Docker Startup and Configuration Flow

This document describes the general setup and update flow used.
The main entry point is called by the container platform and will remain active while the server is running.
It is controlling all setup and update operations if a new server is started or a server is running for the first time with a new/updated image.
The following abstract is mainly intended for understanding the general flow. Please refer to other sections for details about environment variables in detail.


`domino_docker_entry.sh` calls the following two additional scripts, which are also described here.
* `domino_install_data_copy.sh`
* `docker_prestart.sh`



## /domino_docker_entry.sh


Main entry point to run the Domino server.
The logic also takes care of server setup and updates the server without separate parameters specified.
This logic is performed automatically based on the version variables in the container and the image.


This project leverages the well know Nash!Com Domino on Linux/Unix start script, from which also the main entry-point logic is derived. The start script is not only useful for start/stop operations, but also provides additional functionality like generating NSDs, managing logs, creating NSDs, accessing the remote console and many more. Refer to the start script documentation for details.

You can customize the start script configuration either by overwriting `/etc/sysconfig/rc_domino_config` or passing all not explicitly configured parameters via environment variables (all variables start with `DOMINO_`. Leveraging the start script offers admins the same functionality they already know from Domino on Linux and AIX.

The following steps are performed by the entry-point script and helper scripts:

- Setup environment (path, umask, user, etc.)

- Check if we have a LOGONNAME else we need to patch `/etc/passwd` via `nuid2pw`

  Note: Important if specifying a UID or running on a platform that needs a separate user per Pod and doesn't take care about it on it's own (K8s).


- Run `/domino-docker/scripts/domino_install_data_copy.sh` (setup & update data directory see below)



- Check if server is configured (notes.ini `ServerSetup=` is empty)

  - if not configured run -> `/domino-docker/scripts/docker_prestart.sh`

  - If still not configured start setup via listening mode


- Start domino running the start script `rc_domino_script`


## domino_install_data_copy.sh

This script is intended for first data directory deployment or update

Checks if `/local/notesdata/notes.ini` already exists. if not executes the following logic:


- Creates directories:

    - /local/`notesdata`
    - /local/`translog`
    - /local/`daos`
    - /local/`nif`
    - /local/`ft`

    (Directories are recreated if empty and not a mount point)


- extracts install `/domino-docker/install_data_domino.taz` to `/local/notesdata`
  this is the first deployment for a new container.


- Checks if version has been updated and copies new templates etc.
    - The check is performed via version files in the data directory and in the container to compare if 
"image file version = version in the data volume"



## docker_prestart.sh


This script is intended to setup the Domino server.
The operations are stopped if no configuration is specified (no `ServerName` variable specified)


- If specified downloads and extracts `$CustomNotesdataZip` into `/local/notesdata`

- If specified download `$GitSetupRepo` to `/local/git`

  - `/local/git` can be used by setup routine. `/local/git/notesdata` is automatically copied to `/local/notesdata`

  - Run `$GitSetupScript` if specified


- Download files and get password variables
  - ( e.g. `server.id`, organization password, trial license file etc)


- Configure setup.pds file using configuration variables (environment vars, parameters set by passwords downloaded)


- Run `server -silent SetupProfile.pds` to setup Domino via standard silent mode.



- If no `keyfile.kyr` exists, create new self singed kyrfile with a locally created CA for configured hostname in container


- Cleanup downloaded files and environment

