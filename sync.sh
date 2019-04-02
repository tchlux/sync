# 
#    _______________________________
#   | AUTHOR   |  Thomas C.H. Lux   |
#   |          |                    |
#   | EMAIL    |  tchlux@vt.edu     |
#   |          |                    |
#   | VERSION  |  2019.04.02        |
#   |          |  Basic sync script |
#   |          |  with `sync` func. |
#   |__________|____________________|
# 
# 
# --------------------------------------------------------------------
#                             README
# 
#   This file provides a command-line function `sync` for
#   synchronizing a local directory with a server directory through
#   `ssh` and `rsync`. It keeps track of a file called `.sync_time`
#   containing the time since the Epoch in seconds to determine which
#   repository is more recent. Then the `rsync` utility is used to
#   transfer (and delete if appropriate) files between
#   `$SYNC_LOCAL_DIR` and `$SYNC_SERVER:$SYNC_SERVER_DIR` using the
#   efficient delta method of `rsync`. This can be very fast even for
#   large directories, certainly more so than a full `scp`.
# 
#   This tool provides a one-liner replacement for something like
#   Dropbox or Git that can be used easily from a server with a POSIX
#   interface, `pwd`, `export`, `cd`, `mkdir`, `read`, `echo`, `cat`,
#    `sed`, `grep`, `rsync` and `python`.
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
#     if <condition> ; then <true body> ; elif <condition> ; then <true body> ; else <false body> ; fi
# 
#   Along with the standard POSIX expectations above, the following
#   commands are used by this program with the demonstrated syntax.
# 
#     pwd (no arguments / prints full path to present working directory)
#     dirname <path to get only directory name>
#     basename <path to get only file name>
#     rm <path to file to remove>
#     cd <directory to move to>
#     mkdir -p <directory to create if it does not already exist>
#     export <varname>=<value>
#     read -e -p "<user input prompted with directory tab-auto-complete>"
#     echo "<string to output to stdout>"
#     cat <path to file that will be printed to stdout>
#     sed -i.backup "s/<match pattern>/<replace pattern in-file>/g" <file-name>
#     grep "<regular expression>" <file to find matches>
#     rsync -az -e "<remote shell command>" --update --delete --progress <source-patah> <destination-path>
#     python -c "<python 2 / 3 compatible code>"
# 
# 
# ## USAGE:
# 
#     $ sync [--status] [--configure] [path=$SYNC_LOCAL_DIR]
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
#   A script is provided that will automatically walk you through
#   configuration on your local machine. If this file is executed and
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

# Use Python to convert seconds since the epoch to a local time date string.
seconds_to_date () {
    command="import time; print(time.ctime($1))"
    echo $(python -c "$command" || python3 -c "$command")
}

# Use Python to generate the time since the epoch in seconds.
time_in_seconds () {
    command="import time; print(int(time.time()))"
    echo $(python -c "$command" || python3 -c "$command")
}

