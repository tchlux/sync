# sync
A minimal (efficient) Posix-based file synchronization utility built on rsync.

## INSTALLATION

  Download the file `sync.sh` in this repository and move it to
  whatever directory you want to keep it in (and whatever name you
  want).

  Add a line `source <path to sync script>` to your shell
  initialization file (in bash that could be `.bashrc`).

  Open a new shell (or manually `source <path to sync script>`).

  The default configuration script will walk through the process for
  setting up the `sync` command on the local machine.

--------------------------------------------------------------------

# Built-in README

  This file provides the command for "sync"ing the present working
  directory with a master directory. It keeps track of a file called
  `.sync_time` with the recorded output of `python -c "import time;
  print(int(time.time()))"` to determine which repository is more
  recent. Then the `rsync` utility is used to transfer (and delete if
  appropriate) files between the files at

    $SYNC_LOCAL_DIR   <--->   $SYNC_SERVER:$SYNC_SERVER_DIR


## USAGE:

    $ sync [--status] [--configure] [path=$SYNC_LOCAL_DIR]

  The `sync` command will synchronize the entire local directory if no
  path nor options are specified. If a path is specified, it MUST be
  contained within SYNC_LOCAL_DIR and only that subset will be
  synchronized.

  Executing with the '--status' option will get the last modification
  time of the server and local directories, print them, and exit.

  Executing with the '--configure' command will run the initial
  configuration script to update the stored configuration variables
  expressed in this file.

  A script is provided that will automatically walk you through
  configuration on your local machine. If this file is executed and
  the value $SYNC_SCRIPT_PATH does not point to a valid file, a prompt
  to automatically (re)configure will appear.
