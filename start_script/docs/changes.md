
# Domino Start Script Change History

This file containers the change history for all start script components.  
Refere to the documentation for details. 

# Change History

## V3.7.0 09.01.2022

### New Features

- Documentation switched from readme.txt to markdown format with separate files on-line readable.
- Beta support for "setup auto configuration and templating". Detailed documentation follows.
  This version is intended to get the code out for preview.

## V3.6.2 04.12.2021

### Problems solved

Fixed an issue in start script installer for environments with more strict "umask" settings.

## V3.6.1 06.11.2021

### Changes

Beginning with this version the rc_domino script moved from /etc/init.d/rc_domino to /usr/bin/domino.
A symbolic link is created in the old standard location.

Some Linux distributions don't have a legacy /etc/init.d directory any more.
Also systemd environments don't need etc/init.d.

The script can still be still started from the old location. Just the locations swapped.

### Problems solved

The trap statement for the monitor command (live console) contained the wrong function.
This did not show up as an issue on most platforms but first showed up on Ubuntu.
With this change the live console also works on Ubuntu.

## V3.6.0 20.09.2021

### New Features

Support for One-touch Domino setup

Two new files in notesdata directory to allow to configure One-touch Domino setup

- DominoAutoConfig.env
- DominoAutoConfig.json

New command "setup" to configure the setup.

 ```
setup env
setup json
setup log
 ```

See detail in the "setup" configration section.

### Changes

- Removed support for init.d configurations.

- All supported Domino versions only run on platforms leveraging systemd.
- In a next step the rc_domino script will move from /etc/init.d directory to the start script directory /opt/nashcom/startscript.

- Removed old documentation about security limit pam configuration.

## V3.5.0 15.01.2021

### New Features

- Sametime 11 Community Server support
- New command "resetstlogs" to reset ST logs/diagnostics

The Sametime Community server as some additional search path requirements, which are added to the search path

## V3.4.0 01.09.2020

### Problems solved

- Fixed an issue with live console for server controller. The controller log file can have an absolue path.
- Routine now checks and prepends the data directory only if path is relative

Minor ### Changes for Docker

## V3.3.1 10.01.2020

### New Features

- New configuration variable DOMINO_ENV_FILE

- Environment file, which is particular useful for systemd environments, where the profile cannot be used to set variables, because systemd starts the process

- You can source in the file into your profile for processes starting from a shell and have it included into the server running under systemd.
systemd invokes rc_domino_script which sets the parameters if the configured file exists and can be read.

- Additional check for live console to ignore "e" and "q" to stop the server.
This helps to avoid  accidential server shutdowns. "qu", "ex" and other short-cuts for "quit" and "exit" will still work.

## V3.3.0 01.01.2020

### New Features

- Updated container support for other container environments than Docker (detecting other container run-time environments)
- Updated support for AIX including install script

### Changes

- Changed live console functionality
Up to now the live console wrote into the notes.input file which is connected to the server process (< input file).  
With the new functionality the commands are send to the server via server -c  "command".  
This change is intended to solve an issue with a stall console in some situations.  
In addition this allows live console functionality also in combination with the server controller.  
The script detects the current server controller file (via notes.ini setting DominoControllerCurrentLog).  
You can switch to the previous behavior via DOMINO_CONSOLE_SERVERC=NO.

- Removed legacy configuration from rc_domino_script, which was confusing

## V3.2.2 16.05.2019

### New Features

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

`DOMINO_TIKA_SHUTDOWN_TERM_SECONDS`

Tries to shutdown the Tika index server during shutdown.  
It can happen that the Tika server does not terminate, which prevents the Domino server from shutting down properly.

Default 30 seconds.

`DOMINO_SHUTDOWN_DELAYED_SCRIPT`

Script which can be executed delayed during shutdown.  
`DOMINO_SHUTDOWN_DELAYED_SECONDS` specifies the number of seconds after shutdown start (default 20 seconds).

