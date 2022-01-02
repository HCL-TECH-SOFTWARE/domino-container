# Configuration Parameters

Parameters are specified in the configuration file `/etc/sysconfig/rc_domino_config`.  
The configuration shipped with the start script comes with reasonable defaults.  

## DOMINO_USER (required)

User-variable automatically set to the OS level user (indirect configuration)

## LOTUS (required)

Domino installation directory (usual `/opt/hcl/domino`)
This is the main variable which needs to be set for binaries

Default: `/opt/hcl/domino`

## DOMINO_DATA_PATH (required)

Data-Directory
Default: `/local/notesdata`

## DOMINO_CONFIGURED (required)

Configuration variable. Needs to be set to `yes` per user to confirm that the environment for this user is setup correctly.

## DOMINO_LANG

Language setting used to determine local settings
(e.g. decimal point and comma)

Examples:

```
DOMINO_LANG=en_US.UTF-8
```

Default: not set --> uses the setting of the UNIX/Linux user

## DOMINO_ENV_FILE

Environment file, which is particular useful for systemd environments, where the profile cannot be used to set variables, because systemd starts the process.   
You can source in the file into your profile for processes starting from a shell and have it included into the server running under systemd.  
systemd invokes `rc_domino_script` which sets the parameters if the configured file exists and can be read.

## DOMINO_UMASK

umask used when creating new files and folders. Usually this is set in the profile of the user but can be also set here for flexibility

Examples:

```
DOMINO_UMASK=0077
```

Default: not set --> Uses the setting of the UNIX/Linux user

## DOMINO_SHUTDOWN_TIMEOUT

Grace period in seconds (default: 600) to allow to wait until the Domino server should shutdown. After this time nsd -kill is used to terminate the server.

## DOMINO_LOG_DIR

Output log file directory for domino log files.  
Default: `DOMINO_DATA_PATH`

## DOMINO_OUTPUT_LOG

Output log file used to log Domino output into a OS-level log file (used for troubleshooting and the "monitor" option).  
Default: `$DOMINO_USER.log` in data-directory

## DOMINO_INPUT_FILE

Input file for controlling the Domino server (used for "monitor" option)  
Default: `$DOMINO_USER.input` in data-directory

## DOMINO_LOG_BACKUP_DIR

Output log file backup directory for domino log files for archiving log files.  
Default: `DOMINO_DATA_PATH`

## DOMINO_ARCHIVE_LOGS_SHUTDOWN

Archive logs after Domino server is shutdown.  
This operation runs after the server is shutdown and before a DOMINO_POST_SHUTDOWN_SCRIPT is executed.  
Specify `yes` to enable this option.

The option could be helpful specially when the Domino output files are written to a tmpfs.  
In combination with setting a different location for the DOMINO_LOG_BACKUP_DIR those files could be saved to a normal disk while at run-time the files are still written to a normal disk.

## DOMINO_USE_JAVA_CONTROLLER

Use the Java Controller to manage the Domino server.  
Specify `yes` to enable this option.

When using the Java Server Controller the "monitor" command cannot be used because the Domino Java Server Controller does handle all the console input/output and writes to separate files.

## COMPRESS_COMMAND

Command that is used to compress log files. There might be different options possible depending on your platform and your installed software

e.g. compress, zip, gzip, ...  
(Default: "gzip --best").

## EDIT_COMMAND

By default "vi" is used to edit files via start script.  
This option can be used to change the edit command to for example "mcedit" instead.

## REMOVE_COMMAND_TEMP

By default "rm -f" is used to remove temporary files.  
You can change this in case you want special checking or archiving etc.

## REMOVE_COMMAND_CLEANUP

By default "rm -f" is used to remove files that should be cleaned up when they are expired.  
You can change this in case you want special checking or archiving etc.
This would be specially useful for archiving.  
But you could also change it for example to "ls -l" to test which files would be removed during cleanup.

## DOMINO_DEBUG_MODE

Enabling the debug mode via DOMINO_DEBUG_MODE=`yes` allows to trace and troubleshoot the start script. Enable this option only for testing!

## DOMINO_DEBUG_FILE

When you enable the debug mode debug output is written to the console.  
This option allows to specify a separate debug output file.  
Note: Works in combination with DOMINO_DEBUG_MODE=`yes`

## DOMINO_RESET_LOADMON (default)

Domino calculates the Server Availability Index (SAI) via LoadMon by calculating the current transaction times and the minimum transactions times which are stored in loadmon.ncf when the server is shutdown.  
This file can only be deleted when the server is showdown.  

Enable this option (DOMINO_RESET_LOADMON=`yes`) to remove loadmon.ncf at server startup

Note: When using this option you will only see a loadmon.ncf in the data directory,
when the server is down, because it will be only written at server shutdown time.

## DOMINO_CUSTOM_COMMAND_BASEPATH (expert)

This option allows you to specify a directory which is used for custom commands.  
If a command which is specified when invoking the script matches a script name which is present in the specified directory (and if the script can be executed) the custom command will execute the script passing all current parameters of the current command.  
This is a new flexible way to plug-in your own commands without changing the code of the main script logic.

