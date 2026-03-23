#!/bin/bash

LOG_FILE="/var/log/user_onboarding_audit.log"

log() {
    local message="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

while IFS=',' read -r username groupname shell; do
	#VALIDATION Requirement 7
	if ! [[ "$username" =~ ^[a-z][a-z0-9_-]{0,31}$ ]]; then
        	log "ERROR: Invalid username '$username' -- skipping"
        	continue
   	fi

 	if [[ -z "$username" || -z "$groupname" || -z "$shell" ]]; then
        	log "ERROR: Missing field(s) in record: '$username,$groupname,$shell' -- skipping"
        	continue
    	fi

    	if ! grep -qx "$shell" /etc/shells; then
        	log "WARNING: Shell '$shell' not found in /etc/shells -- proceeding anyway"
    	fi

	log "Name: $username | Group: $groupname | Shell: $shell"
	log "Processing user $username"

	#Requirement 1
	#usermod -s : usermod modifies an existing user account
	#Chance this users default shell to be the one defined in $shell, it will show no changes if nothing has changed.
	#id is a command that shows information about a user
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

	if ! getent group "$groupname" &>/dev/null; then
               	log "$groupname does not exist"
                sudo groupadd "$groupname"
                log "$groupname created"
    	fi
	#usermod -aG appends the group to the users existing groups without removing any of the existing memberships.
	log "Adding $username to group $groupname"
    	sudo usermod -aG "$groupname" "$username"
    	groups "$username"

	#Requirement 3
	#make a variable with path of the home directory
	home_dir="/home/$username"
	#Checking if there is a directory associated with the account of the user, and if it doesnt, it will create one
    	if [[ ! -d "$home_dir" ]]; then
            	log "Home directory missing"
            	sudo mkdir -p "$home_dir"
    	fi	
	#assigns ownership of the home dir to the user, meaning they will have full control over their personal files
    	sudo chown "$username":"$username" "$home_dir"
    	log "Set ownership of $home_dir to $username"
	#Apply permission of 700 (execute) so only the user can access the home (look at the zeros on groups and others section)
	#This protects the files found in the home, makes home directory secure
    	sudo chmod 700 "$home_dir"
    	log "Set permissions 700 on $home_dir."

	#Requirement 4
	proj_dir="/opt/projects/$username"

	
    	if [[ ! -d "$proj_dir" ]]; then
        	log "Creating project directory $proj_dir"
            	sudo mkdir -p "$proj_dir"
    	fi
	#Set ownership so user can own the directory, but groups can also have access. This allows group members to see the contents of the directory and can set specific permissions like in below
    	sudo chown "$username":"$groupname" "$proj_dir"
    	log "Set ownership of $proj_dir to $username:$groupname"
	#Apply permissions of 750, meaning user has full access, while members have read/execute
	#others still have zero access or permissions
    	sudo chmod 750 "$proj_dir"
    	log "Set permissions 750 on $proj_dir"

	echo "_____________________________________"

done < users.csv





