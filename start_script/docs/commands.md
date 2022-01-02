# Domino Start Script Commands

Start Script commands provide the functionality of the start script.  
Refer to the parameter configuration for customization.

## start

Starts the Domino server and archives the last OS-level Domino output-file.  
The output-file is renamed with a time-stamp and compressed using the configured compression tool.  
 Compressing the log file is invoked in background to avoid slowing down the server start when compressing large log-files.  
The start operation does clear the console input file and logs information about the UNIX user environment and the security limits of the Unix user.

## start live

Same as `start` but displays the live console at restart. See `monitor` command for details

## stop

Stops the Domino server via server -q and waits a given grace period (configurable via DOMINO_SHUTDOWN_TIMEOUT -- default 10 minutes).

After this time the Domino server is killed via NSD if it cannot be shutdown and processes are still ruining after this time (see "kill" command below).

The Java controller will also be shutdown (if used).  
This is specially important when invoking a shutdown on systems using systemd.  
If you specify `stop live` the live console is shown during shutdown.

## stop live

Same as `stop` but displays the live console during shutdown.  
The live console is automatically closed after shutdown of the server  
See `monitor` command for details

## quit

Stops the Domino server via `server -q` and waits a given grace period (configurable via `DOMINO_SHUTDOWN_TIMEOUT` -- default 10 minutes).  
After this time the Domino server is killed via NSD if it cannot be shutdown and processes are still ruining after this time (see `kill` command below).  
The Java controller remains active if configured.

## restart

Stops the Domino server and restarts it using `stop` and `start` command with all implications and specially the time-out values for "stop".

## restart live

Same as `restart` but displays the live console for server/start stop.  
See `monitor` command for details

## status

Checks if the Domino server is running and prints a message.

Return code of the script:

```
 0 = server is not running
 3 = server is running
```

## statusd

