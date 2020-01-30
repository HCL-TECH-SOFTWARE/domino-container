###########################################################################
# README - Start/Stop Script for Domino on xLinux/zLinux/AIX              #
# Version 3.3.1 10.01.2020                                                #
#                                                                         #
# (C) Copyright Daniel Nashed/NashCom 2005-2020                           #
# Feedback domino_unix@nashcom.de                                         #
#                                                                         #
# Licensed under the Apache License, Version 2.0 (the "License");         #
# you may not use this file except in compliance with the License.        #
# You may obtain a copy of the License at                                 #
#                                                                         #
#      http://www.apache.org/licenses/LICENSE-2.0                         #
#                                                                         #
# Unless required by applicable law or agreed to in writing, software     #
# distributed under the License is distributed on an "AS IS" BASIS,       #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.#
# See the License for the specific language governing permissions and     #
# limitations under the License.                                          #
###########################################################################

Note: See end of file for detailed Change History

------------
Introduction
------------

The Domino cross platform start/stop and diagnostic script has been written
to unify and simplify running Domino on Linux and UNIX. The start script
is designed to be "one-stop shopping" for all kind of operations done on the
Linux/UNIX prompt. The script can start and stop the server, provides an interactive
console and run NSD in different flavors.
It ensures that the environment is always setup correct and supports multiple partitions.

This script is designed to run with a dedicated user for each partition.
Out of the box the script is configured to use the "notes" user/group and the standard 
directories for binaries (/opt/ibm/domino) and the data directory (/local/notesdata).
You should setup all settings in the script configuration file.

Note: For newer versions using systemd (CentOS 7 RHEL 7/ SLES 12) root permissions are 
required to start/stop the server. 
One way to accomplish this is to grant "sudo" permissions for the "rc_domino" script.
See the "Enable Startup with sudo" section for details.

--------------------
Simple Configuration
--------------------

If you configure your Domino environment with the standard path names 
and users names, you can use this standard configuration and install script.

The default configuration is

User : notes
Group: notes
Binary Directory: /opt/ibm/domino
Data Directory  : /local/notesdata

The standard configuration is highly recommended. This will make your life easier for installing the server.
You can change the data directory in the rc_domino_config file. 
But the binary location and the notes:notes user and group should stay the same.

I would stay with the standard /local/notesdata. This could be a spearate mount-point.
And you could also use the following directory structure for the other directories.

/local/translog
/local/nif
/local/daos

Each of them could be a separate file-system/disk.

If you have the standard environemnt you just have to untar the start-script files and start the install_script.
It copies all the scripts and configuration and after installation you can use the "domino" command for everything.
The script is pre-configured and will work for older versions with init.d and also with the newer systemd.

- The first command untars the files
- The install_scripts writes all required files into the right locations with the right owner and permissions.
- The next command enables the service (works for init.d and systemd)
- And finally the server is started

tar -xvf start_script.tar
./install_script

domino service on
domino start

Other useful commands:

domino status
domino statusd
domino console

All details about configuration and commands are documented below.

--------------------------
Enable Startup with sudo
--------------------------

If you never looked into sudo, here is a simple configuration that allow you to run the start script with root permissions.
Basically this allows the notes user to run the /etc/init.d/rc_domino as root.
This avoids switching to the root user.

visudo

Add the following lines to the sudoer file

-- snip --
%notes  ALL= NOPASSWD: /etc/init.d/rc_domino *, /usr/bin/domino *
-- snip --


This allows you to to run the start script in the following way from your notes user.

sudo /etc/init.d/rc_domino ..


--------------------------
Quick manual Configuration
--------------------------

1.) Copy Script Files 

a.) Copy the script rc_domino_script into your Nash!Com start script directory /opt/nashcom/startscript 
b.) Copy rc_domino into /etc/init.d 

c.) For systemd copy the domino.service file to /etc/systemd/system
    And ensure that rc_domino contains the right location for the service file
	  configured in the top section of your rc_domino file -> DOMINO_SYSTEMD_NAME=domino.service.
		
2.) Ensure the script files are executable by the notes user

    Example: 
    chmod 755 /opt/nashcom/startscript/rc_domino_script
    chmod 755 /etc/init.d/rc_domino

	
3.) Check Configuration 

Ensure that your UNIX/Linux user name matches the one in the configuration part 
of the Domino server. Default is "notes".

For systemd ensure the configuration of the domino.service file is matching and 
specially if it contains the right user name and path to the rc_domino_script.
And also the right path for the "PIDFile"
(See "Special platform considerations --> systemd (CentOS 7 RHEL 7/ SLES 12 or higher)"  for details).


Special Note for systemd
------------------------

For systemd the start/stop operations are executed using the systemd service "domino.service".
The rc_domino script itself can be still used as a central entry point for all operations.
This includes start/stop which will calls the systemd commands in the background.
When using systemd you can re-locate the rc_domino script into any other directory.
It but it is perfectly OK to keep it in the /etc/init.d directory for consistence.

In addition take care that systemd does not use .profile and .bash_profile!
Environment variables are specified in the systemd service in the following way:

Environment=LANG=de_DE.UTF-8 


4.) Ensure to setup at least the following script variables per Domino partition.

- LOTUS 
  Domino binary directory 
  default: /opt/ibm/domino

- DOMINO_DATA_PATH
  Domino data directory
  default: /local/notesdata

  Setup the script in the configuration file per Domino partition. 
  The default location is in /etc/sysconfig/rc_domino_config
  
  Having the configuration separated from the script logic allows you to install new script 
  versions without changing the code in the script itself.
  All configuration can be found in the rc_domino_config file.
  It contains all configuration parameters either with a default value or commented out waiting to be enabled.
  
  For a single partition the defaults in the start script should work.
  This is the current recommended configuration. You should not modify the script itself.
  For AIX you may have to create a directory for the config file.


---------------------------------------
Special platform considerations systemd
---------------------------------------


systemd (CentOS 7 RHEL 7/ SLES 12 or higher)
--------------------------------------------
	
etc/systemd/system/domino.service contains the configuration for the systemd service.

The following parameters should be reviewed and might need to be configured.
Once you have configured the service you can enable and disable it with systemctl.
	
systemctl enable domino.service
systemctl disable domino.service

To check the status use "systemctl status domino.service".

Description of parameters used in domino.service	
	
User=notes
----------
	
This is the Linux user name that your partition runs with.
	
LimitNOFILE=60000
-----------------
	
With systemd the security limit configuration is not used anymore and the limits
are enforced by systemd. Starting with Domino 9 you should configure at least 60000 files.
Files means file handles and also TCP/IP sockets!

LimitNPROC=8000
---------------

With systemd the security limit configuration is not used anymore and the limits
are enforced by systemd. Even Domino uses pthreads you should ensure that you have 
sufficient processes configured because the limit does not specify the number of 
processes but the number of threads that the "notes" user is allowed to use!

TasksMax=8000
-------------

The version of systemd shipped in SLES 12 SP2 uses the PIDs cgroup controller. 
This provides some per-service fork() bomb protection, leading to a safer system.
It controls the number of threads/processes a user can use.
To control the default TasksMax= setting for services and scopes running on the system, 
use the system.conf setting DefaultTasksMax=. 

This setting defaults to 512, which means services that are not explicitly configured otherwise 
will only be able to create 512 processes or threads at maximum.
The domino.service sets this value for the service to 8000 explicitly. 
But you could also change the system wide setting.
CentOS / RHEL versions also support TaskMax and the setting is required as well.

Note: If you are running an older version TaskMax might not be supported and you have to remove the line from the domino.service


#Environment=LANG=en_US.UTF-8
#Environment=LANG=de_DE.UTF-8
-----------------------------

You can specify environment variables in the systemd service file.
Depending on your configuration you might want to set the LANG variable.
But in normal cases it should be fine to set it in the profile.

	
PIDFile=/local/notesdata/domino.pid
-----------------------------------
	
This PIDFile has to match the configured DOMINO_PID_FILE ins the start script.
By default the name is "domino.pid" in your data directory.
You can change the location if you set the configuration variable "DOMINO_PID_FILE" 
to override the default configuration if really needed.
	
ExecStart=/opt/nashcom/startscript/rc_domino_script start
ExecStop=/opt/nashcom/startscript/rc_domino_script stop
------------------------------------------------
	
Those two lines need to match the location of the main domino script including the start/stop command parameter.
	
TimeoutSec=100
--------------
	
Time-out value for starting the service
	
	
TimeoutStopSec=300
------------------

Time-out value for stopping the service
	

------------------------------------------------
Special platform considerations SLES11 and below
------------------------------------------------

The script (rc_domino) contains the name of the service. If you modify the name of 
the script you need to change the "Provides:"-line in the main rc-script
Example: " # Provides: rc_domino"
On SLES you can use the insserv command or run-level editor in YaST
Example: insserv /etc/init.d/rc_domino

To verify that your service is correctly added to the rc-levels use the following command
    
find /etc/init.d/ -name "*domino*"

Sample Output:
  /etc/init.d/rc3.d/K13rc_domino
  /etc/init.d/rc3.d/S09rc_domino
  /etc/init.d/rc5.d/K13rc_domino
  /etc/init.d/rc5.d/S09rc_domino
  /etc/init.d/rc_domino


-------------------------------------------------
Special platform considerations RedHat/CentOS 6.x
-------------------------------------------------