Docker Support:

Now the entry point script checks if the script is already started with the right user and will not switch to the user.
There are configuration options on the Docker side to run the entry point script directly with the right user.
When you switch the user to "notes" at the end of your dockerfile, the container is started with "notes".
This provides better security.

### Problems solved

restartcompact and restartfixup did not work correctly with systemd.
For systemd the rc_domino script needs to stop the service run compact/fixup and restart the service.

## V3.2.1 02.03.2019

### Problems solved

The configuration DOMINO_UMASK was enabled by default.

### New Features

Instead of renaming log databases this new feature allows to delete log databases.

The new functionality is available for the following configuration parameters:

```
DOMINO_LOG_DB_BACKUP
DOMINO_DOMLOG_DB_BACKUP_DIR
```

Instead of specifying a target database you specify "DELETEDB" to remove the database on restart.

## V3.2.0 30.10.2018

### New Features

- The start script was always free. To ensure everyone can use it, it is now available under the Apache License, Version 2.0. All files of the start script now contain the required header.

- Introducing Domino Docker support!  
The start script wasn't completely ready for Domino on Docker.  
There are special requirements when running in an Docker environment.  
The start script now includes a Docker entrypoint file to start and stop the server.  
See details in the Docker Support section of the start script.  

- New command 'log' -- displays the start script output log.  
This command can be used with additional options like specifying the command to open the log (e.g. 'log more'). See log command description for details.

- New command 'systemdcfg' to edit the systemd configuration file

- New command 'compactnextstart' which allows you to configure a one time compact at next startup.  
For example after an OS patch day. The new command allows you to enable/disable/display the settings.  
Check the command documentation for details.

- New config variables DOMINO_DOMLOG_DB_DAYS, DOMINO_DOMLOG_DB_BACKUP_DIR which can move domlog.nsf to a backup directory.  
This works like the log.nsf backup/rename introduced earlier.

- New config variable DOMINO_UMASK.  
And also allow to set the umask when starting the server via DOMINO_UMASK.

- New variable DOMINO_LOG_DB_BACKUP to set a fixed log.nsf backup file to have one additional version of log.nsf instead of creating multiple versions with date-stamp. Works in combination with DOMINO_LOG_DB_DAYS.

- New variable DOMINO_DOMLOG_DB_BACKUP to set a fixed domlog.nsf backup file to have one additional version of domlog.nsf
instead of creating multiple versions with date-stamp. Works in combination with DOMINO_DOMLOG_DB_DAYS.

- Show the umask used in the startup log of the server (along with environment and ulimits etc).

- Separate, simple script 'install_script' that will allow you to install the start script for default configurations.

### Changes

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
But using variables does only work for parameters passed to a an ExecStart/ExecStop command but not for the name of those scripts invoked. Also it is not directly sourcing the parameters but reading them directly.  
So there seems to be no way to read the config of domino.service from the config file and I had to "hardcode" the filenames.

## V3.1.3 30.10.2017

### Problems solved

Fixed an issue with systemd in combination with server controller.
Now the server controller correctly shutdown when the service is stopped

### New Features

listini -- displays server's notes.ini

### Changes

Changed sample rc_domino_config_notes setting DOMINO_PRE_SHUTDOWN_COMMAND to "tell traveler shutdown"

## V3.1.2 01.09.2017

### New Features

New check if Domino ".res" files exist and readable to generate warnings

New short cut command "res" for "resources"

### Changes

In previous version either the server specific config file was used or the default config file.

The config files are now used in the following order to allow more flexible configurations:

- First the default config-file is loaded if exists (by default: /etc/sysconfig/rc_domino_config)
- In the next step the server specific config-file (by default: /etc/sysconfig/rc_domino_config_notes) is included.
- The server specific config file can add or overwrite configuration parameters.

This allows very flexible configurations. You can specify global parameters in the default config file and have specific config files  per Domino partition.
So you can now use both config files in combination or just one of them.

