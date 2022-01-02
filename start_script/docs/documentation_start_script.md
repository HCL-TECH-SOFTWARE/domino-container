
# Introduction

The Domino cross platform start/stop and diagnostic script has been written
to unify and simplify running Domino on Linux and UNIX. The start script
is designed to be "one-stop shopping" for all kind of operations done on the
Linux/UNIX prompt. The script can start and stop the server, provides an interactive
console and run NSD in different flavors.
It ensures that the environment is always setup correct and supports multiple partitions.

This script is designed to run with a dedicated user for each partition.
Out of the box the script is configured to use the "notes" user/group and the standard
directories for binaries (/opt/hcl/domino) and the data directory (/local/notesdata).
You should setup all settings in the script configuration file.

Note: Linux systemd (CentOS 7 RHEL 7/ SLES 12) requires root permissions for start/stop.
One way to accomplish this is to grant "sudo" permissions for the "rc_domino" script.
See the "Enable Startup with sudo" section for details.

# Simple Configuration

If you configure your Domino environment with the standard path names
and users names, you can use this standard configuration and install script.

The default configuration is

```
User : notes
Group: notes
Binary Directory: /opt/hcl/domino
Data Directory  : /local/notesdata
```

The standard configuration is highly recommended. This will make your life easier for installing the server.
You can change the data directory in the rc_domino_config file.
But the binary location and the notes:notes user and group should stay the same.

I would stay with the standard /local/notesdata. This could be a spearate mount-point.
And you could also use the following directory structure for the other directories.

```
/local/translog
/local/nif
/local/daos
```

Each of them could be a separate file-system/disk.

If you have the standard environemnt you just have to untar the start-script files and start the install_script.
It copies all the scripts and configuration and after installation you can use the "domino" command for everything.
The script is pre-configured and will work for older versions with init.d and also with the newer systemd.

- The first command untars the files
- The install_scripts writes all required files into the right locations with the right owner and permissions.
- The next command enables the service (works for init.d and systemd)
- And finally the server is started

```
tar -xvf start_script.tar
./install_script
```

```
domino service on
domino start
```

Other useful commands

```
domino status
domino statusd
domino console
```

All details about configuration and commands are documented below.

# Enable Startup with sudo

If you never looked into sudo, here is a simple configuration that allow you to run the start script with root permissions.
Basically this allows the notes user to run the /etc/init.d/rc_domino as root.
This avoids switching to the root user.

visudo

Add the following lines to the sudoer file

```
%notes  ALL= NOPASSWD: /etc/init.d/rc_domino *, /usr/bin/domino *
```

This allows you to to run the start script in the following way from your notes user.

```
sudo /etc/init.d/rc_domino ..
```

# Quick manual Configuration

## 1. Copy Script Files

- Copy the script rc_domino_script into your Nash!Com start script directory /opt/nashcom/startscript
- Copy rc_domino into /etc/init.d

- For systemd copy the domino.service file to /etc/systemd/system  
  And ensure that rc_domino contains the right location for the service file  
  configured in the top section of your rc_domino file -> `DOMINO_SYSTEMD_NAME=domino.service`.

## 2. Ensure the script files are executable by the notes user

Example:

 ```
chmod 755 /opt/nashcom/startscript/rc_domino_script
chmod 755 /etc/init.d/rc_domino
 ```

## 3. Check Configuration

Ensure that your UNIX/Linux user name matches the one in the configuration part
of the Domino server. Default is  `notes`.

For systemd ensure the configuration of the domino.service file is matching and
specially if it contains the right user name and path to the rc_domino_script.
And also the right path for the "PIDFile"
(See "Special platform considerations --> systemd (CentOS 7 RHEL 7/ SLES 12 or higher)"  for details).

# One-touch Domino setup support

Quick mode:

Use the `domino setup` command to setup variables for a first server before you start your server.

Domino V12 introduced a new automated setup/configuration option.
One-touch Domino setup is a cross platform way to setup your Domino server.

You can either use

- environment variables
- a JSON file

Environment variable based setup allows you to set the most important server configuration options.
The JSON based setup provides many more options including creating databases, documents and modifying the server document.

The start script supports both methods and comes with default and sample configurations you can modify for your needs.

The new OneTouchSetup directory contains configuration templates for first server and additional server setups.

The new functionality provides a easy to use new `setup` command, which automatically creates a sample configuration for your.