On RedHat/CentOS you can use the chkconfig to add Domino to the run-level environment
    
Example: chkconfig --add rc_domino

To verify that your service is correctly added to the rc-levels use the following command

find /etc/ -name '*domino*'

etc/sysconfig/rc_domino_config
/etc/rc.d/rc0.d/K19rc_domino
/etc/rc.d/init.d/rc_domino
/etc/rc.d/rc2.d/K19rc_domino
/etc/rc.d/rc6.d/K19rc_domino
/etc/rc.d/rc4.d/S66rc_domino
/etc/rc.d/rc3.d/S66rc_domino
/etc/rc.d/rc1.d/K19rc_domino
/etc/rc.d/rc5.d/S66rc_domino

And you can also query the runlevels in the following way

chkconfig --list | grep -i domino
rc_domino       0:off   1:off   2:off   3:on    4:on    5:on    6:off


------------------------------------
Special platform considerations AIX 
------------------------------------

For AIX change first line of the scripts from "#!/bin/sh" to "#!/bin/ksh"
Domino on Linux use "sh". AIX uses "ksh". 
The implementation of the shells differs in some ways on different platforms.
Make sure you change this line in rc_domino and rc_domino_script

On AIX you can use the mkitab to include rc_domino in the right run-level
Example: mkitab domino:2:once:"/etc/rc_domino start"

----------------------
Domino Docker Support 
----------------------

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

You an add your own configuration script (/docker_prestart.sh) to change the way the server is configured.
The script is started before this standard operations.
If the file /docker_prestart.sh is present in the container and the server is not yet setup, the script is executed first.

The output log of the Domino server is still written to the notes.log files.
And the only output you see in from the entry point script are the start and stop operations.

If you want to interact with the logs or use the monitor command, you can use a shell inside the container.
Using a shell you can use all existing Start Script commands.
But you should stop the Domino server by stopping the container and not use the 'stop' command provided by the start script.

!! Important information !!
---------------------------

Docker has a very short default shutdown timeout!
When you stop your container Docker will send a SIGTERM to the entry point.
After waiting for 10 seconds Docker will send a SIGKILL signal to the entry point!!

This would cause an unclean Domino Server shutdown!

The entrypoint script is designed to catch the signals, but the server needs time to shutdown!

So you should stop your Domino Docker containers always specifying the --time parameter to increase the shutdown grace period.

Example: docker stop --time=60 domino 
Will wait for 60 seconds until the container is killed.


Additonal Docker Start Script Configuration
-------------------------------------------

There is a special configuration option for start script parameters for Docker.
Because the rc_domino_config file is read-only, on Docker you can specify an additional config file
in your data directory which is usually configured to use a persistent volume which isn't part of the container.
This allows you to set new parameters or override parameters from the default config file.


-------------------------
Components of the Script
-------------------------

1.) rc_domino

  This shell script has two main purposes

  - Have a basic entry point per instance to include it in "rc" run-level
    scripts for automatic startup of the Domino partition 
    You need one script per Domino partition or a symbolic link
    with a unique name per Domino partition.

  - Switch to the right user and call the rc_domino_script.
  
  Notes:
   
  - If the user does not change or you invoke it as root you will not
    be prompted for a password. Else the shell prompts for the Notes 
    UNIX user password.
   
  - The script contains the location of the rc_domino_script. 
    You have to specify the location in DOMINO_START_SCRIPT
    (default is /opt/nashcom/startscript/rc_domino_script).
    It is not recommended to change this default location because of systemd configuration.
      

2.) rc_domino_script 

  This shell script contains
 
  - Implementation of the shell logic and helper functions.
  
  - General configuration of the script.

  - The configuration per Domino server specified by notes Linux/UNIX user.
    You have to add more configurations depending on your Domino partition setup.
    
    This is now optional and we recommend using the rc_domino_config_xxx files
    
3.) rc_domino_config / rc_domino_config_xxx

  This file is located by default in /etc/sysconfig and should be used as an external
  configuration (outside the script itself).
   
  By default the script searches for a name in the format rc_domino_config_xxx (e.g. for the 'notes' user rc_domino_config_notes)
  where xxx is the UNIX user name of the Domino server.
  The default name of the script shipped is rc_domino_config but you can add also a specific configuration file for your partition.
  
  The config files are used in the following order to allow flexible configurations:

	- First the default config-file is loaded if exists (by default: /etc/sysconfig/rc_domino_config)
  - In the next step the server specific config-file (by default: /etc/sysconfig/rc_domino_config_notes) is included.
  - The server specific config file can add or overwrite configuration parameters.

  This allows very flexible configuration. You can specify global parameters in the default config file and have specific config files per Domino partition.
  So you can now use both config files in combination or just one of them.
   
  Note: On AIX this directory is not standard but you can create it
  or if really needed change the location the script.
  
  Usually there is one configuration file per Domino partition and the last part of the name
  determines the partition it is used for. 
  
  Examples:
    rc_domino_config_notes, rc_domino_config_notes1, rc_domino_config_notes2, ...
  
  If this file exists for a partition those parameters are used for server
  start script configuration.
  
  This way you can completely separate configuration and script logic.
  You could give even write permissions to Domino admins to allow them to change
  the start-up script configuration. 
  
  This file only needs to be readable in contrast to rc_domino and rc_domino_script
  which need to be executable.

4.) systemd service file "domino.service

  Starting with CentOS 7 RHEL 7 and SLES 12 systemd is used to start/stop services.
  The domino.service file contains the configuration for the service.
  The variables used (Linux user name and script location) have to match your configuration.
  Configuration for the domino.service file is described in the previous section.
  Each Domino partition needs a separate service file. 
  See configuration details in section "Domino Start Script systemd Support"

5.) domino_docker_entrypoint.sh Docker entry point script 

  This script can be used as the standard entry point for your Domino Docker container.
  It takes care of your Domino Server start/stop operations.
  See details in the Docker section.

  
---------------------
Commands & Parameters
---------------------

start
-----

Starts the Domino server and archives the last OS-level Domino output-file.
The output-file is renamed with a time-stamp and compressed using the 
configured compression tool. Compressing the log file is invoked in background
to avoid slowing down the server start when compressing large log-files.
The start operation does clear the console input file and logs information
about the UNIX user environment and the security limits of the Unix user.


start live
----------

Same as "start" but displays the live console at restart.
See "monitor" command for details


stop
----

Stops the Domino server via server -q and waits a given grace period 
(configurable via DOMINO_SHUTDOWN_TIMEOUT -- default 10 minutes).
After this time the Domino server is killed via NSD if it cannot be shutdown
and processes are still ruining after this time (see "kill" command below)
The Java controller will also be shutdown (if used).
This is specially important when invoking a shutdown on systems using systemd.
If you specify "stop live" the live console is shown during shutdown.


stop live
---------

Same as "stop" but displays the live console during shutdown.
The live console is automatically closed after shutdown of the server
See "monitor" command for details


quit
----

Stops the Domino server via server -q and waits a given grace period 
(configurable via DOMINO_SHUTDOWN_TIMEOUT -- default 10 minutes).
After this time the Domino server is killed via NSD if it cannot be shutdown
and processes are still ruining after this time (see "kill" command below)
The Java controller remains active if configured.

restart
-------

Stops the Domino server and restarts it using "stop" and "start" command with
all implications and specially the time-out values for "stop".


restart live
------------

Same as "restart" but displays the live console for server/start stop
See "monitor" command for details


status
------

Checks if the Domino server is running and prints a message.

Return code of the script:
 0 = server is not running
 3 = server is running

 
statusd
-------