## V3.1.0 20.01.2016

### New Features

- New command "clearlog"
Clears logs, custom logs and log backups as configured.
Optionally you can specify custom log cleanup days with two additional parameters.
First parameter defines log cut-off days for logs and second parameter defines cut-off days for backup logs.

- New command "version" shows version of start script

- New command "inivar" displays notes.ini setting specified

- New command "ini" to edit the notes.ini of the server

- New command "lastlog" shows last log lines. by default 100 lines are displayed.
Optionally you can specify the number of log lines

- New command "service" for Linux enables/disables the Domino server "service".
Works for rc-systems and also systemd. Allows to check, enable, disable the service.

- New command "stacks" runs NSD stacks only

- New option for command "archivelog"

- additional parameter to specify an additional string to add to the archive log file name

New Parameters to enable new features  

- DOMINO_LOG_CLEAR_DAYS  
  Number of days until logs are cleared  
- DOMINO_LOG_BACKUP_CLEAR_DAYS  
  Number of days until backup logs are cleared

- DOMINO_CUSTOM_LOG_CLEAR_SCRIPT  
  Custom log clear script will be used instead of the standard log clear operations and replaces all other clear operations!

- DOMINO_COMPACT_TASK  
  Compact task can now be specified. By default "compact" is used.
  Another option would be to use "dbmt" in Domino 9.

- DOMINO_LOG_COMPACT_OPTIONS  
  Log compact options

- DOMINO_LOG_START_COMPACT_OPTIONS  
  Start log compact options

- DOMINO_LOG_DB_DAYS  
  Rename log database on startup after n days

- DOMINO_LOG_DB_BACKUP_DIR  
  Target directory for rename log database on startup / default "log_backup" in data dir

- Moving the log.nsf will be executed before starting the server and after startup compact/fixup operations.
  You can specify a directory inside or outside the Domino data directory

- EDIT_COMMAND  
  Option for the new "ini" command for changing the editor.

- REMOVE_COMMAND_TEMP  
  New option to specify a different command for removing old tempfiles on startup (default: "rm -f")

- REMOVE_COMMAND_CLEANUP  
  New option to specify a different command for removing expired log files (default: "rm -f")

### Changes

DOMINO_REMOVE_TEMPFILES
The script only deletes *TMP files in data directory which are at least 1 day old to ensure no important files are deleted.

The "nsd" command by default will generate a NSD with memcheck -- full nsd
"fullnsd" command is removed from documentation but can still be used.
"nsdnomem" is now used to generate a NSD without memcheck.

### Problems solved

When checking resources (shared mem, MQs, Semaphores) the ipcs command in combination with grep is used to check the resources for a certain partition/user.  
The ipcs command does not allow to specify a user-name. The was a potential issue when the login user-names where sub-strngs of each other.  
Example "notes" and "notes1".  Even this is fixed it is still recommended to ensure that login names are not sub-strings of reach other.

## V3.0.2 09.09.2015

### New Features

New DOMINO_START_FIXUP_OPTIONS to allow fixup before Domino server start.  
New DOMINO_FIXUP_OPTIONS to control fixup options when using the "fixup" and "restartfixup" commands.

New command "fixup" to fixup when server is not started.  
New command "restartfixup" to terminate, fixup and start the server.

The fixup options are mainly designed to compact system databases

## V3.0.1 18.04.2015

### Changes

With systemd it is important that the "stop" command does stop the server and the server controller.
Systemd keeps track of all running processes of a service that is started.
Now "stop" does stop the controller.

A new "quit" command has been introduced to stop Domino and keep the controller running.
But when you start the server again using the start script the controller is still restarted.
There is currently no way to start let the controller start the server from command line.
The only way to star the server is connecting to the server controller to star the server.

The command "stopjc" is not used any more and has been removed.

## V3.0 01.03.2015

### New Features

Support for CentOS 7, RHEL 7 and SLES 12 including the new systemd that replaces the "rc-system".