# Function for displaying the current configuration to the user.
sync_show_configuration () {
    echo "'sync' command configured with the following:"
    echo ""
    echo " SYNC_SCRIPT_PATH: "$SYNC_SCRIPT_PATH
    echo " SYNC_SERVER:      "$SYNC_SERVER
    echo " SYNC_SERVER_DIR:  "$SYNC_SERVER_DIR
    echo " SYNC_LOCAL_DIR:   "$SYNC_LOCAL_DIR
    if [ ${#SYNC_SSH_ARGS} -gt 0 ] ; then
	echo " SYNC_SSH_ARGS:    "$SYNC_SSH_ARGS
    fi
}

# The initial setup script, this will modify the contents of this file
# for future executions. It will also attempt to verify that
# passwordless login has been properly configured on the local machine
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
    read -e -p "Full path to THIS 'sync' script (default '$home/${default_user_script_path#$home/}'): " user_script_path
    user_script_path=${user_script_path:-$default_user_script_path}
    # Check to make sure the script file actually exists at that location.
    while [ ! -f "$home/${user_script_path#$home/}" ] ; do
	echo "No file exists at '$home/${user_script_path#$home/}'."
	read -e -p "Full path to 'sync' script (default '$home/${default_user_script_path#$home/}'): " user_script_path
	user_script_path=${user_script_path:-$default_user_script_path}
    done
    # Read the rest of the configuration values.
    read -e -p "Server ssh identity (default '$default_user_server'): " user_server
    read -e -p "  extra ssh flags (default '$default_user_ssh_args'): " user_ssh_args
    read -e -p "Master sync dirctory on server (default '$default_user_server_dir'): " user_server_dir
    read -e -p "Local sync dirctory (default '$home/${default_user_local_dir#$home/}'): " user_local_dir
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
    cd $(dirname "$user_local_dir") > /dev/null 2> /dev/null
    user_local_dir=$(pwd)/$(basename "$user_local_dir")
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
    # Make sure the "SYNC_LOCAL_DIR" exists.
    cd > /dev/null 2> /dev/null
    mkdir -p "$SYNC_LOCAL_DIR"
    cd "$start_dir" > /dev/null 2> /dev/null
    # Print out the configuration to the user.
    echo ""
    sync_show_configuration
    # Ask about optional extra configuration steps..
    echo ""
    read -p "Configure passwordless ssh (y/n) [n]? " user_query
    user_query=${user_query:-n}
    user_query=$(echo -n "$user_query" | grep "^[Yy][eE]*[sS]*$")
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
    read -p " Add 'sync' command to shell initialization (y/n) [n]? " user_query
    user_query=${user_query:-n}
    user_query=$(echo -n "$user_query" | grep "^[Yy][eE]*[sS]*$")
    if [ ${#user_query} -gt 0 ] ; then
	# Ask where to put the 'source' line.
	read -e -p "Shell initialization file (default '$home/.profile'): " user_shell_init	
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
    SYNC_SERVER_TIMESTAMP=$(ssh $SYNC_SSH_ARGS $SYNC_SERVER "cat $SYNC_SERVER_DIR/.sync_time 2> /dev/null || echo '0'") || return 1
    # Create a ".sync_time" file locally if it does not exist.
    if [ ! -f $local_dir/.sync_time ] ; then
	# If a local sync doesn't exist, we need to set the local time
	# stamp to be a value certainly less, and copy from the
	# master to the local! This date corresponds to '0' seconds.
	echo "0" > $local_dir/.sync_time
    fi
    # Default value of the master timestamp is the second count "0".
    export SYNC_SERVER_TIMESTAMP=${SYNC_SERVER_TIMESTAMP:-"0"}
    export SYNC_LOCAL_TIMESTAMP=$(cat $local_dir/.sync_time)
    # Ask about optional extra configuration steps..
    echo ""
    echo "-------------------------------------------"
    echo "Server directory last synchronization date:"
    echo "  $(seconds_to_date $SYNC_SERVER_TIMESTAMP)"
    echo ""
    echo "Local directory last synchronization date:"
    echo "  $(seconds_to_date $SYNC_LOCAL_TIMESTAMP)"
    echo "-------------------------------------------"
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
    # Get the relative directory as a command line argument.
    relative=$1
    # Use the provided path, otherwise default to the local directory.
    if [ ${#relative} -gt 0 ] ; then
	# If the user wants to reconfigure, call that script.
	if [ "$1" == "--configure" ] ; then sync_configure                        ; return 0
	# If the user wants the status, call that script.
	elif [ "$1" == "--status" ]  ; then
	    sync_status
	    sync_show_configuration
	    echo ""
	    return 0
	# Otherwise assume the user provided a directory to sync.
	# Check to make sure that directory exists, then move to it.
	elif [ ! -d "$1" ] ; then
	    echo "'$1' directory does not exist."
	    return 1
	else cd "$1" > /dev/null 2> /dev/null
	fi
    else
	# By default, when no parameters are provided, sync whole directory.
	cd "$local_dir" > /dev/null 2> /dev/null
    fi
    # Store the current directory (to be synchronized for later use).
    sync_dir=$(pwd)
    # Call the "sync_status" function that updates the time stamps.
    cd "$start_dir" > /dev/null 2> /dev/null
    sync_status || return 1
    # Compare the local and the master to determinex "source" and "destination".
    if [ "$SYNC_SERVER_TIMESTAMP" -gt "$SYNC_LOCAL_TIMESTAMP" ] ; then
	# The master is newer!
	dst="$sync_dir/"
	relative="${dst#$local_dir/}"
	src=$SYNC_SERVER:$SYNC_SERVER_DIR/$relative
    else
	# The local is newer!
	src="$sync_dir/"
	relative="${src#$local_dir/}"
	dst=$SYNC_SERVER:$SYNC_SERVER_DIR/$relative
    fi
    # Create directories in master (in case the path does not exist).
    # Get the ".sync_time" time, redirect "File not found" error, it's ok.
    ( ssh $SSH_ARGS $SYNC_SERVER "mkdir -p $SYNC_SERVER_DIR/$relative || exit 0" ) || return 1
    # Make sure that we are actually in a subdirecty of "SYNC_LOCAL_DIR".
    if [ "${relative:0:1}" == "/" ] ; then
    	# Raise an error.
    	echo "ERROR: Must specify (a subset of) '$local_dir' to sync."
	echo "  $relative"
    else
	extra_args=""
	if [ ${#SYNC_SSH_ARGS} -gt 0 ] ; then
	    extra_args=" -e \"ssh $SYNC_SSH_ARGS\""
	fi
    	# Execute the command.
    	echo "Sync from: $src"
    	echo " --> to:   $dst"
    	echo ""
    	echo "rsync -az$extra_args --update --delete --progress $src $dst"
    	echo ""
	# Wrap the asking a question into cd'ing to the start
	# directory in case the user cancels during this operation.
	read -p "Confirm (y/n) [y]? " confirm
	confirm=${confirm:-y}
	confirm=$(echo -n "$confirm" | grep "^[Yy][Ee]*[Ss]*$")
	# Only continue if the command was confirmed.
	if [ ${#confirm} -gt 0 ] ; then
	    echo ""
    	    # Always update the ".sync_time" date on self.
    	    time_in_seconds > $local_dir/.sync_time
	    # Sync (and hence copy the '.sync_time' file as well.
	    if [ ${#SYNC_SSH_ARGS} -gt 0 ] ; then
		# Pass special ssh arguments to rsync.
    		rsync -az -e "ssh $SYNC_SSH_ARGS" --update --delete --progress $src $dst
	    else
		# Don't pass any special ssh arguments.
    		rsync -az --update --delete --progress $src $dst
	    fi
	else
	    read -p "Swap order and sync (y/n) [n]? " confirm
	    confirm=${confirm:-n}
	    confirm=$(echo -n "$confirm" | grep "^[Yy][Ee]*[Ss]*$")
	    if [ ${#confirm} -gt 0 ] ; then
		# Swap the variables and execute.
		confirm="$src"
		src="$dst"
		dst="$confirm"
		echo ""
    		# Always update the ".sync_time" date on self.
    		time_in_seconds > $local_dir/.sync_time
		# Sync (and hence copy the '.sync_time' file as well.
		if [ ${#SYNC_SSH_ARGS} -gt 0 ] ; then
		    # Pass special ssh arguments to rsync.
    		    rsync -az -e "ssh $SYNC_SSH_ARGS" --update --delete --progress $src $dst
		else
		    # Don't pass any special ssh arguments.
    		    rsync -az --update --delete --progress $src $dst
		fi		
	    fi
	    # ^ End of "Swap order?" block.
	fi
	# ^ End of "Confirm sync?" block.
    fi
    # ^ End of "Is valid path to synchronize?" block.
    echo ""
}

# ====================================================================

# Get the "home" directory using "cd"
start_dir=$(pwd); cd > /dev/null 2> /dev/null
home=$(pwd);      cd "$start_dir" > /dev/null 2> /dev/null
# Execute the confirution script if this file is not configured to this machine.
if [ ${#SYNC_SCRIPT_PATH} -eq 0 ] || [ ! -f "$home/${SYNC_SCRIPT_PATH#$home/}" ] ; then
    echo ""
    echo "The 'sync' utility does not appear to be configured for this machine."
    read -p "  Would you like to configure (y/n) [y]? " confirm
    echo ""
    confirm=${confirm:-y}
    confirm=$(echo -n "$confirm" | grep "^[Yy][Ee]*[Ss]*$")
    # Only continue if the command was confirmed.
    if [ ${#confirm} -gt 0 ] ; then
	sync_configure
    else
	# If the user refuses to configure the sync script, then update
	# the file to prevent it from asking the question again.
	user_script_path=${user_script_path:-"$(pwd)/sync.sh"}
	echo "To prevent further requests, provide the"
	read -e -p " full path to the 'sync' script: " user_script_path
	user_script_path=${user_script_path:-"$(pwd)/sync.sh"}
	# Check to make sure the script file actually exists at that location.
	while [ ! -f "$user_script_path" ] ; do
	    echo "No file exists at '$user_script_path'."
	    read -e -p "Enter full path to 'sync' script: " user_script_path
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