systemd has a very nice and detailed status command.
The default status check remains the status the existing status command.
This command is used to show the systemd status for the domino.service.
(the systemd command would be: systemctl status domino.service"


tika stop|kill
--------------

Shows the Tika server status and can be used to terminate the process.
Without additional parameters this command shows the status of the Tiker server process.

tika stop -> stops the Tika server process
tika kill -> kills the Tika server process


service
-------

Enables, Disables and shows the startup status of the service.
This command works on Linux only for rc-system and also systemd.
It is implemented in the "rc_domino" entry script.

service on -> enables the service
service off -> disables the service
service add -> deletes the service
service del -> deletes the service
service -> shows the startup status of the service

 
monitor
-------

Attaches to the output and the input files of a running Domino server and 
allows a kind of live console from a telnet/ssh session using the input
and output files. ctrl+c or "stop" terminates the live console.


cmd
---

Issue console commands from the linux command line
Syntax: rc_domino cmd "command" [n log lines]
The command needs to be specified in double-quotes like shown above.
The optional parameter log lines can be used to print the last n lines of 
log file (via tail) after waiting 5 seconds for the command to finish

Example: rc_domino cmd "show server" 200
issues a remote console command, waits 5 seconds and displays the last 200 lines

Note: Command parameters always need to be enclosed in quotes.
rc_domino passes the parameters with quotes to the main rc_domino_script.
But if you are using another script or other binary that calls rc_domino 
(for example service), the parameters might not be enclosed in quotes any more.
The rc_domino script requires that you have the parameters in quotes.
Every blank will be interpreted as a delimiter for a new parameter.


version
-------

Shows version of start script


inivar
------

Displays notes.ini setting specified.

Example: rc_domino inivar server_restricted


ini
---

Edit the notes.ini of the server. "vi" is the default editor which can be changed via "EDIT_COMMAND" config setting.

Note: You should not edit the notes.ini while the server is running.
You might corrupt the notes.ini. For a running server use "set config .. " on the server console instead.
Also take care with umlauts and other special characters.
In this case it is always recommended to use "set config" on a Notes Client instead because this will ensure that
the characters are converted correctly.


listini
-------

Lists server's notes.ini. You can use this command to show the notes.ini or redirect the output to a grep command


config/cfg
----------

Edit the start script configuration.
By default if no specific server/user configuration is present the default config is edited
You can either specify config 'server' or config 'default' for the different configurations.

The two options are: 
config server
config default



systemdcfg
----------

Edit the systemd config file.


log
---

Show or edit the log file. By default vi is used to edit the log file.
Optionally you can specify your own command e.g. log more or log head -100 

lastlog
-------

Shows last log lines. by default 100 lines are displayed.
Optionally you can specify the number of log lines

systemlog
---------

Shows last system log lines for the service from systemd. by default 100 lines are displayed.
Optionally you can specify the number of log lines


archivelog
----------

Archives the current server text log-file. The file is copied, compressed and 
the current log file is set to an empty file without losing the current 
file-handles of the server process. There might be a very short log file 
interruption between copying the file and setting it to an empty file. 
The new log file contains a log-line showing the archived log file name.

You can add a string to the archive log name as an additional parameter.
This can be useful if you have enabled debugging and want to capture an 
error situation. In that case run archivelog before and run it afterwards with a
string as an additional parameter which will be added to the file name of the zip.


clearlog
--------

Clears logs, custom logs and log backups as configured.

Optionally you can specify custom log cleanup days with two additional parameters.
First parameter defines log cut-off days for logs and second parameter defines cut-off days for backup logs.

Example: rc_domino clearlog 30 90 

Clears logs with 30 days expiration and clears backup logs with 90 days expiration independent of the configured days.

In normal cases you would just use "clearlog" without parameters and specify expiration settings in the configuration.


"clearlog" uses the following logic:

- If DOMINO_CUSTOM_LOG_CLEAR_SCRIPT is configured only the custom clear script is used else the following logic applies.


- If DOMINO_LOG_CLEAR_DAYS is set the following files will be removed if they meet the expiration times specified:

- If $DOMINO_LOG_PATH is set expired files are removed from this directory and sub-directories.
  Else all expired files from data_directory/IBM_TECHNICAL_SUPPORT and sub-directories are removed.


- If DOMINO_LOG_BACKUP_CLEAR_DAYS is set the following files will be removed if they meet the expiration times specified:

  If $DOMINO_LOG_BACKUP_DIR is set the following expired files are removed from this directory

  $DOMINO_USER_*.log.gz
  (Example: notes_*.log.gz)

  Else the same file pattern is used to remove files from the data-directory


- If DOMINO_CUSTOM_LOG_CLEAR_DAYS is set and also DOMINO_CUSTOM_LOG_CLEAR_PATH is set all expired files from
  this directory and sub-directories are removed that meet the specified expiration days


nsd
---

Generates a full NSD including call-stacks and memcheck.
You can pass additional parameters to NSD.


nsdnomem
--------

Generates a NSD without memcheck (nsd -nomemcheck).


info
----

Generates a sysinfo style NSD (nsd -info).


kill
----

Terminates the Domino server (nsd -kill)


resources
---------

Shows the resources that the server uses. 
This includes processes, shared memory, MQs, semaphores.
The resources are checked on OS level and list the same information 
that is used by the "cleanup" command below.
The command is useful for a running server but also for a crashed server
to check which resources might not have been cleaned up by fault recovery.


cleanup
-------

Remove hanging resources after a server crash
(processes, shared memory, semaphores, message queues)

In contrast to the NSD -kill option this routine removes ALL resources.
This includes all message queues, shared memory, semaphores allocated by
the UNIX user used by the Domino server instance.
And also removes all processes started from the server binary directory
(e.g. /opt/ibm/domino).
NSD currently does only remove registered resources in the following files:
pid.nbf, mq.nbf, sem.nbf, shm.nbf

So this command is mainly useful if NSD cannot remove all resources due to
corruptions or add-on programs or any other odd situation.
It prevents you from having to manually remove resources and processes in
such a corrupt state.

Note: Resources allocated by add-on applications using native OS-level
operations are not registered.

  
memdump
-------

Generate a memory dump from the currently running server. 


hang
----

Generate 3 NSDs collecting the call-stacks (nsd -stacks) and one additional full NSD.
This option is needed collecting troubleshooting data for server hang analysis.

stacks
------

Generate one NSD with call-stacks only (nsd -stacks)

compact
-------

Runs compact when server is shutdown (if the server is started an error message is displayed, you have to shutdown the server first)
Needs DOMINO_COMPACT_OPTIONS to be configured and is mainly intended for system databases.


restartcompact
--------------

Terminates the server, runs compact and restarts the server.
Needs DOMINO_COMPACT_OPTIONS to be configured and is mainly intended for system databases.


fixup 
-----
Runs fixup when server is shutdown (if the server is started an error message is displayed, you have to shutdown the server first)
needs DOMINO_FIXUP_OPTIONS to be configured and is mainly intended for system databases.


restartfixup
------------

Terminates the server, runs fixup and restarts the server.
needs DOMINO_FIXUP_OPTIONS to be configured and is mainly intended for system databases.


compactnextstart on|off|status
------------------------------

Allows you to configure one time compacting databases at next startup.
This functionality controls a text file 'domino_nextstartcompact' in your data directory.
If this file is present, the compact operations specified via
DOMINO_COMPACT_TASK, DOMINO_COMPACT_OPTIONS, DOMINO_LOG_COMPACT_OPTIONS are executed at next start.
The 'domino_nextstartcompact' will be deleted at next startup.

This is for example to be intended to be used after a planned OS reboot or OS patch.
And it avoids separate steps executed by the OS level admin. 

compactnextstart on  --> enables the compact at next startup
compactnextstart off --> disables the compact at next startup

Specifying no or any other option will show the current settings.

The status file used by default is domino_nextstartcompact in data directory.
If this file is present the compact operations will run once and remove the file.

------------------------
Configuration Parameters
------------------------

Variables can be set in the rc_domino_script per user (configuration settings)
or in the profile of the user.
Once the configuration is specified you need to set DOMINO_CONFIGURED="yes"


DOMINO_USER
-----------

(Required)
User-variable automatically set to the OS level user (indirect configuration)


LOTUS
-----

(Required)
Domino installation directory (usual /opt/ibm/domino in D7)
This is the main variable which needs to be set for binaries 
Default: /opt/ibm/domino 


DOMINO_DATA_PATH
----------------

(Required)
Data-Directory
Default: /local/notesdata


DOMINO_CONFIGURED
-----------------

(Required)
Configuration variable. Needs to be set to "yes" per user to confirm
that the environment for this user is setup correctly


DOMINO_LANG
-----------

(Optional)
Language setting used to determine local settings 
(e.g. decimal point and comma)
Examples: DOMINO_LANG=en_US.UTF-8
Default: not set --> uses the setting of the UNIX/Linux user

DOMINO_ENV_FILE
---------------

(Optional)
Environment file, which is particular useful for systemd environments, where the profile cannot be used to set variables, because systemd starts the process
You can source in the file into your profile for processes starting from a shell and have it included into the server running under systemd.
systemd invokes rc_domino_script which sets the parameters if the configured file exists and can be read.


DOMINO_UMASK
------------

(Optional)
umask used when creating new files and folders.
Usually this is set in the profile of the user but can be also set here for flexibility
Examples: DOMINO_UMASK=0077
Default: not set --> Uses the setting of the UNIX/Linux user


DOMINO_SHUTDOWN_TIMEOUT
-----------------------

(Optional)
Grace period in seconds (default: 600) to allow to wait until the Domino 
server should shutdown. After this time nsd -kill is used to terminate
the server. 


DOMINO_LOG_DIR
--------------

(Optional)
Output log file directory for domino log files.
Default: DOMINO_DATA_PATH


DOMINO_OUTPUT_LOG
-----------------

(Optional)
Output log file used to log Domino output into a OS-level log file
(used for troubleshooting and the "monitor" option).
Default: "username".log in data-directory


DOMINO_INPUT_FILE
-----------------

(Optional)
Input file for controlling the Domino server (used for "monitor" option)
Default: "username".input in data-directory


DOMINO_LOG_BACKUP_DIR
---------------------

(Optional)
Output log file backup directory for domino log files for archiving log files.
Default: DOMINO_DATA_PATH


DOMINO_ARCHIVE_LOGS_SHUTDOWN
----------------------------

(Optional)
Archive logs after Domino server is shutdown. 
This operation runs after the server is shutdown and before a DOMINO_POST_SHUTDOWN_SCRIPT is executed.
Specify "yes" to enable this option.

The option could be helpful specially when the Domino output files are written to a tmpfs.
In combination with setting a different location for the DOMINO_LOG_BACKUP_DIR those files could
be saved to a normal disk while at run-time the files are still written to a normal disk.


USE_JAVA_CONTROLLER
-------------------

(Optional)
Use the Java Controller to manage the Domino server.
Specify "yes" to enable this option.

When using the Java Server Controller the "monitor" command cannot be used because the
Domino Java Server Controller does handle all the console input/output and writes to separate files.


COMPRESS_COMMAND
----------------

(Optional)
Command that is used to compress log files. There might be different options 
possible depending on your platform and your installed software
e.g. compress, zip, gzip, ...
(Default: "gzip --best").


EDIT_COMMAND
------------

By default "vi" is used to edit files via start script.
This option can be used to change the edit command to for example "mcedit" instead.


REMOVE_COMMAND_TEMP
-------------------
By default "rm -f" is used to remove temporary files.
You can change this in case you want special checking or archiving etc.


REMOVE_COMMAND_CLEANUP
----------------------
By default "rm -f" is used to remove files that should be cleaned up when they are expired.
You can change this in case you want special checking or archiving etc.
This would be specially useful for archiving.
But you could also change it for example to "ls -l" to test which files would be removed during cleanup.


DOMINO_DEBUG_MODE
-----------------

(Optional)
Enabling the debug mode via DOMINO_DEBUG_MODE="yes" allows to trace and
troubleshoot the start script. Enable this option only for testing!

DOMINO_DEBUG_FILE
---------------------------

(Optional)
When you enable the debug mode debug output is written to the console
This option allows to specify a separate debug output file.
Note: Works in combination with DOMINO_DEBUG_MODE="yes"


DOMINO_RESET_LOADMON
--------------------

(Optional - Recommended - Default)
Domino calculates the Server Availability Index (SAI) via LoadMon by calculating
the current transaction times and the minimum transactions times which are 
stored in loadmon.ncf when the server is shutdown.
This file can only be deleted when the server is showdown.
Enable this option (DOMINO_RESET_LOADMON="yes") to remove loadmon.ncf at server startup
Note: When using this option you will only see a loadmon.ncf in the data directory,
when the server is down, because it will be only written at server shutdown time.


DOMINO_CUSTOM_COMMAND_BASEPATH
------------------------------

(Optional - Expert)
This option allows you to specify a directory which is used for custom commands.
If a command which is specified when invoking the script matches a script name which
is present in the specified directory (and if the script can be executed) the custom
command will execute the script passing all current parameters of the current command.
This is a new flexible way to plug-in your own commands without changing the code of the main script logic.


DOMINO_NSD_BEFORE_KILL
----------------------

(Optional - Recommended - Default)
Generates a NSD before finally using NSD -kill to recycle the server.
This is specially interesting to troubleshoot server shutdown issues.
Therefore the option is enabled by default in current configuration files.
Enable this option via (DOMINO_NSD_BEFORE_KILL="yes")


DOMINO_REMOVE_TEMPFILES
-----------------------

(Optional)
Enable this option (DOMINO_REMOVE_TEMPFILES="yes") to remove temp-files from 
data-directory and if configured from DOMINO_VIEW_REBUILD_DIR at server startup. 
The following files are removed:
*.DTF, *.TMP


!Caution!
---------
Take care that some TMP files can contain important information.
For example files generated by SMTPSaveImportErrors=n
In such cases you have to move those files before restarting the server
Server-Restart via Fault-Recovery is not effected because the internal start
routines do generally not call this start script.

Therefore the script only deletes *TMP files in data directory which are at least 1 day old.


DOMINO_CUSTOM_REMOVE_TEMPFILES_SCRIPT
-------------------------------------

(Optional - Expert)
This script allows a customizable way to remove temp files on server start.
A sample script "remove_tempfiles_script" is included.
the script works in combination with "DOMINO_REMOVE_TEMPFILES".
you have to specify a script name and enable the option.
this script overwrites the default code in the start script.

DOMINO_CLEAR_LOGS_STARTUP
-------------------------

(Optional)
Clear Logs on startup before the server starts.
See "clearlog" for details about the actions performed.


DOMINO_LOG_CLEAR_DAYS
---------------------

(Optional)
Number of days until logs are cleared
(See details in "clearlog" command description)


DOMINO_LOG_BACKUP_CLEAR_DAYS
----------------------------

(Optional)
Number of days until backup logs are cleared
(See details in "clearlog" command description)


DOMINO_CUSTOM_LOG_CLEAR_PATH
----------------------------

(Optional)
Specify this custom location to remove old logs from a directory.
Can only be used in combination with DOMINO_CUSTOM_LOG_CLEAR_DAYS

DOMINO_CUSTOM_LOG_CLEAR_DAYS
----------------------------

(Optional)
Age of log files to be cleared. Works in combination with DOMINO_CUSTOM_LOG_CLEAR_PATH.


DOMINO_CUSTOM_LOG_CLEAR_SCRIPT
------------------------------

(Optional - Expert)
Custom log clear script will be used instead of the standard log clear operations and replaces all other clear operations!
(See details in "clearlog" command description)


DOMINO_LOG_DB_DAYS
------------------

(Optional)
Rename log.nsf database on startup after n days
(This will only work for the default log.nsf location and not check the log= notes.ini parameter).

The file domino_last_log_db.txt in data directory will hold the last time the log was renamed


DOMINO_LOG_DB_BACKUP_DIR
------------------------

(Optional)
Target directory for rename log.nsf database on startup / default "log_backup" in data dir

Moving the log.nsf will be executed before starting the server and after the startup compact/fixup operations
You can specify a directory inside or outside the Domino data directory


DOMINO_LOG_DB_BACKUP
--------------------

(Optional)
Sets a fixed log.nsf backup file to have one additional version of log.nsf 
Instead of creating multiple versions with date-stamp. Works in combination with DOMINO_LOG_DB_DAYS.

Instead of renaming a log database you can specify "DELETEDB" to remove the log database.


DOMINO_DOMLOG_DB_BACKUP
-----------------------

(Optional)
Sets a fixed domlog.nsf backup file to have one additional version of domlog.nsf
Instead of creating multiple versions with date-stamp. Works in combination with DOMINO_DOMLOG_DB_DAYS.

Instead of renaming a log database you can specify "DELETEDB" to remove the log database.


DOMINO_DOMLOG_DB_DAYS
---------------------

(Optional)
Rename domlog.nsf database on startup after n days

The file domino_last_domlog_db.txt in data directory will hold the last time the log was renamed

DOMINO_DOMLOG_DB_BACKUP_DIR
---------------------------

(Optional)
Target directory for rename domlog.nsf database on startup / default "log_backup" in data dir

Moving the domlog.nsf will be executed before starting the server and before startup compact/fixup operations
You can specify a directory inside or outside the Domino data directory


NSD_SET_POSIX_LC
---------------------------

(Optional)
Set the locale to POSIX (C) when running NSD


DOMINO_PRE_SHUTDOWN_COMMAND
---------------------------

(Optional)
Command to execute before shutting down the Domino server.
In some cases, shutting down a certain servertask before shutting down the
server reduces the time the server needs to shutdown.


DOMINO_PRE_SHUTDOWN_DELAY
-------------------------

(Optional)
Delay before shutting down the Domino server after invoking the pre-shutdown
command. If configured the shutdown waits this time until invoking the
actual shutdown after invoking the DOMINO_PRE_SHUTDOWN_COMMAND command.


DOMINO_VIEW_REBUILD_DIR
-----------------------

(Optional)
View Rebuild Directory which will be created if not present.
This option is specially useful for servers using temp file-systems with
subdirectories for example for each partitioned servers separately.
Use notes.ini view_rebuild_dir to specify directory.


DOMINO_TEMP_DIR
---------------

(Optional)
Notes Temporary Directory which will be created if not present.
This option is specially useful for servers using temp file-systems with 
subdirectories for example for each partitioned servers separately.
Use notes.ini notes_tempdir to specify directory.


DOMINO_LOG_PATH
---------------

(Optional)
Log Directory which will be created if not present.
This option is specially useful for servers using temp file-systems with 
subdirectories for example for each partitioned servers separately.
Use notes.ini logfile_dir to specify directory.

The following settings are intended to add functionality to the existing start script without modifying the code directly.
Those scripts inherit all current variables of the main script. 
The scripts are invoked as kind of call-back functionality.
You have to ensure that those scripts terminate in time.


DOMINO_3RD_PARTY_BIN_DIRS
-------------------------

(Optional)
3rd Party directories to check for running processes when cleaning up server resources
specify separate directories with blank in-between. directory names should not contain blanks.
those directories are also checked for running processes when cleaning up server resources via "clenup" command
by default only the $LOTUS directory is checked for running binaries


DOMINO_SCRIPT_DIR
-----------------

(Optional - Expert)
This variable can be used to specify a directory for all scripts that can be invoked.
it is only referenced in the configuration file and used by default for a scripts which are invoked.
but you can also specify different locations per pre/post script.


DOMINO_TIKA_SHUTDOWN_TERM_SECONDS
---------------------------------

Tries to shutdown the Tika index server during shutdown.
It can happen that the Tika server does not terminate, which prevents the Domino server from shutting down properly.
Default: 30 seconds

DOMINO_SHUTDOWN_DELAYED_SCRIPT
------------------------------

Script which can be executed delayed during shutdown. 
DOMINO_SHUTDOWN_DELAYED_SECONDS specifies the number of seconds after shutdown start.

DOMINO_SHUTDOWN_DELAYED_SECONDS
-------------------------------

Shutdown Delay for delayed shutdown command.
Default is 20 seconds if script is defined.


DOMINO_PRE_STARTUP_SCRIPT
--------------------------

(Optional - Expert)
This script is invoked before starting the server.

DOMINO_POST_STARTUP_SCRIPT
--------------------------

(Optional - Expert)
This script is invoked after starting the server.


DOMINO_PRE_SHUTDOWN_SCRIPT
--------------------------

(Optional - Expert)
This script is invoked before shutting down the server.


DOMINO_POST_SHUTDOWN_SCRIPT
---------------------------

(Optional - Expert)
This script is invoked after shutting down the server


DOMINO_PRE_KILL_SCRIPT 
----------------------

(Optional - Expert)
This script is invoked before any "nsd -kill" is executed


DOMINO_POST_KILL_SCRIPT
-----------------------

(Optional - Expert)
This script is invoked after any "nsd -kill" is executed


DOMINO_PRE_CLEANUP_SCRIPT
-------------------------

(Optional - Expert)
This script is invoked before cleaning up server resources native on OS level


DOMINO_POST_CLEANUP_SCRIPT
--------------------------

(Optional - Expert)
This script is invoked after cleaning up server resources native on OS level


DOMINO_PRE_STATUS_SCRIPT
------------------------

(Optional - Expert)
Script which will be executed before the server status is checked.
This can be helpful in case you want to check status for other tools like monitoring tools before you check the Domino server status.
The option does not directly impact the status of the Domino status and is mainly intended to add log output.


DOMINO_START_COMPACT_OPTIONS
----------------------------

(Optional)
Specifies which compact should be executed before Domino server start
this allows regularly compact of e.g. system databases when the server starts
you should specify an .ind file for selecting system databases
an example which is disabled by default is included in the config file


DOMINO_COMPACT_OPTIONS
----------------------

(Optional)
Specifies which compact options to use when using the "compact" and "restartcompact" commands
you should specify an .ind file for selecting system databases
an example which is disabled by default is included in the config file


DOMINO_START_FIXUP_OPTIONS
----------------------------

(Optional)
Specifies which fixup should be executed before Domino server start
this allows regularly fixup of e.g. system databases when the server starts
you should specify an .ind file for selecting system databases
an example which is disabled by default is included in the config file

Note: fixup is a last resort operation when a database is corrupted and 
it is not required to run fixup regularly on any database in a scheduled manner.
some customers have special requirements and this start script is intended to 
provide options for different customer cases


DOMINO_FIXUP_OPTIONS
--------------------

(Optional)
Specifies which fixup options to use when using the "fixup" and "restartfixup" commands
you should specify an .ind file for selecting system databases
an example which is disabled by default is included in the config file


DOMINO_COMPACT_TASK
-------------------

(Optional)
Compact task can now be specified. By default "compact" is used.
Another option would be to use "dbmt" in Domino 9.

DOMINO_LOG_COMPACT_OPTIONS
--------------------------

(Optional)
Log compact options


DOMINO_LOG_START_COMPACT_OPTIONS
--------------------------------

(Optional)
Start log compact options

DOMINO_CONSOLE_SERVERC
----------------------

By default live console uses server -c "cmd" to run server commands.
This new functionality can be reverted back to the previous functionality via DOMINO_CONSOLE_SERVERC=NO.
In this case a echo "cmd" > notes.input is used.
Switching back to the old behavior disables support for the live console in combination with the server controller.


DOMINO_PID_FILE
---------------

(Optional - Expert)
Domino PID file per partition which has to match the PIDFile setting in the domino.service.
This option is only required for systemd support.
The default is domino.pid located in the Domino data-directory.
If you change the setting you have also change the domino.service file.


Additional Options
------------------------
You can disable starting the Domino server temporary by creating a file in the 
data-directory named "domino_disabled". If the file exists when the start 
script is called, the Domino server is not started


-----------------------------
Differences between Platforms
-----------------------------

The two scripts use the Korn-Shell (/bin/ksh) on AIX.
On Linux the script needs uses /bin/sh.
Edit the first line of the script according to your platform
Linux: "#!/bin/sh"
AIX: "#!/bin/ksh" 


-------------------------------------------
Tuning your OS-level Environment for Domino
-------------------------------------------

Tuning your OS-platform is pretty much depending the flavor and version of
UNIX/Linux you are running. You have to tune the security settings for
your Domino UNIX user, change system kernel parameters and other system
parameters.

The start script queries the environment of the UNIX notes user and
the basic information like ulimit output when the server is started.

The script only sets up the tuning parameters specified in the UNIX user
environment. There is a section per platform to specify OS environment
tuning parameters.

Linux
-----

You have to increase the number of open files that the server can open.
Those file handles are required for files/databases and also for TCP/IP sockets.
The default is too low and you have to increase the limits.
Using the ulimit command is not a solution. Settings the security limits via root
before switching to the notes user executing the start script via "su -" does not work any more.
And it would also not be the recommended way. 

su leverages the pam_limits.so module to set the security limits when the user switches.

So you have to increase the limits by modifying /etc/security/limits.conf

You should add a statement like this to /etc/security/limits.conf

* soft nofile 60000
* hard nofile 60000


systemd Changes (CentOS 7 RHEL 7 /SLES 12)
------------------------------------------

This configuration is not needed to start servers with systemd.
systemd does set the limits explicitly when starting the Domino server.
The number of open files is the only setting that needs to be changed via
LimitNOFILE=60000 in the domino.service file.


export NOTES_SHARED_DPOOLSIZE=20971520
Specifies a larger Shared DPOOL size to ensure proper memory utilization.


Detailed tuning is not part of this documentation.
If you need platform specify tuning feel free to contact
domino_unix@nashcom.de


----------------------
Implementation Details
----------------------

The main reason for having two scripts is the need to switch to a different 
user. Only outside the script the user can be changed using the 'su' command
and starting another script. On some platforms like Linux you have to ensure
that su does change the limits of the current user by adding the pam limits
module in the su configuration. 

In the first implementation of the script the configuration per user was 
specified in the first part of the script and passed by parameter to the 
main script. This approach was quite limited because every additional parameter
needed to be specified separately at the right position in the argument list.
Inheriting the environment variables was not possible because the su command
does discard all variables when specifying the "-" option which is needed
to setup the environment for the new user.
Therefore the beginning of the main script contains configuration parameters
for each Domino partitions specified by UNIX user name for each partition.


-----------------------------------
Domino Start Script systemd Support
-----------------------------------

Beginning with CentOS 7 RHEL 7 and SLES 12 Linux is using the new "systemd"
(http://en.wikipedia.org/wiki/Systemd) for starting services daemons. 
All other platforms are also moving to systemd. 
rc scripts are still working to some extent. but it makes sense to switch to the systemd service model.
Most of the functionality in the Domino start script will remain the same and you will also
continue to use the same files and configuration. But the start/stop operations are done by a "domino.service".

The start script will continue to have a central entry point per partition "rc_domino" but that script
is not used by the "rc environment" any more. You can place the file in any location and it is not leveraged by systemd.

systemd will use a new "domino.service" per Domino partition.
The service file will directly invoke the main script logic "rc_domino_script" after switching to the right user
and setting the right resources like number of open files
(before this was done with "su - notes" and the limits configuration of the corresponding pam module).

Starting and Stopping the Domino server can be done either by the rc_domino script which will invoke the
right service calls in the background. Or directly using the systemd commands.

Starting, Stopping and getting the Status

systemctl start domino.service
systemctl stop domino.service
systemctl status domino.service 

Enabling and Disabling the Service

systemctl enable domino.service
systemctl disable domino.service

The service file itself is be located in /etc/systemd/system.

You have to install a service file per Domino partition. 
When you copy the file you have to make sure to have the right settings

a.) ExecStart/ExecStop needs the right location for the rc_domino_script (still usually the Domino program directory) 
b.) Set the right user account name for your Domino server (usually "notes").