New command "statusd" that can me used to show the status of the domino.service invoking rc_domino script.

New variable "DOMINO_ARCHIVE_LOGS_SHUTDOWN".
Set it to `yes` if you want logfiles already archived after Domino server shutdown.
Useful for example when your output file is located on a tmpfs.

New command "resources" which shows the resources of a running server (processes, MQs, SEMs, shared memory).

## V2.8 10.02.2014

### New Features

New variable "DOMINO_SCRIPT_DIR" to have central location for all script files

New custom script option "DOMINO_CUSTOM_REMOVE_TEMPFILES_SCRIPT" to have a customizable way to remove temp files on server start.

A sample script "remove_tempfiles_script" is included

New "DOMINO_PRE_STATUS_SCRIPT" script which will be executed before the server status is checked.
This can be helpful in case you want to check status for other tools like monitoring tools before you check the Domino server status. The option does not directly impact the status of the Domino status and is mainly intended to add log output.

New option "DOMINO_CUSTOM_COMMAND_BASEPATH" to allow custom commands. Commands that match a script name located in this directory will be executed. This is a new optional way to plug-in your own commands without changing the code of the main script logic.

By default the script searches for a name in the format rc_domino_config_xxx where xxx is the UNIX user name of the Domino server.  The default name of the script shipped is still "rc_domino_config_xxx".  

If this file does not exists, the script now checks for the default config file "rc_domino_config".  

This is for example useful if you have multiple Domino partitions which use the same configuration and settings used
are derived from the variables set for the username ($DOMINO_USER).

### Changes

Changed the default locations for the pre/post/custom scripts in the config to $DOMINO_SCRIPT_DIR/"scriptname"
Removed very old SLES related code for the pthread extension support

## V2.7 01.09.2013

### New Features

New Option DOMINO_3RD_PARTY_BIN_DIRS to allow "cleanup" to kill processes started from 3rd Party directories

### Changes

When you try to shutdown a Domino server the script checks now if the server is started at all before initiating the shutdown.
In previous versions this took a longer time because the loop for termination check was invoked anyway.
Also pre-shutdown scripts have been invoked which lead to a delay.
The script also skips post_shudown operations in this case.
You will see a message on the console that shutdown is skipped because the server is not started.
This will improve shutdown performance when the server was not started.

## V2.6 03.01.2013

### New Features

New Option DOMINO_PRE_KILL_SCRIPT to allow invoking a script before "nsd -kill"
New Option DOMINO_POST_KILL_SCRIPT to allow invoking a script after "nsd -kill"

New Option DOMINO_PRE_CLEANUP_SCRIPT to allow invoking a script before cleaning up server resources native on OS level
New Option DOMINO_POST_CLEANUP_SCRIPT to allow invoking a script after cleaning up server resources native on OS level

Added Debug Output (BEGIN/END) for all pre/post scripts

## V2.5 14.08.2012

### New Features

- New Option DOMINO_TEMP_DIR to allow creation of the Notes Temp dir if not present
- New DOMINO_START_COMPACT_OPTIONS to allow compact before Domino server start  
- New DOMINO_COMPACT_OPTIONS to control compact options when using the "compact" and "restartcompact" commands

- New command "compact" to compact when server is not started  
- New command "restartcompact" to terminate, compact and start the server
- The compact options are mainly designed to compact system databases

## V2.4 10.04.2012

### Problems solved

Solved an issue when closing a terminal window while the monitor was running.  
With some OS releases and some shells this caused that the script did not terminate due to issues in the shell.  
This could lead to high CPU usage (100% for one core) for the script because the loop did not terminate.  
The change to catch more events from the shell should resolve this issue.  
If you still run into problems in this area, please send feedback.

## V2.3 04.01.2012

### New Features

- New Option DOMINO_TEMP_DIR to allow creation of the Notes Temp dir if not present
- New Option DOMINO_LOG_DIR to allow creation of the Notes Log dir if not present
- New Option DOMINO_DEBUG_FILE to allow use a debug file for start script debug output