When you use the install script, all the files are automatically copied to the /opt/nashcom/startscript/OneTouchSetup directory.

A new command `setup` allows you to configure the One-touch setup Domino configuration.

The following setup command options are available:

```
setup            edits an existing One Touch config file or creates a 1st server ENV file
setup env 1      creates and edits a first server ENV file
setup env 2      creates and edits an additional server ENV file
setup json 1     creates and edits a first server JSON file
setup json 2     creates and edits an additional server JSON file
```

```
setup log        lists the One Touch setup log file
setup log edit   edits the One Touch setup log file
```

The `setup` command creates the following files:

```
local/notesdata/DominoAutoConfig.json
local/notesdata/DominoAutoConfig.env
```

If present during first server start, the start script leverages One-touch Domino setup.
If both files are present the JSON configuration is preferred.

Refer to the Domino V12 documentation for details:  
https://help.hcltechsw.com/domino/12.0.0/admin/wn_one-touch_domino_setup.html

## Setup files deleted after configuration

After setup is executed the ENV file is automatically removed, because it can contain sensitive information.
Specially for testing ensure to copy the files before starting your server.

For timing reasons the JSON file is not deleted by the start script.
But on successful setup One-touch Domino setup deletes the JSON file as well.

# Special Note for systemd

For systemd the start/stop operations are executed using the systemd service "domino.service".
The rc_domino script itself can be still used as a central entry point for all operations.
This includes start/stop which will calls the systemd commands in the background.
When using systemd you can re-locate the rc_domino script into any other directory.
It but it is perfectly OK to keep it in the /etc/init.d directory for consistence.

In addition take care that systemd does not use .profile and .bash_profile!
Environment variables are specified in the systemd service in the following way:

```
Environment=LANG=de_DE.UTF-8
```

4.) Ensure to setup at least the following script variables per Domino partition.

- `LOTUS`
  Domino binary directory
  default: `/opt/hcl/domino`

- DOMINO_DATA_PATH
  Domino data directory
  default: /local/notesdata

  Setup the script in the configuration file per Domino partition.
  The default location is in `/etc/sysconfig/rc_domino_config`

  Having the configuration separated from the script logic allows you to install new script
  versions without changing the code in the script itself.
  All configuration can be found in the `rc_domino_config` file.
  It contains all configuration parameters either with a default value or commented out waiting to be enabled.

  For a single partition the defaults in the start script should work.
  This is the current recommended configuration. You should not modify the script itself.
  For AIX you may have to create a directory for the config file.

# Special platform considerations systemd

Linux introdued systemd in the following version and is since then the standard used instead of the older init.d functionality

- CentOS 7 RHEL 7
- SLES 12 or higher

`etc/systemd/system/domino.service` contains the configuration for the systemd service.

The following parameters should be reviewed and might need to be configured.
Once you have configured the service you can enable and disable it with systemctl.

```
systemctl enable domino.service
systemctl disable domino.service
```

To check the status use `systemctl status domino.service`.

Description of parameters used in `domino.service`.

```
User=notes
```

This is the Linux user name that your partition runs with.

```
LimitNOFILE=65535
```

With systemd the security limit configuration is not used anymore and the limits
are enforced by systemd. Starting with Domino 9 you should configure at least 65535 files.
Files means file handles and also TCP/IP sockets!

```
LimitNPROC=8000
```

With systemd the security limit configuration is not used anymore and the limits
are enforced by systemd. Even Domino uses pthreads you should ensure that you have
sufficient processes configured because the limit does not specify the number of
processes but the number of threads that the "notes" user is allowed to use!

```
TasksMax=8000
```

The version of systemd shipped in SLES 12 SP2 uses the PIDs cgroup controller.
This provides some per-service fork() bomb protection, leading to a safer system.
It controls the number of threads/processes a user can use.
To control the default TasksMax= setting for services and scopes running on the system,
use the `system.conf` setting `DefaultTasksMax=`.

This setting defaults to 512, which means services that are not explicitly configured otherwise
will only be able to create 512 processes or threads at maximum.
The domino.service sets this value for the service to 8000 explicitly.
But you could also change the system wide setting.
CentOS / RHEL versions also support TaskMax and the setting is required as well.

Note: If you are running an older version TaskMax might not be supported and you have to remove the line from the domino.service