The following example is what will ship with the start script and which needs to be copied 
to "/etc/systemd/system" before it can be enabled or started. 

Systemd service file shipped with the start script
------------------------------------------------------

[Unit] 
Description=IBM Domino Server 
After=syslog.target network.target 

[Service] 
Type=forking 
User=notes 
LimitNOFILE=60000 
PIDFile=/local/notesdata/domino.pid 
ExecStart=/opt/nashcom/startscript/rc_domino_script start
ExecStop=/opt/nashcom/startscript/rc_domino_script stop
TimeoutSec=100 
TimeoutStopSec=300 
KillMode=none 
RemainAfterExit=no 

[Install] 
WantedBy=multi-user.target 


The rc_domino script can be still used for all commands.
This includes starting and stopping Domino as a service (only "restart live" option is not implemented).
You can continue to have rc_domino with the same or different names in the /etc/init.d directory
or put it into any other location. It remains the central entry point for all operations.

But the domino.service can also be started and stopped using "systemctl". 
rc_domino uses the configured name of the domino.service (in the header section of rc_domino script).

systemd operations need root permissions. So it would be best to either start rc_domino for start/stop operations with root.
One way to accomplish using root permissions is to allow sudo for the rc_domino script.

The configuration in /etc/sysconfig/rc_domino_config (or whatever your user name is)
will remain the same and will still be read by rc_domino_script.