## V2.2 01.03.2011

### New Features

- New Option DOMINO_VIEW_REBUILD_DIR to allow creation of the view rebuild dir if not present
- New Option DOMINO_PRE_SHUTDOWN_SCRIPT to allow invoking a script before shutting down the server
- New Option DOMINO_POST_SHUTDOWN_SCRIPT to allow invoking a script after shutting down the server

- New Option DOMINO_PRE_STARTUP_SCRIPT to allow invoking a script before starting the server
- New Option DOMINO_POST_STARTUP_SCRIPT to allow invoking a script after starting the server

- DOMINO_PRE_STARTUP_SCRIPT
  this script is invoked before starting the server

- DOMINO_POST_STARTUP_SCRIPT
  this script is invoked after starting the server

### Changes

- Changed the default for the DOMINO_LANG variable. By default the variable was set to DE_de.

For current Linux versions the LANG variable is set to the UTF-8 setting instead of the older setting.
 There are some odd issues on Traveler servers when you use the older settings.
Therefore the new default setting is to use the default settings for the user.
The configuration file holds the UTF-8 version for German and English in comment strings to make it easier to enable them if needed.

  Example: 
  
 ```
  DOMINO_LANG=en_US.UTF-8
 ```

## V2.1 01.11.2010

### New Features

New option to allow a pre-shutdown command before shutting down the server.
The command is configured via DOMINO_PRE_SHUTDOWN_COMMAND.
And there is also an optional delays time DOMINO_PRE_SHUTDOWN_DELAY.

## V2.0 01.09.2010

### Changes

Changed the behavior of the "hang" function which now does now only dump call-stacks in the first 3 NSDs instead of NSD just without memcheck.
This can be a bit faster specially on larger servers.

### Problems solved

Fixed and issue on Solaris with the tail command.
Some options of tail are only available in the POSIX version of the command-line and caused an issue during startup in one check. For Solaris the POSIX tail is located in /usr/xpg4/bin/tail.

## V1.9 18.12.2008

New platform support for Ubuntu 8.0.4 LTS with Domino 8.5

Disclaimer: Domino is NOT supported on Ubuntu Linux.
But because the Notes Client 8.5 is supported and the server and the client have many components in common including the NSD scripts it should work fine.

## V1.8 04.04.2008

### New Features

- New option "live" that can be used for "start", "stop", "restart"
  The "live" option will combine the "monitor" command for start/stop of a server
  On the console you see the script output along with the live server output

- New command "hang"
  generate 3 NSDs without memcheck and one additional full NSD
  this option is needed collecting troubleshooting data for server hang analysis

- New option DOMINO_NSD_BEFORE_KILL=yes
  This option will generate a NSD before finally using NSD -kill to recycle the server.

- New termination check for the live console.
  you can now type "stop" to close the live console

### Problems solved

- fixed a live console termination issue mainly on RedHat

## V1.7.3 07.11.2007

### Problems solved

The cleanup option was not enabled completely. Only processes have been cleaned-up.  
Semaphores, MQs and shared memory have not cleaned up because the code was still commented out.  
The routine did show the info about removing those resources but did not remove the resources.

## V1.7.2 16.10.2007

### Problems solved

Setting the LC_ALL variable to the user locale after it has been set to "POSIX" by the run-level scripts on SLES (see V1.7.1 fixlist) was not a good idea.  
This causes other issues with Domino, NSD and memcheck.  
This fix unsets the LC_ALL variable and ensures that the LANG variable is set correctly.  
In addition it explicitly sets LC_ALL to "POSIX" when starting NSD.  
This avoids issues with tools that have language specific output.

## V1.7.1 10.07.2007

### New Features

- New command "cleanup"
  Remove hanging resources after a server crash
  (processes, shared memory, semaphores, message queues)

- New command "cmd"
  Issue console commands from the UNIX command line

