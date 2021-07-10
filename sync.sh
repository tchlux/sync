# 
#    ________________________________
#   | AUTHOR   |  Thomas C.H. Lux    |
#   |          |                     |
#   | EMAIL    |  tchlux@vt.edu      |
#   |          |                     |
#   | VERSION  |  2021.07.10         |
#   |          |  Basic sync script  |
#   |          |  with bidirectional |
#   |          |  `sync` operation.  |
#   |__________|_____________________|
# 
# 
# --------------------------------------------------------------------
#                             README
# 
#   This file provides a command-line function `sync` for
#   synchronizing a local directory with a server directory through
#   `ssh` and `rsync`. It keeps track of a file called `.sync_time`
#   containing the time since the Epoch in seconds to determine which
#   files are recently modified. Then the `rsync` utility is used to
#   transfer (and delete if appropriate) files between
#   `$SYNC_LOCAL_DIR` and `$SYNC_SERVER:$SYNC_SERVER_DIR` using the
#   efficient delta method of `rsync`. This can be very fast even for
#   large directories, certainly more so than a full `scp`.
# 
#   This tool provides a one-liner replacement for something like
#   Dropbox or Git that can be used easily from a server with a POSIX
#   compliant shell with the commands `pwd`, `export`, `cd`, `mkdir`,
#   `read`, `echo`, `cat`, `wc`, `sed`, `grep`, `rsync`, `typeset`,
#   and `python` (or `python3`).
# 
# ##  EXPECTED SHELL SYNTAX AND COMMANDS
# 
#     $(<command to execute>)
#     ${<string>:-<value if string is empty>}
#     ${<string>%<pattern to remove from end of string>}
#     ${<string>#<pattern to remove from beginning of string>}
#     ${#<string to measure length>}
#     ${<string>:<integer slice from>:<integer slice to>}
#     <command-1> | <command taking input from command-1 as a file>
#     <command> > <stdout redirect> 2> <stderr redirect>
#     [ <conditional expression to evaluate> ]
#     [ <conditional or 1> || <conditional or 2> ]
#     [ <integer is equal> -eq <to this integer> ]
#     [ <integer is greater> -gt <than this integer> ]
#     [ -f <this file exists?> ]
#     [ -d <this directory exists?> ]
#     [ ! <conditional to be negated> ]
# 
#     func () { <body of function that takes arguments as $1 ...> }
#     while <loop condition> ; do <body commands> ; done
#     for <var name> in $<variable> ; do <body commands> ; done
#     if <condition> ; then <true body> ; elif <condition> ; then <true body> ; else <false body> ; fi
# 
#   Along with the standard POSIX expectations above, the following
#   commands are used by this program with the demonstrated syntax.
# 
#     cd <directory to move to>
#     rm <path to file to remove>
#     mkdir -p <directory to create if it does not already exist>
#     pwd (no arguments / prints full path to present working directory)
#     dirname <path to get only directory name>
#     basename <path to get only file name>
#     export <varname>=<value>
#     read "<user input prompted with directory tab-auto-complete>"
#     echo "<string to output to stdout>"
#     typeset -f "<name of shell function>"
#     cat <path to file that will be printed to stdout>
#     wc -l <path to file to show line count>
#     sed -i.backup "s/<match pattern>/<replace pattern in-file>/g" <file-name>
#     grep "<regular expression>" <file to find matches>
#     rsync -az -e "<remote shell command>" --update --delete --progress --existing --ignore-existing --dry-run <source-path> <destination-path>
#     python -c "<python 2 / 3 compatible code>"
# 
# 
# ## USAGE:
# 
#     $ sync [--status] [--configure] [--rename] [--help]
# 
#   The `sync` command will synchronize the entire local directory if
#   no path nor options are specified. If a path is specified, it
#   *must* be contained within `$SYNC_LOCAL_DIR` and only that subset
#   will be synchronized.
# 
#   Executing with the `--status` option will get the last
#   modification time of the server and local directories, print them,
#   and exit.
# 
#   Executing with the `--configure` option will run the initial
#   configuration script to update the stored configuration variables
#   expressed in the local sync script.
# 
#   Executing with the `--rename` option will prevent the script from
#   exiting upon discovery of local conflict files. Instead, the local
#   files will be renamed appropriately and then synchronization will
#   continue as normal.
# 
#   Executing with the `--help` option will display an abbreviated
#   version of this documentation to standard output.
# 
#   A script is provided that will automatically walk you through
#   configuration on your local host. If this file is executed and
#   the value `$SYNC_SCRIPT_PATH` does not point to a valid file, a
#   prompt to automatically (re)configure will appear.
# 
# CONFIGURATION VARIABLES FOR "SYNC" OPERATION.
#
export SYNC_SCRIPT_PATH=
export SYNC_SERVER=
export SYNC_SSH_ARGS=
export SYNC_SERVER_DIR=
export SYNC_LOCAL_DIR=
# Directories listed above should NOT have a trailing slash.
# --------------------------------------------------------------------