The only difference is that the rc_domino_script is invoked by the systemd service instead of the rc_domino script for start/stop operations.

When invoking start/stop live operations a combination of systemd commands and the existing rc_domino_script logic is used.


New systemd status command
--------------------------

The output from the systemd status command provides much more information than just if the service is started.

Therefore when using systemd the rc_domino script has a new command to show the systemd status output.
The new command is "statusd"


How do you install the script with systemd?
-------------------------------------------

- Copy rc_domino, rc_domino_script and rc_domino_config to the right locations 
- Copy domino.service to etc/systemd/system.
- Make the changes according to your environment 
- Enable the service via systemctl enable domino.service and have it started/stopped automatically
  or start/stop it either via systemd command or via rc_domino script commands.
- rc_domino script contains the name of the systemd service. 
  If you change the name or have multiple partitions you need to change the names accordingly

  
How does it work?
-----------------

a.) Machine startup
When the machine is started systemd will automatically start the domino.service. 
The domino.service will invoke the rc_domino_script (main script logic). 
rc_domino_script will open rc_domino_config for configuration. 

b.) Start/Stop via rc_domino
when rc_domino start is invoked the script will invoke the service via systemctl start/stop domino.service

c.) Other script operations

Other operations like "monitor" will continue unchanged and invoke the rc_domino_script.