```
#Environment=LANG=en_US.UTF-8
#Environment=LANG=de_DE.UTF-8
```

You can specify environment variables in the systemd service file.
Depending on your configuration you might want to set the LANG variable.
But in normal cases it should be fine to set it in the profile.

```
PIDFile=/local/notesdata/domino.pid
```

This PIDFile has to match the configured DOMINO_PID_FILE ins the start script.
By default the name is "domino.pid" in your data directory.
You can change the location if you set the configuration variable "DOMINO_PID_FILE"
to override the default configuration if really needed.

```
ExecStart=/opt/nashcom/startscript/rc_domino_script start
ExecStop=/opt/nashcom/startscript/rc_domino_script stop
```

Those two lines need to match the location of the main domino script including the start/stop command parameter.

`TimeoutSec=100`


Time-out value for starting the service

`TimeoutStopSec=300`

Time-out value for stopping the service

# Special platform considerations SLES11, RHEL 6 and below (legacy configuration)

The script (rc_domino) contains the name of the service. If you modify the name of
the script you need to change the "Provides:"-line in the main rc-script
Example:

```
# Provides: rc_domino"
```

On SLES you can use the insserv command or run-level editor in YaST

Example:

```
insserv /etc/init.d/rc_domino
```

To verify that your service is correctly added to the rc-levels use the following command

```
find /etc/init.d/ -name "*domino*"
```

Sample Output:

```
  /etc/init.d/rc3.d/K13rc_domino
  /etc/init.d/rc3.d/S09rc_domino
  /etc/init.d/rc5.d/K13rc_domino
  /etc/init.d/rc5.d/S09rc_domino
  /etc/init.d/rc_domino
```

# Special platform considerations AIX

For AIX change first line of the scripts from `#!/bin/sh` to `#!/bin/ksh`

AIX uses `ksh` instead of `sh/bash`.
The implementation of the shells differs in some ways on different platforms.
Make sure you change this line in `rc_domino` and `rc_domino_script`

On AIX you can use the mkitab to include rc_domino in the right run-level
Example:

```
mkitab domino:2:once:"/etc/rc_domino start
```

# Domino Docker Support

This start script supports Domino on Docker.
But the configuration differs from classical way to run the start script.
The install_script and also the start script detects a Docker configuration.
And will work according the the requirements of a Docker environment.

For Domino on Docker a separate entry point is needed to start the server.
Images derived from CentOS 7.4 and higher are supported.

A Docker image doesn't have a full systemd implementation and start/stop cannot be implemented leveraging systemd.
Therefore the start script comes with a separate Docker entry point script "domino_docker_entrypoint.sh"
The script can be used in your Docker build script and you can include the start script into your own Docker images.

The entry point script takes care of start and stop of the server by invoking the rc_domino_start script directly.
You can still use rc_domino (or the new alias domino) to interact with your server once you started a shell inside the container.

In addition the script also supports remote setup of a Domino server.  
If no names.nsf is located in the data directory it puts the server into listen mode for port 1352 for remote server setup.

You an add your own configuration script `/docker_prestart.sh` to change the way the server is configured.  
The script is started before this standard operations.
If the file `/docker_prestart.sh` is present in the container and the server is not yet setup, the script is executed first.

The output log of the Domino server is still written to the notes.log files.
And the only output you see in from the entry point script are the start and stop operations.

If you want to interact with the logs or use the monitor command, you can use a shell inside the container.
Using a shell you can use all existing Start Script commands.
But you should stop the Domino server by stopping the container and not use the 'stop' command provided by the start script.

## !! Important information !!

Docker has a very short default shutdown timeout!
When you stop your container Docker will send a `SIGTERM` to the entry point.
After waiting for 10 seconds Docker will send a `SIGKILL` signal to the entry point!!

This would cause an unclean Domino Server shutdown!

The entrypoint script is designed to catch the signals, but the server needs time to shutdown!

So you should stop your Domino Docker containers always specifying the `--time` parameter to increase the shutdown grace period.

Example:

```
docker stop --time=60 domino
```

Will wait for **60 seconds** until the container is killed.

## Additonal Docker Start Script Configuration

There is a special configuration option for start script parameters for Docker.  
Because the `rc_domino_config` file is read-only, on Docker you can specify an additional config file
in your data directory which is usually configured to use a persistent volume which isn't part of the container.  
This allows you to set new parameters or override parameters from the default config file.

