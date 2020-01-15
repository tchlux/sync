# sync
  A minimal Posix-compatible file synchronization utility built on `rsync`.

## INSTALLATION

  Download the file `sync.sh` in this repository and move it to
  a permanent directory, renaming it if appropriate / desired.

  In the shell, type `source <path to sync script>`.

  The default configuration script will walk through the process for
  setting up the `sync` command on the local machine.

--------------------------------------------------------------------

# Documentation in code

  This file provides a command-line function `sync` for
  synchronizing a local directory with a server directory through
  `ssh` and `rsync`. It keeps track of a file called `.sync_time`
  containing the time since the Epoch in seconds to determine which
  files are recently modified. Then the `rsync` utility is used to
  transfer (and delete if appropriate) files between
  `$SYNC_LOCAL_DIR` and `$SYNC_SERVER:$SYNC_SERVER_DIR` using the
  efficient delta method of `rsync`. This can be very fast even for
  large directories, certainly more so than a full `scp`.

  This tool provides a one-liner replacement for something like
  Dropbox or Git that can be used easily from a server with a POSIX
  compliant shell with the commands `whoami`, `hostname`, `pwd`,
  `cd`, `rm`, `mkdir`, `dirname`, `basename`, `which`, `source`,
  `export`, `read`, `echo`, `typeset`, `cat`, `wc`, `sed`, `grep`, 
  `ssh`, `ssh-keygen`, `ssh-copy-id`, `rsync`, and `python` (or
  `python3`).

##  EXPECTED SHELL SYNTAX AND COMMANDS

    $(<command to execute>)
    ${<string>:-<value if string is empty>}
    ${<string>%<pattern to remove from end of string>}
    ${<string>#<pattern to remove from beginning of string>}
    ${#<string to measure length>}
    ${<string>:<integer slice from>:<integer slice to>}
    <command-1> | <command taking input from command-1 as a file>
    <command> > <stdout redirect> 2> <stderr redirect>
    [ <conditional expression to evaluate> ]
    [ <conditional or 1> || <conditional or 2> ]
    [ <integer is equal> -eq <to this integer> ]
    [ <integer is greater> -gt <than this integer> ]
    [ -f <this file exists?> ]
    [ -d <this directory exists?> ]
    [ ! <conditional to be negated> ]

    func () { <body of function that takes arguments as $1 ...> }
    while <loop condition> ; do <body commands> ; done
    if <condition> ; then <true body> ; elif <condition> ; then <true body> ; else <false body> ; fi

  Along with the standard POSIX expectations above, the following
  commands are used by this program with the demonstrated syntax.

    whoami (no arguments / prints the current user name)
    hostname (no arguments / prints name of machine)
    pwd (no arguments / prints full path to present working directory)
    cd <directory to move to>
    rm -f <path to file to remove>
    mkdir -p <directory to create if it does not already exist>
    dirname <path to get only directory name>
    basename <path to get only file name>
    which <name of executable to return full path to>
    source <path to shell file to run>
    export <varname>=<value>
    read <variable> (user input prompted with directory tab-auto-complete)
    echo "<string to output to stdout>"
    typeset -f "<name of shell function>"
    cat <path to file that will be printed to stdout>
    wc -l <path to file to show line count>
    sed -i.backup "s/<match pattern>/<replace pattern in-file>/g" <file-name>
    grep "<regular expression>" <file to find matches>
    rsync -az -e "<remote shell command>" --update --delete --progress --existing --ignore-existing --dry-run <source-path> <destination-path>
    python -c "<python 2 / 3 compatible code>"
    ssh <server-name> "command" (opens a secure shell to server and runs command)
    ssh-keygen (generates an ssh remote login key if it doesn't exist)
    ssh-copy-id <server-name> (exchanges ssh authorizations with server)


## USAGE:

    $ sync [--status] [--configure] [--rename] [--help]

  The `sync` command will synchronize the entire local directory if
  no path nor options are specified. If a path is specified, it
  *must* be contained within `$SYNC_LOCAL_DIR` and only that subset
  will be synchronized.

  Executing with the `--status` option will get the last
  modification time of the server and local directories, print them,
  and exit.

  Executing with the `--configure` option will run the initial
  configuration script to update the stored configuration variables
  expressed in the local sync script.

  Executing with the `--rename` option will prevent the script from
  exiting upon discovery of local conflict files. Instead, the local
  files will be renamed appropriately and then synchronization will
  continue as normal.

  Executing with the `--help` option will display an abbreviated
  version of this documentation to standard output.

  A script is provided that will automatically walk you through
  configuration on your local host. If this file is executed and
  the value `$SYNC_SCRIPT_PATH` does not point to a valid file, a
  prompt to automatically (re)configure will appear.

## WARNINGS:

  In some cases, symbolic links will show a modification time that 
  makes them *always* synchronize. This can cause chaos, so for now
  if you see this happenn then delete that file. Please consider
  submitting an `Issue` in the repository with a minimum working
  example and I will fix it as soon as possible.
