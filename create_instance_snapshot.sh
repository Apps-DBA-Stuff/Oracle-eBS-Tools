#!/bin/bash
#+====================================================================================================================================
#| File Name:
#| create_instance_snapshot.sh
#|
#| Description:
#| Fetching an overview of the eBS instance when starting working with a new system is important.
#| This tool fetches the most information and creates a HTML report from it.
#| Use for 12.2.3 and higher.
#|
#| Usage:
#| ./create_instance_snapshot.sh
#|
#| Change History:
#|
#| 2026-10-18   0.1     Fredrik Lindkvist                         Creation
#+======================================================================================================================================
#set -x
set -u  # Catch typos

PROGRAM_VERSION=0.1

SCRIPT_DIR="$( pwd )"                           # Location of the script
DATE=$(date +"%Y-%m-%d_%H:%M:%S")               # Sysdate Variable
LOG_DIR=${SCRIPT_DIR}/log                       # Log directory
LOG_FILE="ebs_instance_snapshot_${DATE}.log"              # Log file Name

# Check if the Environment has been sourced
if [ -z "$APPL_TOP" ]; then
        echo "eBS environment has not been sourced, please source the environment and run the program again : Terminating Program"
        return 1 2>/dev/null || exit 1
fi

# Prompt user for APPS Password
read -s -p "Enter password for APPS User: " apps_password

# Set APPS User Credentials
APPS_USER=apps
apps_connection_string=${APPS_USER}/${apps_password}

# Removing the apps_password content, not needed anymore
unset apps_password

# Attempt to access the database in order to test the connection string
sqlplus -S -L "${apps_connection_string}" << EOF > /dev/null 2>&1
        EXIT;
EOF

# Check exit status of connection attempt.
if [ $? -ne 0 ]; then
        sleep 1
        echo "Login as APPS was Unsucessful, Terminating Program"
        return 1 2>/dev/null || exit 1
else
        sleep 1
        echo ""
        echo "Login as APPS was Sucessful, Proceeding"
fi