# Components of the Script

## rc_domino

  This shell script has two main purposes

- Have a basic entry point per instance to include it in "rc" run-level
  scripts for automatic startup of the Domino partition
  You need one script per Domino partition or a symbolic link
  with a unique name per Domino partition.

- Switch to the right user and call the `rc_domino_script`.

  Notes:

- If the user does not change or you invoke it as root you will not
  be prompted for a password. Else the shell prompts for the Notes
  UNIX user password.

- The script contains the location of the `rc_domino_script`.
  You have to specify the location in `DOMINO_START_SCRIPT`
  (default is /opt/nashcom/startscript/rc_domino_script).
  It is not recommended to change this default location because of systemd configuration.

## rc_domino_script

  This shell script contains

- Implementation of the shell logic and helper functions.
- General configuration of the script.
- The configuration per Domino server specified by notes Linux/UNIX user.
  You have to add more configurations depending on your Domino partition setup.
  This is now optional and we recommend using the rc_domino_config_xxx files

## rc_domino_config / rc_domino_config_xxx

- This file is located by default in /etc/sysconfig and should be used as an external configuration (outside the script itself).

- By default the script searches for a name in the format rc_domino_config_xxx (e.g. for the `notes` user rc_domino_config_notes)
where xxx is the UNIX user name of the Domino server.

- The default name of the script shipped is rc_domino_config but you can add also a specific configuration file for your partition.

The config files are used in the following order to allow flexible configurations:

- First the default config-file is loaded if exists (by default: `/etc/sysconfig/rc_domino_config`)
- In the next step the server specific config-file (by default: `/etc/sysconfig/rc_domino_config_notes` ) is included.
- The server specific config file can add or overwrite configuration parameters.

This allows very flexible configuration. You can specify global parameters in the default config file and have specific config files per Domino partition.  
So you can now use both config files in combination or just one of them.

Note: On AIX this directory is not standard but you can create it or if really needed change the location the script.

Usually there is one configuration file per Domino partition and the last part of the name
determines the partition it is used for.

Examples:

```
rc_domino_config_notes
rc_domino_config_notes1
rc_domino_config_notes2
...
```

If this file exists for a partition those parameters are used for server start script configuration.

This way you can completely separate configuration and script logic.  
You could give even write permissions to Domino admins to allow them to change the start-up script configuration.

This file only needs to be readable in contrast to `rc_domino` and `rc_domino_script` which need to be executable.

## systemd service file: domino.service

Starting with CentOS 7 RHEL 7 and SLES 12 systemd is used to start/stop services.  
The domino.service file contains the configuration for the service.  
The variables used (Linux user name and script location) have to match your configuration.  
Configuration for the domino.service file is described in the previous section.  
Each Domino partition needs a separate service file.  
See configuration details in section "Domino Start Script systemd Support"

## domino_docker_entrypoint.sh Docker entry point script

This script can be used as the standard entry point for your Domino Docker container.  
It takes care of your Domino Server start/stop operations.  
See details in the Docker section.

# Additional Options

You can disable starting the Domino server temporary by creating a file in the data-directory named `domino_disabled`.  
If the file exists when the start script is called, the Domino server is not started.

# Differences between Platforms

The two scripts use the Korn-Shell `/bin/ksh` on AIX.  
On Linux the script needs uses `/bin/sh` / `/bin/bash`.

Edit the first line of the script according to your platform

```
Linux: "#!/bin/sh"
AIX: "#!/bin/ksh"
```

# Tuning your OS-level Environment for Domino

Tuning your OS-platform is pretty much depending the flavor and version of UNIX/Linux you are running.  
You have to tune the security settings for your Domino UNIX user, change system kernel parameters and other system parameters.

The start script queries the environment of the UNIX notes user and the basic information like ulimit output when the server is started.

The script only sets up the tuning parameters specified in the UNIX user environment. There is a section per platform to specify OS environment tuning parameters.

## Linux

You have to increase the number of open files that the server can open.  
Those file handles are required for files/databases and also for TCP/IP sockets.  
The default is too low and you have to increase the limits.

Note: No change is required if you system already has higher default values.

Using the ulimit command is not a solution. Settings the security limits via root before switching to the notes user executing the start script via "su -" does not work any more.  
And it would also not be the recommended way.

su leverages the pam_limits.so module to set the security limits when the user switches.

