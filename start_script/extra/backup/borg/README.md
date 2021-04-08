
# Domino V12 & Borg Backup 

This directory contains a reference implementation for Domino V12 Backup & Restore using Borg Backup.

Components included:

- Integration shell scripts
- DXL configuration file which can be imported into ``dominobackup.nsf`` prepared to work with the scripts provided
- Example build script from plain CentOS 8 to a ready to go Domino V12 image including Borg Backup leveraging the Domino container script and Podman (Docker supported as well, but not included in CentOS).

The implementation can be used in a standard Linux environment where you install Borg on your own or running Domino inside a container.  

### References

- Domino V12 Backup & Restore  
  https://help.hcltechsw.com/domino/12.0.0/admin/admn_backupandrestore.html

- Borg Backup  
   https://borgbackup.readthedocs.io

- Podman  
  https://podman.io/




## How to start

If you want to natively install on Linux the start script main directory contains an install script ``install_borg``  to install the required files into the standard directories ``/opt/hcl/domino/backup/borg`` .

This directory contains the [install-centos-podman-domino-borg.sh](install-centos-podman-domino-borg.sh) script which can be used to automatically install and build the environment.

This script can be also used as a commented command reference if you want to build it on your own.

Once you built the image you can use the ``domino_container`` script to configure and run your first server.
The ``domino_container`` is part of the NashCom start script and is intended to run and mange Domino on Podman and Docker.

# Working with the domino_container script 

Now that the image is created, you can use the container script to configure and start your container.  
The following is a short reference for the main steps.  
The domino_container script is prepared to be used with Borg Backup.


## 1. Check the status of the image and container

The inspect command provides detailed information about your container.
You can run it even before the container is started for the first time.

```
domino_container inspect 
```

## 2. Check & edit the container configuration 

The container script contains a configuration file in /etc/sysconfig which can be edited.
Those configuration variables define your container including network mode, volumes etc.
There is a default configuration, you can modify for your needs.

Tip: If vi isn't your favorite editor you can define your editor exporting an environment variable in your profile or shell ( Example: ``export EDIT_COMMAND=mcedit`` ).


```
domino_container cfg 
```

## 3. Check container environment 

Each container should also have an environment file (references in config) to define environment variables for your container. This can include Domino V12 One-Touch environment variables.

```
domino_container env 
```


## 4. Start your container 

The following command creates a new container or starts an existing container.

```
domino_container start
```

## 5. Launch a bash script inside the container 

```
domino_container bash 
```

## 6. Init the Borg Backup repository 

```
borg init --encryption=repokey-blake2 /local/borg 
```

## 7. Run the domino console inside the container 

The Domino Docker project leverages the Nash!Com start script inside the container.
You can run all operations you know from a normal Domino on Linux environment inside the container.

```
domino console 
```

## 8. Create Domino V12 backup configuration

Start Domino Backup once to create the configuration database.
The backup application will create a new database from template and terminates to let you review and update the backup configuration.

```
load backup 
```

## 9. Configure Domino Backup Borg

In our case we need to import Domino Borg Backup configuration file ``config.dxl`` included in this directory.

Switch to your Notes client, import the config.dxl (also part of the project) into ``dominobackup.nsf`` 

Important: Disable the default configuration