## DOMINO_NSD_BEFORE_KILL (default)

Generates a NSD before finally using NSD -kill to recycle the server.
This is specially interesting to troubleshoot server shutdown issues.
Therefore the option is enabled by default in current configuration files.
Enable this option via (DOMINO_NSD_BEFORE_KILL=`yes`)

## DOMINO_REMOVE_TEMPFILES

Enable this option (DOMINO_REMOVE_TEMPFILES=`yes`) to remove temp-files from notesdata-directory and if configured from ` DOMINO_VIEW_REBUILD_DIR` at server startup.

The following files are removed:

- *.DTF
- *.TMP

## !Caution!

Take care that some TMP files can contain important information.  
For example files generated by `SMTPSaveImportErrors=n`

In such cases you have to move those files before restarting the server Server-Restart via Fault-Recovery is not effected because the internal start routines do generally not call this start script.

Therefore the script only deletes *TMP files in data directory which are at least 1 day old.

## DOMINO_CUSTOM_REMOVE_TEMPFILES_SCRIPT (expert)

This script allows a customizable way to remove temp files on server start.  
A sample script `remove_tempfiles_script` is included. The script works in combination with `DOMINO_REMOVE_TEMPFILES`.
You have to specify a script name and enable the option. This script overwrites the default code in the start script.

## DOMINO_CLEAR_LOGS_STARTUP (expert)

Clear Logs on startup before the server starts. See `clearlog` for details about the actions performed.

## DOMINO_LOG_CLEAR_DAYS (expert)

Number of days until logs are cleared (See details in `clearlog` command description).

## DOMINO_LOG_BACKUP_CLEAR_DAYS (expert)

Number of days until backup logs are cleared (See details in `clearlog` command description).

## DOMINO_CUSTOM_LOG_CLEAR_PATH (expert)

Specify this custom location to remove old logs from a directory.  
Can only be used in combination with `DOMINO_CUSTOM_LOG_CLEAR_DAYS`

## DOMINO_CUSTOM_LOG_CLEAR_DAYS (expert)

Age of log files to be cleared. Works in combination with `DOMINO_CUSTOM_LOG_CLEAR_PATH`.

## DOMINO_CUSTOM_LOG_CLEAR_SCRIPT (expert)

Custom log clear script will be used instead of the standard log clear operations and replaces all other clear operations!
(See details in `clearlog` command description).

## DOMINO_LOG_DB_DAYS

Rename log.nsf database on startup after n days (This will only work for the default log.nsf location and not check the log= notes.ini parameter).

The file domino_last_log_db.txt in data directory will hold the last time the log was renamed.

## DOMINO_LOG_DB_BACKUP_DIR

Target directory for rename log.nsf database on startup / default `log_backup` in data dir.

Moving the log.nsf will be executed before starting the server and after the startup compact/fixup operations.  
You can specify a directory inside or outside the Domino data directory.

## DOMINO_LOG_DB_BACKUP

Sets a fixed log.nsf backup file to have one additional version of log.nsf.  
Instead of creating multiple versions with date-stamp. Works in combination with `DOMINO_LOG_DB_DAYS`.

Instead of renaming a log database you can specify `DELETEDB` to remove the log database.

## DOMINO_DOMLOG_DB_BACKUP

Sets a fixed domlog.nsf backup file to have one additional version of domlog.nsf.  
Instead of creating multiple versions with date-stamp. Works in combination with `DOMINO_DOMLOG_DB_DAYS`.

Instead of renaming a log database you can specify `DELETEDB` to remove the log database.

## DOMINO_DOMLOG_DB_DAYS

Rename domlog.nsf database on startup after n days.

The file domino_last_domlog_db.txt in data directory will hold the last time the log was renamed.

## DOMINO_DOMLOG_DB_BACKUP_DIR

Target directory for rename domlog.nsf database on startup / default `log_backup` in data dir

Moving the domlog.nsf will be executed before starting the server and before startup compact/fixup operations.  
You can specify a directory inside or outside the Domino data directory.

## NSD_SET_POSIX_LC

Set the locale to POSIX (C) when running NSD.

## DOMINO_PRE_SHUTDOWN_COMMAND

Command to execute before shutting down the Domino server.  
In some cases, shutting down a certain servertask before shutting down the server reduces the time the server needs to  shutdown.

## DOMINO_PRE_SHUTDOWN_DELAY

Delay before shutting down the Domino server after invoking the pre-shutdown command. If configured the shutdown waits this time until invoking the actual shutdown after invoking the `DOMINO_PRE_SHUTDOWN_COMMAND` command.

## DOMINO_VIEW_REBUILD_DIR

View Rebuild Directory which will be created if not present.  
This option is specially useful for servers using temp file-systems with subdirectories for example for each partitioned servers separately. Use notes.ini `view_rebuild_dir` to specify directory.

## DOMINO_TEMP_DIR