So you have to increase the limits by modifying `/etc/security/limits.conf`

You should add a statement like this to `/etc/security/limits.conf`

```
* soft nofile 65535
* hard nofile 65535
```

# systemd ### Changes (CentOS 7 RHEL 7 /SLES 12)

This configuration is not needed to start servers with systemd.  
systemd does set the limits explicitly when starting the Domino server.  
The number of open files is the only setting that needs to be changed via `LimitNOFILE=65535` in the domino.service file.

```
export NOTES_SHARED_DPOOLSIZE=20971520
```

Specifies a larger Shared DPOOL size to ensure proper memory utilization.

Detailed tuning is not part of this documentation. If you need platform specify tuning feel free to contact
domino_unix@nashcom.de

## Implementation Details

The main reason for having two scripts is the need to switch to a different user. Only outside the script the user can be changed using the 'su' command and starting another script. On some platforms like Linux you have to ensure that su does change the limits of the current user by adding the pam limits module in the su configuration.

In the first implementation of the script the configuration per user was specified in the first part of the script and passed by parameter to the main script. This approach was quite limited because every additional parameter
needed to be specified separately at the right position in the argument list.

Inheriting the environment variables was not possible because the su command does discard all variables when specifying the "-" option which is needed to setup the environment for the new user.  
Therefore the beginning of the main script contains configuration parameters for each Domino partition specified by UNIX user name for each partition.

## Domino Start Script systemd Support

