# sync
A minimal (efficient) Posix-based file synchronization utility built on rsync.

## INSTALLATION

  Download the file `sync.sh` in this repository and move it to
  whatever directory you want to keep it in (and whatever name you
  want).

  Add a line `source <path to sync script>` to your shell
  initialization file, most shells look at `.profile` in the users
  home directory when initializing.

  Open a new shell or manually enter `source <path to sync script>`.

  The default configuration script will walk through the process for
  setting up the `sync` command on the local machine.

--------------------------------------------------------------------

# Documentation in code

  This file provides a command-line function `sync` for
  synchronizing a local directory with a server directory through
  `ssh` and `rsync`. It keeps track of a file called `.sync_time`
  containing the time since the Epoch in seconds to determine which
  repository is more recent. Then the `rsync` utility is used to
  transfer (and delete if appropriate) files between
  `$SYNC_LOCAL_DIR` and `$SYNC_SERVER:$SYNC_SERVER_DIR` using the
  efficient delta method of `rsync`. This can be very fast even for
  large directories, certainly more so than a full `scp`.

  This tool provides a one-liner replacement for something like
  Dropbox or Git that can be used easily from a server with a POSIX
  interface, `pwd`, `export`, `cd`, `mkdir`, `read`, `echo`, `cat`,
   `sed`, `grep`, `rsync` and `python`.

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

    pwd (no arguments / prints full path to present working directory)
    export <varname>=<value>
    cd <directory to move to>
    mkdir -p <directory to create if it does not already exist>
    read -e -p "<user input prompted with directory tab-auto-complete>"
    echo "<string to output to stdout>"
    cat <path to file that will be printed to stdout>
    sed -i.backup "s/<match pattern>/<replace pattern in-file>/g" <file-name>
    grep "<regular expression>" <file to find matches>
    rsync -az -e "<remote shell command>" --update --delete --progress <source-patah> <destination-path>
    python -c "<python 2 / 3 compatible code>"


## USAGE:

    $ sync [--status] [--configure] [path=$SYNC_LOCAL_DIR]

  The `sync` command will synchronize the entire local directory if
  no path nor options are specified. If a path is specified, it MUST
  be contained within SYNC_LOCAL_DIR and only that subset will be
  synchronized.

  Executing with the `--status` option will get the last
  modification time of the server and local directories, print them,
  and exit.

  Executing with the `--configure` command will run the initial
  configuration script to update the stored configuration variables
  expressed in this file.

  A script is provided that will automatically walk you through
  configuration on your local machine. If this file is executed and
  the value `$SYNC_SCRIPT_PATH` does not point to a valid file, a
  prompt to automatically (re)configure will appear.