------------
Known Issues
------------


Hex Messages instead of Log Messages
------------------------------------

In some cases when you start the Domino server with my start script you see
hex codes instead of log message.

The output looks similar to this instead of real log messages.

01.03.2015 12:42:00 07:92: 0A:0A
01.03.2015 12:42:00 03:51: 07:92

Here is the background about what happens:

Domino uses string resources for error messages on Windows which are linked into the binary.
On Linux/UNIX there are normally no string resources and IBM/Lotus uses the res files created
on Windows in combination which code that reads those string resources for error output.

In theory there could be separate version of res files for each language and there used to be res 
files which have been language dependent.
So there is code in place in Domino to check for the locale and find the right language for error message.

But there are no localized resources for the error codes any more since Domino ships as English version
with localized language packs (not containing res files any more).
This means there is only one set of res Files in English containing all the error text for the core code
(a file called strings.res) and one per server tasks using string resources.
So string resources contain all the error texts and if Domino does not found the res files the server
will only log the error codes instead.

By default the res files should be installed into the standard local of the server called "C".
In some cases the installer does copy the res files into a locale specific directory. For example ../res/de_DE for German.

The start script usually sets the locale of the server. For example to LANG=de_DE or LANG=en_US.
If this locale is different than the locale you installed the server with, the Domino server will
not find the res files in those cases.

The right location for the res files would be for example on Linux:
 /opt/ibm/domino/notes/latest/linux/res/C/strings.res

But in some cases it looks like this
 /opt/ibm/domino/notes/latest/linux/res/de_DE/strings.res

The solution for this issue is to move the de_DE directory to C (e.g. mv de_DE C) and your server
will find the res files independent of the locale configured on the server.

You could create a sym link for your locale. This will ensure it works also with
all add-on applications and in upgrade scenarios.

cd /opt/ibm/domino/notes/latest/linux/res
ln -s de_DE.UTF-8 C
ln -s en_US.UTF-8 C


In some cases when the installer created the directory for a specific locale, you should make sure that you also have directory or sym link to a directory for C. So the ln -s command would have the opposite order.


Long user name issues
---------------------

Some Linux/UNIX commands by default only show the names of a user if the name is 8 chars or lower.
Some other commands like ipcs start truncating user-names in display after 10 chars.

It is highly recommended to use 8 chars or less for all user-names on Linux/UNIX!



Domino SIGHUB Issue
-------------------

The Domino JVM has a known limitation when handling the SIGHUB signal on some platforms.
Normally the Domino Server does ignore this signal. But the JVM might crash
when receiving the signal. Starting the server via nohub does not solve the issue.
The only two known working configurations are:

a.) Invoke the bash before starting the server

b.) - Ensure that your login shell is /bin/ksh
    - Start server always with "su - " (switch user) even if you are already
      running with the right user. The su command will start the server in
      it's own process tree and the SIGHUB signal is not send to the Domino
      processes. 
      
      Note: The start-script does always switch to the Domino server user
      for the "start" and "restart" commands.
      For other commands no "su -" is needed to enforce the environment.
      Switching the user from a non-system account (e.g. root) will always
      prompt for password -- even when switching to the same UNIX user.
      

SELinux (RedHat) RC-start level issue
-------------------------------------

Depending on your configuration the RC-subsystem will ask for confirmation
when starting Domino when switching the run-level.

To avoid this question you have to ensure that your pam configuration for
"su" is setup correctly. 

remove the "multiple" from the pam_selinux.so open statement

example: /etc/pam.d/su
session    required     pam_selinux.so open multiple

extract from pam_selinux documentation

multiple 

Tells pam_selinux.so to allow the user to select the security context they
will login with, if the user has more than one role.

This ensures that there are no questions asked when starting the Domino server
during run-level change.


!Caution!
---------
Modifying the script to use "runuser" instead of "su" is not a solution,
because "runuser" does not enforce the /etc/security/limits specified for the
notes-user. 
This means that the security limits (max. number of open files, etc.)might be to low.
You can check for the security limits in the output log of the script.
The ulimit output is dumped when the server starts.


!Note!
------
To enforce the security limits for the user you have to add the following line
to /etc/security/limits before pam_selinux.so open

session    required     pam_limits.so

SLES10 does contain this setting by default.
The default settings have been enhanced and different parts use include files.
The include file used for "session" settings contains this entry already.

--------------
Change History
--------------

V3.3.1 10.01.2020

New Features
------------

New configuration variable DOMINO_ENV_FILE

Environment file, which is particular useful for systemd environments, where the profile cannot be used to set variables, because systemd starts the process
You can source in the file into your profile for processes starting from a shell and have it included into the server running under systemd.
systemd invokes rc_domino_script which sets the parameters if the configured file exists and can be read.


Additional check for live console to ignore "e" and "q" to stop the server.
This helps to avoid  accidential server shutdowns. "qu", "ex" and other short-cuts for "quit" and "exit" will still work.


V3.3.0 01.01.2020


New Features
------------

Updated container support for other container environments than Docker (detecting other container run-time environments)

Updated support for AIX including install script


Changes
-------

Changed live console functionality

Up to now the live console wrote into the notes.input file which is connected to the server process (< input file).
With the new functionality the commands are send to the server via server -c  "command".
This change is intended to solve an issue with a stall console in some situations.
In addition this allows live console functionality also in combination with the server controller.
The script detects the current server controller file (via notes.ini setting DominoControllerCurrentLog).
You can switch to the previous behavior via DOMINO_CONSOLE_SERVERC=NO.


Removed legacy configuration from rc_domino_script, which was confusing


--------------
Change History
--------------

V3.2.2 16.05.2019

New Features
------------

New Commands:

"systemlog" shows the last log lines from systemd service.
This is helpful to see output of the start script.


"tika" stop|kill

Shows the Tika server status and can be used to terminate the process.
Without additional parameters this command shows the status of the Tiker server process.
tika stop --> stops the process.
tik kill  --> kills the process. 

Added "locale" output to server start logging.
This can help to troubleshoot issues with locale setting on your server.


New configuration options:


DOMINO_TIKA_SHUTDOWN_TERM_SECONDS

Tries to shutdown the Tika index server during shutdown.
IT happens that the Tika server does not terminate, which prevents the Domino server from shutting down properly.
Default 30 seconds.

DOMINO_SHUTDOWN_DELAYED_SCRIPT

Script which can be executed delayed during shutdown. 
DOMINO_SHUTDOWN_DELAYED_SECONDS specifies the number of seconds after shutdown start.

DOMINO_SHUTDOWN_DELAYED_SECONDS (default 20 seconds)

Shutdown Delay for delayed shutdown command.
Default is 20 seconds if script is defined.


Docker Support:

Now the entry point script checks if the script is already started with the right user and will not switch to the user.
There are configuration options on the Docker side to run the entry point script directly with the right user.
When you switch the user to "notes" at the end of your dockerfile, the container is started with "notes".
This provides better security.

Problems Solved
---------------
restartcompact and restartfixup did not work correctly with systemd. 
For systemd the rc_domino script needs to stop the service run compact/fixup and restart the service.


V3.2.1 02.03.2019

Problems Solved
---------------

The configuration DOMINO_UMASK was enabled by default.

New Features
------------

Instead of renaming log databases this new feature allows to delete log databases.

The new functionality is available for the following configuration parameters:

DOMINO_LOG_DB_BACKUP
DOMINO_DOMLOG_DB_BACKUP_DIR

Instead of specifying a target database you specify "DELETEDB" to remove the database on restart.


V3.2.0 30.10.2018

New Features
------------

The start script was always free. To ensure everyone can use it, 
it is now available under the Apache License, Version 2.0.
All files of the start script now contain the required header.

Introducing Domino Docker support!
The start script wasn't completely ready for Domino on Docker.
There are special requirements when running in an Docker environment.
The start script now includes a Docker entrypoint file to start and stop the server.
See details in the Docker Support section of the start script.

New command 'log' -- displays the start script output log.
This command can be used with additional options like specifying the command to open the log (e.g. 'log more').
See log command description for details.

New command 'systemdcfg' to edit the systemd configuration file

New command 'compactnextstart' which allows you to configure a one time compact at next startup.
For example after an OS patch day. The new command allows you to enable/disable/display the settings.
Check the command documentation for details.

New config variables DOMINO_DOMLOG_DB_DAYS, DOMINO_DOMLOG_DB_BACKUP_DIR which can move domlog.nsf to a backup directory.
This works like the log.nsf backup/rename introduced earlier.

New config variable DOMINO_UMASK.
And also allow to set the umask when starting the server via DOMINO_UMASK.