# Get the last argument passed to this function.
last_arg () {
    for value ; do true ; done
    echo $value
}

# Get the path to a python executable by getting the last element
#  returned by `which python3` or if that fails, `which python`.
export SYNC_PYTHON=$(last_arg $(which python3 2> /dev/null || which python 2> /dev/null || echo "SYNC_ERROR_NO_PYTHON"))

# Given a `path`, and `time`, print out all absolute paths
# to files in the directory tree under `path` that have been modified
# more recently than `time` seconds (since epoch).
find_mtime_seconds () {
    # Set the environment variable "SYNC_PYTHON" if it is not set.
    # This has to be done because this function is used through ssh.
    if [ ${#SYNC_PYTHON} -eq 0 ] ; then
        export SYNC_PYTHON=$(last_arg $(which python3 2> /dev/null || which python 2> /dev/null || echo "SYNC_ERROR_NO_PYTHON"))
    fi
    # Run the find command.
    $SYNC_PYTHON -c "import sys, os; [sys.stdout.write(os.path.abspath(os.path.join(d,p))+\"\\n\") for (d,ds,ps) in os.walk(os.path.abspath(\"$1\")) for p in (ps+ds) if ((os.path.isfile(os.path.join(d,p)) or os.path.islink(os.path.join(d,p))) and ($2 < os.lstat(os.path.join(d,p)).st_mtime))]"
}

# Given a `prefix`, read standard input as a file, but add `prefix`
# before every line. Uses `python` to achieve this.
add_line_prefix_to_stdin () {
    $SYNC_PYTHON -c "import sys; sys.stdout.write(\"$1\"+(\"\\n\"+\"$1\").join([l.rstrip(\"\\n\") for l in sys.stdin.readlines()]))"
    echo ""
}

# Use Python to compute the minimum of two numbers (supports floats).
minimum () {
    $SYNC_PYTHON -c "import sys; sys.stdout.write(str(min($1, $2)))"
}

# Use Python to convert seconds since the epoch to a local time date string.
seconds_to_date () {
    $SYNC_PYTHON -c "import sys, time; sys.stdout.write(str(time.ctime(int($1))))"
}

# Use Python to generate the time since the epoch in seconds.
time_in_seconds () {
    $SYNC_PYTHON -c "import sys, time; sys.stdout.write(str(int(time.time())))"
}

# Give the integer number of nonempty lines in a file.
count_nonempty_lines () {
    # Use wc to count the number of changes and `sed` to remove blank lines.
    changed_count=$(cat "$1" | sed '/^\s*$/d' | wc -l)
    # Remove excess whitespace from the "wc" operation.
    echo $changed_count
}

# Function for displaying the current configuration to the user.
sync_show_configuration () {
    echo "'sync' command configured with the following:"
    echo ""
    echo "  SYNC_SCRIPT_PATH: "$SYNC_SCRIPT_PATH
    echo "  SYNC_SERVER:      "$SYNC_SERVER
    echo "  SYNC_SERVER_DIR:  "$SYNC_SERVER_DIR
    echo "  SYNC_LOCAL_DIR:   "$SYNC_LOCAL_DIR
    if [ ${#SYNC_SSH_ARGS} -gt 0 ] ; then
        echo "  SYNC_SSH_ARGS:    "$SYNC_SSH_ARGS
    fi
    echo "  SYNC_PYTHON:      "$SYNC_PYTHON
}

# The initial setup script, this will modify the contents of this file
# for future executions. It will also attempt to verify that
# passwordless login has been properly configured on the local host
# (if it is not, it will attempt to configure that as well).
sync_configure () {
    # Get the "home" directory using "cd"
    start_dir=$(pwd); cd > /dev/null 2> /dev/null
    home=$(pwd);      cd $start_dir > /dev/null 2> /dev/null
    # Set the default values for all variables if they are not defined.
    default_user_script_path=${SYNC_SCRIPT_PATH:-"$(pwd)/sync.sh"}
    default_user_server=${SYNC_SERVER:-"$(whoami)@$(hostname)"}
    default_user_ssh_args=${SYNC_SSH_ARGS:-""}
    default_user_server_dir=${SYNC_SERVER_DIR:-"Sync"}
    default_user_local_dir=${SYNC_LOCAL_DIR:-"$(pwd)/Sync"}
    # Query the user for the values to put in their place.
    echo ""
    echo "----------------------------------------------------------------------"
    echo "Configuring 'sync' function."
    echo ""
    echo -n "Full path to THIS 'sync' script (default '$home/${default_user_script_path#$home/}'): "
    read user_script_path
    user_script_path=${user_script_path:-$default_user_script_path}
    # Check to make sure the script file actually exists at that location.
    while [ ! -f "$home/${user_script_path#$home/}" ] ; do
        echo "No file exists at '$home/${user_script_path#$home/}'."
        echo -n "Full path to 'sync' script (default '$home/${default_user_script_path#$home/}'): "
        read user_script_path
        user_script_path=${user_script_path:-$default_user_script_path}
    done
    # Read the rest of the configuration values.
    echo -n "Server ssh identity (default '$default_user_server'): "
    read user_server
    echo -n "  extra ssh flags (default '$default_user_ssh_args'): "
    read user_ssh_args
    echo -n "Master sync dirctory on server (default '$default_user_server_dir'): "
    read user_server_dir
    echo -n "Local sync dirctory (default '$home/${default_user_local_dir#$home/}'): "
    read user_local_dir
    echo ""
    # Set the default values for all unprovided variables from the user.
    user_server=${user_server:-$default_user_server}
    user_ssh_args=${user_ssh_args:-$default_user_ssh_args}
    user_server_dir=${user_server_dir:-$default_user_server_dir}
    user_local_dir=${user_local_dir:-$default_user_local_dir}
    # Convert the provided path to an absolute path.
    cd $(dirname "$user_script_path") > /dev/null 2> /dev/null
    user_script_path=$(pwd)/$(basename "$user_script_path")
    cd "$start_dir" > /dev/null 2> /dev/null
    # Convert the provided local directory into an aboslute path.
    mkdir -p "$user_local_dir" || return 5
    cd "$user_local_dir" > /dev/null 2> /dev/null
    user_local_dir=$(pwd)
    cd "$start_dir" > /dev/null 2> /dev/null
    # Strip the trailing "/" from the provided path names.
    user_server_dir="${user_server_dir%/}"
    # Use "sed" to edit this file to contain the user entered values.
    echo -n "Reconfiguring this sync script.. "
    # Replace this file with a configured version of itself. Each line
    # that defines "replacement" is escaping "sed" special characters.
    # Each line that starts with "sed" is updating this file.
    replacement="$(echo "$user_server" | sed 's/[\/&]/\\&/g')"
    sed -i.backup "s/^export SYNC_SERVER=.*$/export SYNC_SERVER=$replacement/g" "$user_script_path"
    replacement="$(echo "\"$user_ssh_args\"" | sed 's/[\/&]/\\&/g')"
    sed -i.backup "s/^export SYNC_SSH_ARGS=.*$/export SYNC_SSH_ARGS=$replacement/g" "$user_script_path"
    replacement="$(echo "$user_server_dir" | sed 's/[\/&]/\\&/g')"
    sed -i.backup "s/^export SYNC_SERVER_DIR=.*$/export SYNC_SERVER_DIR=$replacement/g" "$user_script_path"
    replacement="$(echo "${user_local_dir#$home/}" | sed 's/[\/&]/\\&/g')"
    sed -i.backup "s/^export SYNC_LOCAL_DIR=.*$/export SYNC_LOCAL_DIR=$replacement/g" "$user_script_path"
    replacement="$(echo "${user_script_path#$home/}" | sed 's/[\/&]/\\&/g')"
    sed -i.backup "s/^export SYNC_SCRIPT_PATH=.*$/export SYNC_SCRIPT_PATH=$replacement/g" "$user_script_path"
    rm "$user_script_path.backup"
    echo "done."
    # Export the user variables by re-sourcing this file.
    source "$user_script_path"
    # Print out the configuration to the user.
    echo ""
    sync_show_configuration
    # Ask about optional extra configuration steps..
    echo ""
    echo -n "Configure passwordless ssh (y/n) [n]? "
    read user_query
    user_query=${user_query:-n}
    user_query=$(echo -n "$user_query" | grep '^[Yy]\([eE][sS]\)\?$')
    if [ ${#user_query} -gt 0 ] ; then
        echo ""
        echo "Checking '$home' for RSA key.."
        echo ""
        # Check for the existence of ".ssh" and "id_rsa.pub", if the
        # public RSA key has not been created, create it.
        if [ ! -d "$home/.ssh" ] ; then    
            ssh-keygen
        elif [ ! -f "$home/.ssh/id_rsa.pub" ] ; then
            ssh-keygen
        fi
        # Perform the copy-id operation.
        ssh-copy-id $SYNC_SERVER
    fi
    echo ""
    echo "If you do not source this script at shell initialization"
    echo " automatically, you will have to manually source before use."
    echo -n " Add 'sync' command to shell initialization (y/n) [n]? "
    read user_query
    user_query=${user_query:-n}
    user_query=$(echo -n "$user_query" | grep '^[Yy]\([eE][sS]\)\?$')
    if [ ${#user_query} -gt 0 ] ; then
        # Ask where to put the 'source' line.
        echo -n "Shell initialization file (default '$home/.profile'): "
        read user_shell_init    
        user_shell_init=${user_shell_init:-"$home/.profile"}
        # Make the directory if it does not exist.
        mkdir -p "$(dirname $user_shell_init)"
        # Append a line to the file.
        echo "source $home/${SYNC_SCRIPT_PATH#$home/}" >> $user_shell_init
        echo ""
    fi
    echo "----------------------------------------------------------------------"
    echo ""
}

# Get the last synchronization time of the server and the local directories.
# Print the times to the user and update shell variables
# SYNC_SERVER_TIMESTAMP and SYNC_LOCAL_TIMESTAMP that describe the
# previous update time in seconds.
sync_status () {
    # Get the starting directory (to return to it once complete).
    start_dir=$(pwd)
    # Get the full path to the "local_dir" in case "SYNC_LOCAL_DIR" is relative.
    cd > /dev/null 2> /dev/null
    # Create the "sync" directory in local in case it does not exist.
    mkdir -p "$SYNC_LOCAL_DIR"
    cd "$SYNC_LOCAL_DIR" > /dev/null 2> /dev/null
    local_dir=$(pwd)
    cd "$start_dir" > /dev/null 2> /dev/null
    # Get the ".sync_time" time, redirect "File not found" error, it's ok.
    SYNC_SERVER_TIMESTAMP=$(ssh $SYNC_SSH_ARGS $SYNC_SERVER "echo -n 'SYNC_TIME_IS' && ( cat $SYNC_SERVER_DIR/.sync_time 2> /dev/null || echo '' )") || return 1
    SYNC_SERVER_TIMESTAMP=$(echo -n $SYNC_SERVER_TIMESTAMP | sed "s:^.*SYNC_TIME_IS::g")
    # Create a ".sync_time" file locally if it does not exist.
    if [ ! -f $local_dir/.sync_time ] ; then
        # If a local sync doesn't exist, we need to set the local time
        # stamp to be a value certainly less, and copy from the
        # master to the local! This date corresponds to '0' seconds.
        echo -n "0" > $local_dir/.sync_time
    fi
    # Default value of the master timestamp is the second count "0".
    export SYNC_SERVER_TIMESTAMP=${SYNC_SERVER_TIMESTAMP:-"0"}
    export SYNC_LOCAL_TIMESTAMP=$(cat $local_dir/.sync_time)
    # Ask about optional extra configuration steps..
    echo ""
    echo "___________________________________________"
    echo ""
    echo "Server directory last synchronization date:"
    echo "  $(seconds_to_date $SYNC_SERVER_TIMESTAMP)"
    echo ""
    echo "Local directory last synchronization date:"
    echo "  $(seconds_to_date $SYNC_LOCAL_TIMESTAMP)"
    echo "___________________________________________"
    # Find all the local files, ignore the ".sync_time" file, and remove leading characters.
    old_sync_time=$(minimum "$SYNC_LOCAL_TIMESTAMP" "$SYNC_SERVER_TIMESTAMP")
    sync_changed_files=$(find_mtime_seconds "$local_dir" $old_sync_time | sed "s:^.*$local_dir:$local_dir:g" | ( grep -v "$local_dir/\.sync_time" || echo '' ) )
    if [ ${#sync_changed_files} -gt 0 ] ; then
        echo ""
        # Get the number of changed files.
        sync_changed_count=$(echo "$sync_changed_files" | wc -l)
        sync_changed_count=$(echo $sync_changed_count)
        if [ "$sync_changed_count" = "1" ] ; then
            echo "$sync_changed_count local file changed or added since last sync:"
        else
            echo "$sync_changed_count local files changed or added since last sync:"
        fi
        echo ""
        echo "$sync_changed_files" | add_line_prefix_to_stdin "  "
        echo ""
        echo "-------------------------------------------"
    fi
    echo ""
}

# Define the "sync" command that can be used from the command line.
sync () {
    # Get the starting directory (to return to it once complete).
    start_dir=$(pwd)
    # Get the full path to the "local_dir" in case "SYNC_LOCAL_DIR" is relative.
    cd > /dev/null 2> /dev/null
    mkdir -p "$SYNC_LOCAL_DIR"
    cd "$SYNC_LOCAL_DIR" > /dev/null 2> /dev/null
    local_dir=$(pwd)
    cd "$start_dir" > /dev/null 2> /dev/null
    # Get any command line arguments.
    arguments=$1
    # Use the provided path, otherwise default to the local directory.
    if [ ${#arguments} -gt 0 ] ; then
        # If the user wants to reconfigure, call that script.
        if [ "$1" = "--configure" ] ; then sync_configure ; return 0
                                           # If the user wants the status, call that script.
        elif [ "$1" = "--status" ] ; then
            echo ""
            sync_show_configuration || return 2
            sync_status || return 1
            return 0
            # Do nothing (these option will be used later).
        elif [ "$1" = "--rename" ] ; then :
        else
            echo ""
            echo "The 'sync' utility provides easy automatic synchronization using"
            echo " 'rsync' and a single time file to intelligently synchronize files"
            echo "  between the local host and a server. Use as:"
            echo ""
            echo " sync [--status] [--configure] [--rename] [--help]"
            echo ""
            echo "where the options have the following effects:"
            echo "  status     -  Show the synchronization status of the server and local host and exit."
            echo "  configure  -  Re-run the built-in configuration script and exit."
            echo "  rename     -  Continue execution even with conflicts, automatically rename."
            echo "  help       -  Display this help message."
            echo ""
            return 0
        fi
    fi
    # Call the "sync_status" function that updates the time stamps.
    sync_status || return 1
    # Simplify the name of the path to the server sync directory and `rsync` command.
    serve_dir=$SYNC_SERVER:$SYNC_SERVER_DIR
    if [ ${#SYNC_SSH_ARGS} -gt 0 ] ; then sync_args="-e \"ssh $SYNC_SSH_ARGS\"" ; fi
    # Create directories in master (in case the path does not exist).
    # Get the ".sync_time" time, redirect "File not found" error, it's ok.
    ( ssh $SSH_ARGS $SYNC_SERVER "mkdir -p $SYNC_SERVER_DIR" > /dev/null ) || return 3
    # Declare some file names to use in this process.
    sync_files_serve=".sync_files_$(hostname)_transfer_from_server"
    # Find all server files that are newer than this sync time (relative paths only, exclude ".sync_time" file).
    server_find_command="$(typeset -f last_arg); $(typeset -f find_mtime_seconds); find_mtime_seconds \"$SYNC_SERVER_DIR\" $old_sync_time | sed \"s:^.*$SYNC_SERVER_DIR/::g\" | ( grep -v \"\.sync_time\" || echo '' )"
    ( ( ssh $SSH_ARGS $SYNC_SERVER "$server_find_command" ) > "$local_dir/$sync_files_serve" ) || return 3
    # Cycle through local files that have been modified, if they are also
    # modified on the server, then reassign their name to have a conflict
    # string at the end of the name.
    if [ $(count_nonempty_lines "$local_dir/$sync_files_serve") -gt 0 ] ; then
        conflict_files=$(echo "$sync_changed_files" \
                             | sed "s:^$local_dir/::g" \
                             | grep -Ff "$local_dir/$sync_files_serve")
    else
        unset conflict_files
    fi
    # If there are conflicting files, then handle appropriately.
    if [ ${#conflict_files} -gt 0 ] ; then
        # If "--rename" was specified, automatically rename the conflicts.
        if [ "$1" = "--rename" ] ; then
				suffix="_SYNC_CONFLICT_[$(hostname)]_$(date +%Y-%m-%d_%H-%M-%S_%Z)"
            while IFS= read -r conflict_file; do
                echo "  making file: ""$local_dir/$conflict_file$suffix"
                mv "$local_dir/$conflict_file" "$local_dir/$conflict_file$suffix"
            done <<< "$conflict_files"
            echo ""
            # If "--rename" was not specified, raise an error.
        else
            echo "ERROR: Found conflicting local files. Either rename files or use"
            echo "       the '--rename' option to automatically rename files."
            echo ""
            echo "$conflict_files" | add_line_prefix_to_stdin "  $local_dir/"
            echo ""
            # Remove the file that was created to list the new server files.
            rm -f "$local_dir/$sync_files_serve"
            return 4
        fi
    fi
    # 
    #         -------------------------------------------
    # 
    # Show a message about what is being `sync`ed to local, if there is anything.
    if [ $(count_nonempty_lines "$local_dir/$sync_files_serve") -gt 0 ] ; then
        echo " LOCAL <-- SERVER"
        echo ""
        # Sync all new files from the server to the local.
        echo 'rsync '$sync_args' -az --update --progress --files-from="'$local_dir'/'$sync_files_serve'" "'$serve_dir'" "'$local_dir'"'
        ( rsync $sync_args -az --update --progress --files-from="$local_dir/$sync_files_serve" "$serve_dir" "$local_dir" ) || return 7
        echo ""
        echo "-------------------------------------------"
        echo ""
    fi
    # Identify which files on this host were created since the last sync.
    # Use `sed` to remove the local directory prefix and to skip the
    # files specifc to operating the `sync` command.
    sync_files_local=".sync_files_$(hostname)_transfer_from_local"
    ( echo "$sync_changed_files" | sed "s:$local_dir/::g" > $local_dir/$sync_files_local ) || return 6
    if [ $(count_nonempty_lines "$local_dir/$sync_files_local") -gt 0 ] ; then    
        # Show a message about what is being `sync`ed up (always at leaast one file).
        echo " LOCAL --> SERVER"
        echo ""
        # Sync all new files from this local host to the server.
        echo 'rsync '$sync_args' -az --update --progress --files-from="'$local_dir'/'$sync_files_local'" "'$local_dir'" "'$serve_dir'"'
        ( rsync $sync_args -az --update --progress --files-from="$local_dir/$sync_files_local" "$local_dir" "$serve_dir" ) || return 8
        echo ""
        echo "-------------------------------------------"
        echo ""
    fi
    # Remove the temporary files used for synchronizing.
    rm -f "$local_dir/$sync_files_local" "$local_dir/$sync_files_serve"
    # Delete the local files that are gone from the server.
    delete_output=$( rsync $sync_args -a --progress --existing --ignore-existing --delete --dry-run "$serve_dir/" "$local_dir" ) || return 9
    # Print any outputs that describe a deletion on the local host.
    delete_output=$(echo "$delete_output" | sed 's:^.*deleting:deleting:g' | grep "deleting" | sed 's:^deleting ::g')
    if [ ${#delete_output} -gt 0 ] ; then
        echo " LOCAL DELETIONS"
        echo ""
        echo "$delete_output" | add_line_prefix_to_stdin "  $local_dir/"
        echo ""
        echo -n " Would you like to permantly delete all listed local files? (y/n) [y]? "
        read confirm
        confirm=${confirm:-y}
        confirm=$(echo -n "$confirm" | grep '^[Yy]\([eE][sS]\)\?$')
        # Only continue with the deletion if it was confirmed.
        if [ ${#confirm} -gt 0 ] ; then
            echo '  rsync '$sync_args' -a --existing --ignore-existing --delete "'$serve_dir'/" "'$local_dir'"'
            rsync $sync_args -a --existing --ignore-existing --delete "$serve_dir/" "$local_dir" || return 10
        fi
        echo ""
        echo "-------------------------------------------"
        echo ""
    fi
    # Overwrite the ".sync_time" file, because a synchronization has
    # happened. Record the current `time_in_seconds` so that all the
    # files that were just synchronized do not look newer than the 
    # synchronization itself.
    time_in_seconds > "$local_dir/.sync_time"
    # Sync the ".sync_time" file and execute local deletions on server.
    delete_output=$( rsync $sync_args -a --progress --delete --dry-run "$local_dir/" "$serve_dir" ) || return 11
    # Print any outputs that describe a deletion on the server.
    delete_output=$(echo "$delete_output" | sed 's:^.*deleting:deleting:g' | grep "deleting" | sed 's:^deleting ::g')
    if [ ${#delete_output} -gt 0 ] ; then
        echo " SERVER DELETIONS"
        echo ""
        echo "$delete_output" | add_line_prefix_to_stdin "  $SYNC_SERVER_DIR/"
        echo ""
        echo -n " Would you like to permantly delete all listed server files? (y/n) [y]? "
        read confirm
        confirm=${confirm:-y}
        confirm=$(echo -n "$confirm" | grep '^[Yy]\([eE][sS]\)\?$')
        # Only continue with the deletion if it was confirmed.
        if [ ${#confirm} -gt 0 ] ; then
            echo '  rsync '$sync_args' -a --delete "'$local_dir'/" "'$serve_dir'"'
            rsync $sync_args -a --delete "$local_dir/" "$serve_dir" || return 12
        fi
        echo ""
        echo "-------------------------------------------"
        echo ""
    fi
    # We have to send over the ".sync_time" file regardless.
    echo 'rsync '$sync_args' -a "'$local_dir/.sync_time'" "'$serve_dir'/"'
    rsync $sync_args -a "$local_dir/.sync_time" "$serve_dir/" || return 13

    # End of successful execution.
    return 0
}

# ====================================================================

# Get the "home" directory using "cd"
sync_start_dir=$(pwd); cd > /dev/null 2> /dev/null
sync_home=$(pwd);      cd "$sync_start_dir" > /dev/null 2> /dev/null
# Remove the extra 'start_dir' variable from the shell.
unset sync_start_dir
# Execute the confirution script if this file is not configured to this machine.
if [ ${#SYNC_SCRIPT_PATH} -eq 0 ] || [ ! -f "$sync_home/${SYNC_SCRIPT_PATH#$sync_home/}" ] ; then
    echo ""
    echo "The 'sync' utility does not appear to be configured for this machine."
    echo -n "  Would you like to configure (y/n) [y]? "
    read confirm
    echo ""
    confirm=${confirm:-y}
    confirm=$(echo -n "$confirm" | grep '^[Yy]\([eE][sS]\)\?$')
    # Only continue if the command was confirmed.
    if [ ${#confirm} -gt 0 ] ; then
        sync_configure
    else
        # If the user refuses to configure the sync script, then update
        # the file to prevent it from asking the question again.
        user_script_path=${user_script_path:-"$(pwd)/sync.sh"}
        echo    "To prevent further requests, provide the"
        echo -n " path to this 'sync' script: "
        read user_script_path
        user_script_path=${user_script_path:-"$(pwd)/sync.sh"}
        # Check to make sure the script file actually exists at that location.
        while [ ! -f "$user_script_path" ] ; do
            echo "No file exists at '$user_script_path'."
            echo -n "Enter full path to 'sync' script: "
            read user_script_path
            user_script_path=${user_script_path:-"$(pwd)/sync.sh"}
        done
        # Convert the provided path to an absolute path.
        start_dir=$(pwd)
        cd "$(dirname $user_script_path)" > /dev/null 2> /dev/null
        user_script_path=$(pwd)/$(basename $user_script_path)
        cd "$start_dir" > /dev/null 2> /dev/null
        # Update the "export SYNC_SCRIPT_PATH" line to prevent further questioning.
        replacement="$(echo "$user_script_path" | sed 's/[\/&]/\\&/g')"
        sed -i.backup "s/^export SYNC_SCRIPT_PATH=.*$/export SYNC_SCRIPT_PATH=$replacement/g" $user_script_path
        rm $user_script_path.backup
        echo ""
    fi
fi
# Remove the extra 'home' variable from the shell.
unset sync_home