- New command "memdump"
  Generate a memory dump from the currently running server.

- New command Option "stop live" to show the live console on server shutdown

- New option to remove loadmon.ncf on startup of the server via DOMINO_RESET_LOADMON=yes

- New option to remove temp-files from data-directory on startup via DOMINO_REMOVE_TEMPFILES=yes

- New parameter DOMINO_LOG_DIR to specify a separate directory for logging (instead of the data directory)

- New parameter DOMINO_LOG_BACKUP_DIR to specify a separate directory for backing up log files (instead of the data directory)

- Have a check that "quit" and "exit" in lower-case in monitor console mode does not shutdown the server
  You have to type in the command in uppercase to shutdown the server because "exit" and "quit"
  are commonly used commands in a shell. Only those two reserved key-words are captured.
  All other abbreviations (like "q") still work.

- New variable DOMINO_DEBUG_MODE=yes to help debugging start-script problems

- Crash detection on shutdown.
  The "stop" command does now monitor the server log-file for crashes during server shutdown.
  If a crash is detected the fault-recovery history is shown along with the name of the
  generated NSD file.

- Be more SLES RC compliant and always return nice RC error status

- Updated documentation and quick documentation

### Changes

- Changed default location of configuration file.
  The config file for the individual servers is now located in a Linux conform standard location
  /etc/sysconfig/rc_domino_config_$DOMINO_USER
  Example: /etc/sysconfig/rc_domino_config_notes
  On AIX you may have to create this directory.

- Rename archived log file. ".log" is now always the last part of the log-file name before the
  time-stamp to make it easier to open the log file in text editor after decompressing.

### Problems solved

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

## V1.6 10.01.2007

- Support for RHEL 4.0 (and CentOS 4.3)  
  RedHat uses "lock-files" in their RC system to keep track of started services  
  This version of the script can use a lock file in /var/lock/subsys for RedHat and CentOS.  
  Unfortunately files in /var/lock/subsys need root permissions to create/delete files.  
  Therefore on RedHat the start/stop/restart options need root permissions.

  You have to run those scripts as "root". The script automatically switches to the  right UNIX user name for the configured Domino partition

- Added information about a known issue in combination with SELinux when starting the server during the runlevel setup.

## V1.5 22.05.2006

- New option to configure all settings externally in one or multiple configuration files.  
  Either one per partition or a general config file, separated from the script logic

- Most companies using the script turned out to be on Linux.  
  "sh" is now the default shell for Linux. AIX administrators have to change the shell in all scripts back to ksh.

- Changed the default opt directory for Domino from /opt/lotus to /opt/ibm/lotus to reflect the new default for Domino 7.

- fixed a problem with NSD without memcheck (option nsd). if was calling nsd -info instead of nsd -nomemcheck

## V1.4 02.04.2006

- Added code in rc_domino to handle a Solaris SIGHUB issue when started manually in the shell

- Added code in rc_domino to optional determine the UNIX user from RC script name (link)

- "NOTES_" is reserved. Therefore all variables have been changed from "NOTES_" to "DOMINO_"

- Removed a description line in the SuSE start-script configuration to allow multiple partitions started correctly using the RC package

## V1.3 24.10.2005

- New DOMINO_OUTPUT_LOG and DOMINO_INPUT_FILE variables to define output and input log files per partition

- Configurable (exportable) NOTES_SHARED_DPOOLSIZE parameter per partition

- Start script debug variable (DOMINO_DEBUG_MODE=yes) does also enable NSD debug mode

- Fixed a problem on Linux where the 'ps' command was only reporting truncated process list entries depending on screen size
  The -w option of the ps command (on Linux only) is needed to provide a full list (else it is truncated after 80 chars).  
  The resulting problem was that in some cases the domino_is_running function  to report that the Domino server is not running

- New function "archivelog" for archiving the current text log-file

## V1.2 15.10.2005

- Support for SuSE run-level editor in rc_domino script