New variable DOMINO_LOG_DB_BACKUP to set a fixed log.nsf backup file to have one additional version of log.nsf
instead of creating multiple versions with date-stamp. Works in combination with DOMINO_LOG_DB_DAYS.

New variable DOMINO_DOMLOG_DB_BACKUP to set a fixed domlog.nsf backup file to have one additional version of domlog.nsf 
instead of creating multiple versions with date-stamp. Works in combination with DOMINO_DOMLOG_DB_DAYS.

Show the umask used in the startup log of the server (along with environment and ulimits etc).

Separate, simple script 'install_script' that will allow you to install the start script for default configurations.


Changes
-------

Start script is now prepared for systemd without changing rc_domino script (adding the service name).

Enable the configuration for systemd in the rc_domino script by default and check if systemd is used on the platform.
This allows to install it on servers with systemd or init.d without changing the rc_domino script.

Changing deployment from zip to tar format. So you can unpack the files directly on the target machine.
This also means you can run the install_script without changing the permissions.

Changed the default location for the Domino PID file for systemd from /local/notesdata/domino.pid to /tmp/domino.pid.
This allows you to change the data directory location without changing the pid file name in domino.service and config.
But this means for multiple partitions you have to change the name for each of the services.

I tried to dynamically read parameters from the config file in domino.service.
There is an EnvironmentFile= statement in systemd services to read configuration files.
But using variables does only work for parameters passed to a an ExecStart/ExecStop command but not for the name of
those scripts invoked. Also it is not directly sourcing the parameters but reading them directly.
So there seems to be no way to read the config of domino.service from the config file.
And I had to "hardcode" the filenames.


V3.1.3 30.10.2017

Problems Solved
---------------

Fixed an issue with systemd in combination with server controller.
Now the server controller correctly shutdown when the service is stopped


New Features
------------

listini -- displays server's notes.ini

Changes
-------

Changed sample rc_domino_config_notes setting DOMINO_PRE_SHUTDOWN_COMMAND to "tell traveler shutdown"


V3.1.2 01.09.2017

New Features
------------

New check if Domino ".res" files exist and readable to generate warnings

New short cut command "res" for "resources"

Changes
-------

In previous version either the server specific config file was used or the default config file.

The config files are now used in the following order to allow more flexible configurations:

- First the default config-file is loaded if exists (by default: /etc/sysconfig/rc_domino_config)
- In the next step the server specific config-file (by default: /etc/sysconfig/rc_domino_config_notes) is included.
- The server specific config file can add or overwrite configuration parameters.

This allows very flexible configurations. You can specify global parameters in the default config file and have specific config files  per Domino partition.
So you can now use both config files in combination or just one of them.



V3.1.0 20.01.2016

New Features
------------

New command "clearlog"
Clears logs, custom logs and log backups as configured.
Optionally you can specify custom log cleanup days with two additional parameters.
First parameter defines log cut-off days for logs and second parameter defines cut-off days for backup logs.

New command "version" shows version of start script

New command "inivar" displays notes.ini setting specified

New command "ini" to edit the notes.ini of the server

New command "lastlog" shows last log lines. by default 100 lines are displayed.
Optionally you can specify the number of log lines

New command "service" for Linux enables/disables the Domino server "service".
Works for rc-systems and also systemd. Allows to check, enable, disable the service.

New command "stacks" runs NSD stacks only

New option for command "archivelog"

- additional parameter to specify an additional string to add to the archive log file name


New Parameters to enable new features

DOMINO_LOG_CLEAR_DAYS
Number of days until logs are cleared

DOMINO_LOG_BACKUP_CLEAR_DAYS
Number of days until backup logs are cleared

DOMINO_CUSTOM_LOG_CLEAR_SCRIPT
Custom log clear script will be used instead of the standard log clear operations and replaces all other clear operations!


DOMINO_COMPACT_TASK
Compact task can now be specified. By default "compact" is used.
Another option would be to use "dbmt" in Domino 9.

DOMINO_LOG_COMPACT_OPTIONS
Log compact options

DOMINO_LOG_START_COMPACT_OPTIONS
Start log compact options


DOMINO_LOG_DB_DAYS
Rename log database on startup after n days

DOMINO_LOG_DB_BACKUP_DIR
Target directory for rename log database on startup / default "log_backup" in data dir

Moving the log.nsf will be executed before starting the server and after startup compact/fixup operations
You can specify a directory inside or outside the Domino data directory


EDIT_COMMAND
------------

Option for the new "ini" command for changing the editor.


REMOVE_COMMAND_TEMP
-------------------
New option to specify a different command for removing old tempfiles on startup (default: "rm -f")


REMOVE_COMMAND_CLEANUP

New option to specify a different command for removing expired log files (default: "rm -f")


Changes
-------

DOMINO_REMOVE_TEMPFILES
The script only deletes *TMP files in data directory which are at least 1 day old to ensure no important files are deleted.


The "nsd" command by default will generate a NSD with memcheck -- full nsd
"fullnsd" command is removed from documentation but can still be used.
"nsdnomem" is now used to generate a NSD without memcheck.


Problems Solved
---------------
When checking resources (shared mem, MQs, Semaphores) the ipcs command in combination with grep is used to check the resources for a certain partition/user.
The ipcs command does not allow to specify a user-name. The was a potential issue when the login user-names where sub-strngs of each other.
Example "notes" and "notes1".  Even this is fixed it is still recommended to ensure that login names are not sub-strings of reach other.

V3.0.2 09.09.2015

New Features
------------

New DOMINO_START_FIXUP_OPTIONS to allow fixup before Domino server start
New DOMINO_FIXUP_OPTIONS to control fixup options when using the "fixup" and "restartfixup" commands

New command "fixup" to fixup when server is not started
New command "restartfixup" to terminate, fixup and start the server

The fixup options are mainly designed to compact system databases


V3.0.1 18.04.2015

Changes
-------
With systemd it is important that the "stop" command does stop the server and the server controller.
Systemd keeps track of all running processes of a service that is started.
Now "stop" does stop the controller. 

A new "quit" command has been introduced to stop Domino and keep the controller running.
But when you start the server again using the start script the controller is still restarted.
There is currently no way to start let the controller start the server from command line.
The only way to star the server is connecting to the server controller to star the server.

The command "stopjc" is not used any more and has been removed.

V3.0 01.03.2015

New Features
------------

Support for CentOS 7, RHEL 7 and SLES 12 including the new systemd that replaces the "rc-system".

New command "statusd" that can me used to show the status of the domino.service invoking rc_domino script.

New variable "DOMINO_ARCHIVE_LOGS_SHUTDOWN".
Set it to "yes" if you want logfiles already archived after Domino server shutdown.
Useful for example when your output file is located on a tmpfs.

New command "resources" which shows the resources of a running server (processes, MQs, SEMs, shared memory).


V2.8 10.02.2014

New Features
------------

New variable "DOMINO_SCRIPT_DIR" to have central location for all script files

New custom script option "DOMINO_CUSTOM_REMOVE_TEMPFILES_SCRIPT" to have a customizable way to remove temp files on server start
A sample script "remove_tempfiles_script" is included

New "DOMINO_PRE_STATUS_SCRIPT" script which will be executed before the server status is checked.
This can be helpful in case you want to check status for other tools like monitoring tools before you check the Domino server status.
The option does not directly impact the status of the Domino status and is mainly intended to add log output.

New option "DOMINO_CUSTOM_COMMAND_BASEPATH" to allow custom commands.
Commands that match a script name located in this directory will be executed.
This is a new optional way to plug-in your own commands without changing the code of the main script logic.

By default the script searches for a name in the format rc_domino_config_xxx where xxx is the UNIX user name of the Domino server.
The default name of the script shipped is still "rc_domino_config_xxx".
If this file does not exists, the script now checks for the default config file "rc_domino_config".
This is for example useful if you have multiple Domino partitions which use the same configuration and settings used
are derived from the variables set for the username ($DOMINO_USER).
  

Changes
-------
Changed the default locations for the pre/post/custom scripts in the config to $DOMINO_SCRIPT_DIR/"scriptname"
Removed very old SLES related code for the pthread extension support

V2.7 01.09.2013

New Features
------------

New Option DOMINO_3RD_PARTY_BIN_DIRS to allow "cleanup" to kill processes started from 3rd Party directories

Changes
-------
When you try to shutdown a Domino server the script checks now if the server is started at all before initiating the shutdown.
In previous versions this took a longer time because the loop for termination check was invoked anyway.
Also pre-shutdown scripts have been invoked which lead to a delay.
The script also skips post_shudown operations in this case.
You will see a message on the console that shutdown is skipped because the server is not started.
This will improve shutdown performance when the server was not started.


V2.6 03.01.2013

New Features
------------

New Option DOMINO_PRE_KILL_SCRIPT to allow invoking a script before "nsd -kill"
New Option DOMINO_POST_KILL_SCRIPT to allow invoking a script after "nsd -kill"

New Option DOMINO_PRE_CLEANUP_SCRIPT to allow invoking a script before cleaning up server resources native on OS level
New Option DOMINO_POST_CLEANUP_SCRIPT to allow invoking a script after cleaning up server resources native on OS level

Added Debug Output (BEGIN/END) for all pre/post scripts

V2.5 14.08.2012

New Features
------------

New Option DOMINO_TEMP_DIR to allow creation of the Notes Temp dir if not present