systemd has a very nice and detailed status command.  
The default status check remains the status the existing status command.  
This command is used to show the systemd status for the domino.service.  
(the systemd command would be: `systemctl status domino.service`

## tika stop|kill

Shows the Tika server status and can be used to terminate the process.  
Without additional parameters this command shows the status of the Tiker server process.

```
tika stop -> stops the Tika server process
tika kill -> kills the Tika server process
```

## service

Enables, Disables and shows the startup status of the service.  
This command works on Linux only for rc-system and also systemd.  
It is implemented in the `rc_domino` entry script.  

```
service on -> enables the service
service off -> disables the service
service add -> deletes the service
service del -> deletes the service
service -> shows the startup status of the service
```

## monitor

Attaches to the output and the input files of a running Domino server and allows a kind of live console from a telnet/ssh session using the input and output files. `stop` terminates the live console.

## cmd

Issue console commands from the linux command line.  

Syntax:

```
rc_domino cmd "command" [n log lines]
```

The command needs to be specified in double-quotes like shown above.  
The optional parameter log lines can be used to print the last n lines of log file (via tail) after waiting 5 seconds for the command to finish.

Example:

```
rc_domino cmd "show server" 200
```

Issues a remote console command, waits 5 seconds and displays the last 200 lines

Note: Command parameters always need to be enclosed in quotes.

`rc_domino` passes the parameters with quotes to the main `rc_domino_script`.  
But if you are using another script or other binary that calls rc_domino (for example service), the parameters might not be enclosed in quotes any more.  
The rc_domino script requires that you have the parameters in quotes.  
Every blank will be interpreted as a delimiter for a new parameter.

## version

Shows version of start script

## inivar

Displays notes.ini setting specified.

Example:

```
rc_domino inivar server_restricted
```

## ini

Edit the notes.ini of the server. `vi` is the default editor which can be changed via ```EDIT_COMMAND``` config setting.

Note: You should not edit the notes.ini while the server is running.  
You might corrupt the notes.ini. For a running server use "set config .. " on the server console instead.  
Also take care with umlauts and other special characters.  
In this case it is always recommended to use "set config" on a Notes Client instead because this will ensure that
the characters are converted correctly.

## listini

Lists server's notes.ini. You can use this command to show the notes.ini or redirect the output to a grep command

## config/cfg

Edit the start script configuration.  
By default if no specific server/user configuration is present the default config is edited.  
You can either specify config '`server`' or config '`default`' for the different configurations.

The two options are:

```
config server
config default
```

## systemdcfg

Edit the systemd config file.

## log

Show or edit the log file. By default `vi` is used to edit the log file.  
Optionally you can specify your own command e.g. `log` more or `log head -100`

## lastlog

Shows last log lines. by default **100 lines** are displayed.  
Optionally you can specify the number of log lines.

## systemlog

Shows last system log lines for the service from systemd. by default 100 lines are displayed.  
Optionally you can specify the number of log lines.

## archivelog

Archives the current server text log-file. The file is copied, compressed and the current log file is set to an empty file without losing the current file-handles of the server process.  
There might be a very short log file interruption between copying the file and setting it to an empty file.  
The new log file contains a log-line showing the archived log file name.

You can add a string to the archive log name as an additional parameter.  
This can be useful if you have enabled debugging and want to capture an error situation.  
 In that case run archivelog before and run it afterwards with a string as an additional parameter which will be added to the file name of the zip.

## clearlog

Clears logs, custom logs and log backups as configured.

Optionally you can specify custom log cleanup days with two additional parameters.  
First parameter defines log cut-off days for logs and second parameter defines cut-off days for backup logs.

Example:

```
rc_domino clearlog 30 90
```

Clears logs with 30 days expiration and clears backup logs with 90 days expiration independent of the configured days.  
In normal cases you would just use "clearlog" without parameters and specify expiration settings in the configuration.

`clearlog` uses the following logic:

- If `DOMINO_CUSTOM_LOG_CLEAR_SCRIPT` is configured only the custom clear script is used else the following logic applies.

- If `DOMINO_LOG_CLEAR_DAYS` is set the following files will be removed if they meet the expiration times specified:

- If `DOMINO_LOG_PATH` is set expired files are removed from this directory and sub-directories.  
  Else all expired files from `/local/notesdata/IBM_TECHNICAL_SUPPORT` and sub-directories are removed.

- If `DOMINO_LOG_BACKUP_CLEAR_DAYS` is set the following files will be removed if they meet the expiration times specified:

  If `DOMINO_LOG_BACKUP_DIR` is set the following expired files are removed from this directory

  $DOMINO_USER_*.log.gz

  Example:
  
  ```
  notes_*.log.gz
  ```

  Else the same file pattern is used to remove files from the data-directory.

- If `DOMINO_CUSTOM_LOG_CLEAR_DAYS` is set and also `DOMINO_CUSTOM_LOG_CLEAR_PATH` is set all expired files from
  this directory and sub-directories are removed that meet the specified expiration days

## nsd

Generates a full NSD including call-stacks and memcheck.  
You can pass additional parameters to NSD.

## nsdnomem

Generates a NSD without memcheck (nsd -nomemcheck).

## info

Generates a sysinfo style NSD (nsd -info).

## kill

Terminates the Domino server (nsd -kill)

## resources (res)

Shows the resources that the server uses. This includes processes, shared memory, MQs, semaphores.  
The resources are checked on OS level and list the same information that is used by the `cleanup` command below.
The command is useful for a running server but also for a crashed server to check which resources might not have been cleaned up by fault recovery.

## cleanup

Remove hanging resources after a server crash (processes, shared memory, semaphores, message queues).

In contrast to the `NSD -kill` option this routine removes ALL resources.  
This includes all message queues, shared memory, semaphores allocated by the UNIX user used by the Domino server instance.

And also removes all processes started from the server binary directory (e.g. `/opt/hcl/domino`).  
NSD currently does only remove registered resources in the following files:  

```
pid.nbf, mq.nbf, sem.nbf, shm.nbf
```

So this command is mainly useful if NSD cannot remove all resources due to corruptions or add-on programs or any other odd situation. It prevents you from having to manually remove resources and processes in such a corrupt state.

Note: Resources allocated by add-on applications using native OS-level operations are not registered.

## memdump

Generate a memory dump from the currently running server.

## hang

Generate 3 NSDs collecting the call-stacks (nsd -stacks) and one additional full NSD.  
This option is needed collecting troubleshooting data for server hang analysis.

## stacks

Generate one NSD with call-stacks only (nsd -stacks)

## compact

Runs compact when server is shutdown (if the server is started an error message is displayed, you have to shutdown the server first).  
Needs `DOMINO_COMPACT_OPTIONS` to be configured and is mainly intended for system databases.

## restartcompact

Terminates the server, runs compact and restarts the server.  
Needs `DOMINO_COMPACT_OPTION` to be configured and is mainly intended for system databases.

## fixup

Runs fixup when server is shutdown (if the server is started an error message is displayed, you have to shutdown the server first).  
Needs DOMINO_FIXUP_OPTIONS to be configured and is mainly intended for system databases.

## restartfixup

Terminates the server, runs fixup and restarts the server.  
Needs `DOMINO_FIXUP_OPTIONS` to be configured and is mainly intended for system databases.

## compactnextstart on|off|status

Allows you to configure one time compacting databases at next startup.  
This functionality controls a text file 'domino_nextstartcompact' in your data directory.  
If this file is present, the compact operations specified via the following settings are executed at next start

- DOMINO_COMPACT_TASK
- DOMINO_COMPACT_OPTIONS
- DOMINO_LOG_COMPACT_OPTIONS

The `domino_nextstartcompact` will be deleted at next startup.

This is for example to be intended to be used after a planned OS reboot or OS patch.  
And it avoids separate steps executed by the OS level admin.

```
compactnextstart on  --> enables the compact at next startup
compactnextstart off --> disables the compact at next startup
```

Specifying no or any other option will show the current settings.

The status file used by default is domino_nextstartcompact in data directory.
If this file is present the compact operations will run once and remove the file.

## resetstlogs

Reset Sametime Community server logs/diags as used in the ststart script