Notes Temporary Directory which will be created if not present.  
This option is specially useful for servers using temp file-systems with subdirectories for example for each partitioned servers separately.

Use notes.ini `notes_tempdir` to specify directory.

## DOMINO_LOG_PATH

Log Directory which will be created if not present.

This option is specially useful for servers using temp file-systems with subdirectories for example for each partitioned servers separately.

Use notes.ini `logfile_dir` to specify directory.

The following settings are intended to add functionality to the existing start script without modifying the code directly.  
Those scripts inherit all current variables of the main script. The scripts are invoked as kind of call-back functionality.
You have to ensure that those scripts terminate in time.

## DOMINO_3RD_PARTY_BIN_DIRS

3rd Party directories to check for running processes when cleaning up server resources specify separate directories with blank in-between. directory names should not contain blanks.  
Those directories are also checked for running processes when cleaning up server resources via `clenup` command by default only the $LOTUS directory is checked for running binaries.

## DOMINO_SCRIPT_DIR (expert)

This variable can be used to specify a directory for all scripts that can be invoked.  
It is only referenced in the configuration file and used by default for a scripts which are invoked.  
But you can also specify different locations per pre/post script.

## DOMINO_TIKA_SHUTDOWN_TERM_SECONDS

Tries to shutdown the Tika index server during shutdown.  
It can happen that the Tika server does not terminate, which prevents the Domino server from shutting down properly.

Default: 30 seconds

## DOMINO_SHUTDOWN_DELAYED_SCRIPT

Script which can be executed delayed during shutdown.  
`DOMINO_SHUTDOWN_DELAYED_SECONDS` specifies the number of seconds after shutdown start.

## DOMINO_SHUTDOWN_DELAYED_SECONDS

Shutdown Delay for delayed shutdown command.

Default is **20 seconds** if script is defined.

## DOMINO_PRE_STARTUP_SCRIPT (expert)

This script is invoked before starting the server.

## DOMINO_POST_STARTUP_SCRIPT (expert)

This script is invoked after starting the server.

## DOMINO_PRE_SHUTDOWN_SCRIPT (expert)

This script is invoked before shutting down the server.

## DOMINO_POST_SHUTDOWN_SCRIPT (expert)

This script is invoked after shutting down the server.

## DOMINO_PRE_KILL_SCRIPT (expert)

This script is invoked before any `nsd -kill` is executed.

## DOMINO_POST_KILL_SCRIPT (expert)

This script is invoked after any `nsd -kill` is executed.

## DOMINO_PRE_CLEANUP_SCRIPT (expert)

This script is invoked before cleaning up server resources native on OS level.

## DOMINO_POST_CLEANUP_SCRIPT (expert)

This script is invoked after cleaning up server resources native on OS level.

## DOMINO_PRE_STATUS_SCRIPT (expert)

Script which will be executed before the server status is checked.  
This can be helpful in case you want to check status for other tools like monitoring tools before you check the Domino server status.  
The option does not directly impact the status of the Domino status and is mainly intended to add log output.

## DOMINO_START_COMPACT_OPTIONS

Specifies which compact should be executed before Domino server start. This allows regularly compact of e.g. system databases when the server starts you should specify an .ind file for selecting system databases.  
An example which is disabled by default is included in the config file.

## DOMINO_COMPACT_OPTIONS

Specifies which compact options to use when using the "compact" and `restartcompact` commands you should specify an .ind file for selecting system databases.

An example which is disabled by default is included in the config file.

## DOMINO_START_FIXUP_OPTIONS

Specifies which fixup should be executed before Domino server start.  
This allows regularly fixup of e.g. system databases when the server starts you should specify an `.ind` file for selecting system databases.

An example which is disabled by default is included in the config file.

Note: fixup is a last resort operation when a database is corrupted and it is not required to run fixup regularly on any database in a scheduled manner.  
Some customers have special requirements and this start script is intended to provide options for different customer cases.

## DOMINO_FIXUP_OPTIONS

Specifies which fixup options to use when using the "fixup" and `restartfixup` commands.  
You should specify an .ind file for selecting system databases.

An example which is disabled by default is included in the config file.

## DOMINO_COMPACT_TASK

Compact task can now be specified. By default "compact" is used.

Another option would be to use `dbmt` (since Domino 9).

## DOMINO_LOG_COMPACT_OPTIONS

Log compact options.

## DOMINO_LOG_START_COMPACT_OPTIONS

Start log compact options.

## DOMINO_CONSOLE_SERVERC (expert)

By default live console uses `server -c "cmd"` to run server commands.  
This new functionality can be reverted back to the previous functionality via DOMINO_CONSOLE_SERVERC=NO.  
In this case a echo "cmd" > notes.input is used.  
Switching back to the old behavior disables support for the live console in combination with the server controller.

## DOMINO_PID_FILE (expert)

Domino PID file per partition which has to match the PID file setting in the domino.service.

This option is only required for systemd support.  
The default is domino.pid located in the Domino data-directory.  
If you change the setting you have also change the `domino.service` file.