New DOMINO_START_COMPACT_OPTIONS to allow compact before Domino server start
New DOMINO_COMPACT_OPTIONS to control compact options when using the "compact" and "restartcompact" commands

New command "compact" to compact when server is not started
New command "restartcompact" to terminate, compact and start the server

The compact options are mainly designed to compact system databases


V2.4 10.04.2012

Problems Solved
---------------
Solved an issue when closing a terminal window while the monitor was running.
With some OS releases and some shells this caused that the script did not terminate due to issues in the shell.
This could lead to high CPU usage (100% for one core) for the script because the loop did not terminate.
The change to catch more events from the shell should resolve this issue.
If you still run into problems in this area, please send feedback.

V2.3 04.01.2012

New Features
------------

New Option DOMINO_TEMP_DIR to allow creation of the Notes Temp dir if not present
New Option DOMINO_LOG_DIR to allow creation of the Notes Log dir if not present
New Option DOMINO_DEBUG_FILE to allow use a debug file for start script debug output

V2.2 01.03.2011 

New Features
------------

New Option DOMINO_VIEW_REBUILD_DIR to allow creation of the view rebuild dir if not present

New Option DOMINO_PRE_SHUTDOWN_SCRIPT to allow invoking a script before shutting down the server
New Option DOMINO_POST_SHUTDOWN_SCRIPT to allow invoking a script after shutting down the server

New Option DOMINO_PRE_STARTUP_SCRIPT to allow invoking a script before starting the server
New Option DOMINO_POST_STARTUP_SCRIPT to allow invoking a script after starting the server


DOMINO_PRE_STARTUP_SCRIPT
--------------------------

this script is invoked before starting the server

DOMINO_POST_STARTUP_SCRIPT

Changes
-------

- Changed the default for the DOMINO_LANG variable. By default the variable was set to DE_de. 
  For current Linux versions the LANG variable is set to the UTF-8 setting instead of the older setting.
  There are some odd issues on Traveler servers when you use the older settings.
  Therefore the new default setting is to use the default settings for the user.
  The configuration file holds the UTF-8 version for German and English in comment strings to make it easier to enable them if needed.
  Example: #DOMINO_LANG=en_US.UTF-8


V2.1 01.11.2010

New Features
------------

New option to allow a pre-shutdown command before shutting down the server.
The command is configured via DOMINO_PRE_SHUTDOWN_COMMAND.
And there is also an optional delays time DOMINO_PRE_SHUTDOWN_DELAY.


V2.0 01.09.2010

Changes
-------

Changed the behavior of the "hang" function which now does now only dump call-stacks in the first 3 NSDs instead of NSD just without memcheck.
This can be a bit faster specially on larger servers. 

Problems Solved
---------------

Fixed and issue on Solaris with the tail command.
Some options of tail are only available in the POSIX version of the command-line and caused an issue during startup in one check
For Solaris the POSIX tail is located in /usr/xpg4/bin/tail.



V1.9 18.12.2008

New platform support for Ubuntu 8.0.4 LTS with Domino 8.5

Disclaimer: Domino is NOT supported on Ubuntu Linux. 
But because the Notes Client 8.5 is supported and the server and the client have many components in common including the NSD scripts it should work fine.


V1.8 04.04.2008

New Features
------------

- New option "live" that can be used for "start", "stop", "restart"
  The "live" option will combine the "monitor" command for start/stop of a server
  On the console you see the script output along with the live server output
  
- New command "hang"
  generate 3 NSDs without memcheck and one additional full NSD
  this option is needed collecting troubleshooting data for server hang analysis
  
- New option DOMINO_NSD_BEFORE_KILL="yes"  
  This option will generate a NSD before finally using NSD -kill to recycle the server.

- New termination check for the live console.
  you can now type "stop" to close the live console

Problems Solved
---------------

- fixed a live console termination issue mainly on RedHat


V1.7.3 07.11.2007

Problems Solved
---------------

The cleanup option was not enabled completely. Only processes have been cleaned-up.
Semaphores, MQs and shared memory have not cleaned up because the code was still commented out.
The routine did show the info about removing those resources but did not remove the resources.

V1.7.2 16.10.2007

Problems Solved
---------------

- Setting the LC_ALL variable to the user locale after it has been set to "POSIX" 
  by the run-level scripts on SLES (see V1.7.1 fixlist) was not a good idea.
  This causes other issues with Domino, NSD and memcheck.
  This fix unsets the LC_ALL variable and ensures that the LANG variable is set correctly.
  In addition it explicitly sets LC_ALL to "POSIX" when starting NSD.
  This avoids issues with tools that have language specific output.
  

V1.7.1 10.07.2007
-----------------

New Features
------------

- New command "cleanup"
  Remove hanging resources after a server crash
  (processes, shared memory, semaphores, message queues)

- New command "cmd"
  Issue console commands from the UNIX command line
  
- New command "memdump"
  Generate a memory dump from the currently running server. 

- New command Option "stop live" to show the live console on server shutdown

- New option to remove loadmon.ncf on startup of the server via DOMINO_RESET_LOADMON="yes"

- New option to remove temp-files from data-directory on startup via DOMINO_REMOVE_TEMPFILES="yes"

- New parameter DOMINO_LOG_DIR to specify a separate directory for logging (instead of the data directory)

- New parameter DOMINO_LOG_BACKUP_DIR to specify a separate directory for backing up log files (instead of the data directory)

- Have a check that "quit" and "exit" in lower-case in monitor console mode does not shutdown the server
  You have to type in the command in uppercase to shutdown the server because "exit" and "quit"
  are commonly used commands in a shell. Only those two reserved key-words are captured.
  All other abbreviations (like "q") still work.

- New variable DOMINO_DEBUG_MODE="yes" to help debugging start-script problems

- Crash detection on shutdown.
  The "stop" command does now monitor the server log-file for crashes during server shutdown.
  If a crash is detected the fault-recovery history is shown along with the name of the
  generated NSD file.

- Be more SLES RC compliant and always return nice RC error status

- Updated documentation and quick documentation

Changes
-------

- Changed default location of configuration file.
  The config file for the individual servers is now located in a Linux conform standard location
  /etc/sysconfig/rc_domino_config_$DOMINO_USER
  Example: /etc/sysconfig/rc_domino_config_notes
  On AIX you may have to create this directory.

- Rename archived log file. ".log" is now always the last part of the log-file name before the
  time-stamp to make it easier to open the log file in text editor after decompressing.


Problems Solved
---------------

- Fixed a problem in parameter processing of the rc_domino script when running with the same account
  (without using -su) in some environments the way the parameters are passed did not work with how
  the shell processed them
  
  Note: you need to replace your rc_domino scripts to get this fixed
  (the rc_domino script contains some logic that cannot be moved to the rc_domino_script)
  
- Platform SLES: Fixed a problem with the LANG variable that was not properly used by the server
  due to issues with the RC environment LC_ALL was set to "POSIX".
  This caused problems setting the locale in Domino (comma and decimal point issues).
  Now also LC_ALL is set explicitly to avoid incorrect locale setting in Domino due to the
  SuSE RC system.


V1.6 10.01.2007
---------------

- Support for RHEL 4.0 (and CentOS 4.3)
  RedHat uses "lock-files" in their RC system to keep track of started services
  This version of the script can use a lock file in /var/lock/subsys for RedHat and CentOS.
  Unfortunately files in /var/lock/subsys need root permissions to create/delete files. 
  Therefore on RedHat the start/stop/restart options need root permissions

  You have to run those scripts as "root". The script automatically switches to the
  right UNIX user name for the configured Domino partition
  
- Added information about a known issue in combination with SELinux when starting the
  server during the runlevel setup. 


V1.5 22.05.2006
---------------

- New option to configure all settings externally in one or multiple configuration files
  Either one per partition or a general config file, separated from the script logic

- Most companies using the script turned out to be on Linux
  "sh" is now the default shell for Linux. AIX administrators have to change 
  the shell in all scripts back to ksh
 
- Changed the default opt directory for Domino from /opt/lotus to /opt/ibm/lotus
  to reflect the new default for Domino 7.

- fixed a problem with NSD without memcheck (option nsd). if was calling nsd -info
  instead of nsd -nomemcheck


V1.4 02.04.2006
---------------

- Added code in rc_domino to handle a Solaris SIGHUB issue when started manually in the shell

- Added code in rc_domino to optional determine the UNIX user from RC script name (link)

- "NOTES_" is reserved. Therefore all variables have been changed from "NOTES_" to "DOMINO_"

- Removed a description line in the SuSE start-script configuration to allow multiple
  partitions started correctly using the RC package


V1.3 24.10.2005
---------------

- New DOMINO_OUTPUT_LOG and DOMINO_INPUT_FILE variables to define output and
  input log files per partition

- Configurable (exportable) NOTES_SHARED_DPOOLSIZE parameter per partition
  
- Start script debug variable (DOMINO_DEBUG_MODE="yes") does also enable NSD debug mode
  
- Fixed a problem on Linux where the 'ps' command was only reporting truncated
  process list entries depending on screen size
  The -w option of the ps command (on Linux only) is needed to provide a full
  list (else it is truncated after 80 chars)
  The resulting problem was that in some cases the domino_is_running function
  to report that the Domino server is not running

- New function "archivelog" for archiving the current text log-file


V1.2 15.10.2005
---------------

- Support for SuSE run-level editor in rc_domino script


---------------------
End of Change History
---------------------
