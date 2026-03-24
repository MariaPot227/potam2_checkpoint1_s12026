#!/bin/bash

#File path of where the logs will go into put inside a variable which is used in the log function
LOG_FILE="/var/log/user_onboarding_audit.log"

#Log function to include timestamps and write to both console and log file
#The time gives each log a unique history
log() {
    local message="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

#splits the csv file at each comma , into three variables, username, groupname and shell
while IFS=',' read -r username groupname shell; do
#one user has multilple groups, this splits it into an array.
#-ra will read the raw text and split the input into an array
	IFS='/' read -ra grp_array <<< "$groupname"
	#VALIDATION Requirement 7
	#Validates username by:
	#starts with lower case letters, rest only allow lowercase, digits, _ or -, max 32 length
	#CONTINUE skips the rest of the current loop iteration and moves on, meaning if an error occurs, it moves onto the next line of the csv
	if ! [[ "$username" =~ ^[a-z][a-z0-9_-]{0,31}$ ]]; then
        	log "ERROR: Invalid username '$username' -- skipping"
        	continue
   	fi

	#checks if any variables are empty, missing fields will send a failure
 	if [[ -z "$username" || -z "$groupname" || -z "$shell" ]]; then
        	log "ERROR: Missing field(s) in record: '$username,$groupname,$shell' -- skipping"
        	continue
    	fi

	#verifies if the shell exists inside the etc directory, prevents any invalid login shells
	#grep -q is quiet mode (dont print) and -x is matching the entire line perfectlu
	#If matched, will exit code with 0, if not, a 1
    if ! grep -qx "$shell" /etc/shells; then
        	log "WARNING: Shell '$shell' not found in /etc/shells -- proceeding anyway"
    fi

	
	log "Processing user $username"

	#Requirement 1
	# Check if the user already exists before attempting creation.
	# id returns exit code 0 for an existing user, non-zero otherwise
	# Redirecting to /dev/null suppresses output we don't need here
	if id "$username" &>/dev/null; then
                log "$username exists"
                sudo usermod -s "$shell" "$username"
                log "Shell updated for $username"
    	else
                log "$username does not exist"
                sudo useradd -m -s "$shell" "$username"
                log "User '$username' created"
    	fi

	#Requirement 2
	#Checks if the group already exists before attempting creation
	#getent returns exit code 0 if the group is found and non zero if it does not exist. Redirecting to /dev/null hides output.
	#groupadd will fail if the group already exists, so it must be checked!
	for grp in "${grp_array[@]}"; do
		echo "$username belongs in $grp"
		if ! getent group "$grp" &>/dev/null; then
               		log "Group $grp does not exist"
                	sudo groupadd "$grp"
                	log "$grp created"
    	fi
		#usermod -aG appends the user to the supplementary group list(-G).
    	#without -a, it will append and overwrite all existing group memberships, which will cause issues
		log "Adding $username to groups: $grp"
		sudo usermod -aG "$grp" "$username"
    	groups "$username"
	
		#Requirement 3
		home_dir="/home/$username"

		#Checks if the home directory exists
		#Users that do not have a home directly will need one, needs to be checked
		#-p meaning if the full directory path doesnt exist, it will create the missing path.
		#Without -p, mkdir can fail if the directory exists.
    	if [[ ! -d "$home_dir" ]]; then
            	log "Home directory missing"
            	sudo mkdir -p "$home_dir"
    	fi

		#Sets ownership of the home directory to the user
		#this makes sure the user has full control over their home D
		#applying permission of 700
		#only this user will have access to their own home directory, no one else
		#This makes it secure and private 
    	sudo chown "$username":"$username" "$home_dir"
    	log "Set ownership of $home_dir to $username"

    	sudo chmod 700 "$home_dir"
    	log "Set permissions 700 on $home_dir."

		#Requirement 4
		proj_dir="/opt/projects/$username"

		#ensure the project directory exists, makes one if it doesnt under /opt/projects
    	if [[ ! -d "$proj_dir" ]]; then
        	log "Creating project directory $proj_dir"
            	sudo mkdir -p "$proj_dir"
    	fi

		#Sets ownership to user and its group
		#this is for projects and collaborative work, the whole group can access this directory
		#Applying permissions of 750, meaning the user has full access, and the group can only read/execute/
    	log "Set ownership of $proj_dir to $username:$grp"

    	sudo chmod 750 "$proj_dir"
    	log "Set permissions 750 on $proj_dir"
	
	done



	echo "_____________________________________"
	log "______________________________________"
done < users.csv