Beginning with CentOS 7 RHEL 7 and SLES 12 Linux is using the new "systemd"  
(http://en.wikipedia.org/wiki/Systemd) for starting services daemons.

All other Linux platforms are also moving to systemd.  
rc scripts are still working to some extent. but it makes sense to switch to the systemd service model.  
Most of the functionality in the Domino start script will remain the same and you will also continue to use the same files and configuration. But the start/stop operations are done by a `domino.service`.

The start script will continue to have a central entry point per partition `rc_domino` but that script is not used by the "rc environment" any more. You can place the file in any location and it is not leveraged by systemd.

systemd uses a new `domino.service` per Domino partition.

The service file is directly invoke the main script logic `rc_domino_script` after switching to the right user and setting the right resources like number of open files (before this was done with "su - notes" and the limits configuration of the corresponding pam module).

It is still recommended to specify the same security limits also via `/etc/security/limits.conf` in case a server is started manually or other processes are started outside the server (e.g. backup).

Starting and Stopping the Domino server can be done either by the rc_domino script which will invoke the right service calls in the background. Or directly using the systemd commands.

### Starting, Stopping and getting the Status

```
systemctl start domino.service
systemctl stop domino.service
systemctl status domino.service
```

### Enabling and Disabling the Service

```
systemctl enable domino.service
systemctl disable domino.service
```

The service file itself is be located in `/etc/systemd/system`.

You have to install a service file per Domino partition. When you copy the file you have to make sure to have the right settings.

- ExecStart/ExecStop needs the right location for the rc_domino_script (still usually the Domino program directory)
- Set the right user account name for your Domino server (usually "notes").

The following example is what will ship with the start script and which needs to be copied to `/etc/systemd/system` before it can be enabled or started.

### Systemd service file shipped with the start script

```
[Unit]
Description=HCL Domino Server
After=syslog.target network.target

[Service]
Type=forking
User=notes
LimitNOFILE=65535
PIDFile=/local/notesdata/domino.pid
ExecStart=/opt/nashcom/startscript/rc_domino_script start
ExecStop=/opt/nashcom/startscript/rc_domino_script stop
TimeoutSec=100
TimeoutStopSec=300
KillMode=none
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
```

The rc_domino script can be still used for all commands.  
This includes starting and stopping Domino as a service (only "restart live" option is not implemented).  
You can continue to have rc_domino with the same or different names in the `/etc/init.d` directory or put it into any other location. It remains the central entry point for all operations.

But the domino.service can also be started and stopped using "systemctl". rc_domino uses the configured name of the domino.service (in the header section of `rc_domino script`).

systemd operations need root permissions. So it would be best to either start rc_domino for start/stop operations with root.
One way to accomplish using root permissions is to allow sudo for the `rc_domino script`.

The configuration in `/etc/sysconfig/rc_domino_config` (or whatever your user name is) will remain the same and will still be read by `rc_domino_script`.

The only difference is that the `rc_domino_script` is invoked by the systemd service instead of the `rc_domino` script for start/stop operations.

When invoking start/stop live operations a combination of systemd commands and the existing `rc_domino_script` logic is used.

## systemd status command

The output from the systemd status command provides much more information than just if the service is started.

Therefore when using systemd the rc_domino script has a new command to show the systemd status output.
The new command is `statusd`

## How do you install the script with systemd?

- Copy `rc_domino`, `rc_domino_script` and `rc_domino_config` to the right locations
- Copy domino.service to `/etc/systemd/system`.
- Make the ### Changes according to your environment
- Enable the service via `systemctl enable domino.service` and have it started/stopped automatically
  or start/stop it either via systemd command or via `rc_domino` script commands.
- rc_domino script contains the name of the systemd service.
  If you change the name or have multiple partitions you need to change the names accordingly

## How does it work?

- Machine startup  
When the machine is started systemd will automatically start the domino.service.  
The `domino.service` invokes the `rc_domino_script` (main script logic).  
`rc_domino_script` will read `rc_domino_config`.

- Start/Stop via rc_domino
 When `rc_domino start` is invoked the script will invoke the service via systemctl start/stop domino.service.

- Other script operations
Other operations like "monitor" will continue unchanged and invoke the `rc_domino_script`.

# Known Issues

## Hex Messages instead of Log Messages

In some cases when you start the Domino server with my start script you see hex codes instead of log message.

The output looks similar to this instead of real log messages.

```
01.03.2015 12:42:00 07:92: 0A:0A
01.03.2015 12:42:00 03:51: 07:92
```

Here is the background about what happens:

Domino uses string resources for error messages on Windows which are linked into the binary.  
On Linux/UNIX there are normally no string resources and Domino uses the res files created on Windows in combination which code that reads those string resources for error output.

In theory there could be separate version of res files for each language and there used to be res files which have been language dependent.

So there is code in place in Domino to check for the locale and find the right language for error message.

But there are no localized resources for the error codes any more since Domino ships as English version with localized language packs (not containing res files any more).

This means there is only one set of res Files in English containing all the error text for the core code (a file called strings.res) and one per server tasks using string resources.

So string resources contain all the error texts and if Domino does not found the res files the server will only log the error codes instead.

By default the res files should be installed into the standard local of the server called `C`.  
In some cases the installer does copy the res files into a locale specific directory. For example `../res/de_DE` for German.

The start script usually sets the locale of the server. For example to LANG=de_DE or LANG=en_US.  
If this locale is different than the locale you installed the server with, the Domino server will not find the res files in those cases.

The right location for the res files would be for example on Linux:

```
 /opt/hcl/domino/notes/latest/linux/res/C/strings.res
```

But in some cases it looks like this

```
 /opt/hcl/domino/notes/latest/linux/res/de_DE/strings.res
```

The solution for this issue is to move the de_DE directory to C (e.g. `mv de_DE C`) and your server will find the res files independent of the locale configured on the server.

You could create a sym link for your locale. This will ensure it works also with all add-on applications and in upgrade scenarios.

```
cd /opt/hcl/domino/notes/latest/linux/res
ln -s de_DE.UTF-8 C
ln -s en_US.UTF-8 C
```

In some cases when the installer created the directory for a specific locale, you should make sure that you also have directory or sym link to a directory for C. So the `ln -s` command would have the opposite order.

## Long user name issues

Some Linux/UNIX commands by default only show the names of a user if the name is 8 chars or lower.  
Some other commands like ipcs start truncating user-names in display after 10 chars.

It is highly recommended to use 8 chars or less for all user-names on Linux/UNIX!

## Domino SIGHUB Issue

The Domino JVM has a known limitation when handling the SIGHUB signal on some platforms.  
Normally the Domino Server does ignore this signal. But the JVM might crash when receiving the signal. Starting the server via nohub does not solve the issue.

The only two known working configurations are:

- Invoke the bash before starting the server

- Start server always with "su - " (switch user) even if you are already  running with the right user. The su command will start the server in it's own process tree and the SIGHUB signal is not send to the Domino processes.

  Note: The start-script does always switch to the Domino server user for the "start" and "restart" commands.  
  For other commands no "su -" is needed to enforce the environment.  
  Switching the user from a non-system account (e.g. root) will always prompt for password -- even when switching to the same UNIX user.
