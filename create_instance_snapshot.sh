#!/bin/bash
#+======================================================================================================================================
#| File Name:
#| create_instance_snapshot.sh
#|
#| Description:
#| Fetching an overview of the eBS instance when starting working with a new system is important.
#| This tool collects the most important information about the OS, the database and eBS and creates a HTML report from it.
#| Use for eBS 12.2.3 and higher, on database 11.2.0.4, 12.1.0.2 or 19c (CDB/PDB).
#|
#| Usage:
#| Run as applmgr on an application tier node, with the run file system environment sourced:
#|   . $HOME/EBSapps.env run
#|   ./create_instance_snapshot.sh [system name]
#|
#| The APPS password is asked for. The system name is shown in the report title, it defaults to the PDB name
#| (database name on a non-CDB). The report is written to the tool directory as ebs_snapshot_<name>_<date>.html.
#| Warnings and errors are printed on screen, there is no log file.
#| The fetched data (lookup files) is held in a work directory in /tmp while running, it is removed at the end.
#|
#| How it works:
#|   1. Checks the environment and the APPS password
#|   2. Collects the data: runs run_sql.sql as APPS and reads the OS of this node (inc_functions)
#|   3. Builds the HTML report from the collected data (inc_functions)
#|
#| Files:
#| variables                     All variables
#| inc_functions                 All functions: environment check, SQL execution, data collection, HTML report, housekeeping
#| run_sql.sql                   All SQL for the Database and eBS sections
#| parameters.lst                The lists: init parameters, profile options and context file parameters, one section each
#|
#| Install on another server:
#| Copy the 5 files above into one directory, any name and place, as applmgr (i.e scp * othernode:Scripts/eBS_Snapshot/).
#| Needs only bash, sqlplus from the eBS environment and standard Linux commands (awk, sed, df, lscpu), no Python or Perl.
#| The directory must be writable for the report.
#|
#| Exit status: 0 = report created, 1 = stopped (environment, login or database version), 130/143 = interrupted
#|
#| Change History:
#|
#| 2026-10-18   0.1     Fredrik Lindkvist                       Creation
#| 2026-10-31   0.2     Fredrik Lindkvist                       eBS Applications section, version shown as RU, PDB name as default
#+======================================================================================================================================
#set -x
set -u  # Catch typos

PROGRAM_VERSION=0.3

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"         # Location of the script, works from any current directory

#+-------------
#| SETUP
#+-------------

# All files of the tool must be in the same directory as this script. Check that every file is here,
# so a file missed when copying to another server gives a clear error.
for tool_file in variables inc_functions run_sql.sql parameters.lst; do
        if [ ! -f "${SCRIPT_DIR}/${tool_file}" ]; then
                echo "Error: ${SCRIPT_DIR}/${tool_file} is missing, copy all files of the tool : Terminating Program"
                return 1 2>/dev/null || exit 1
        fi
done

# Include the variables and the function files.
. "${SCRIPT_DIR}/variables"                                           # All variables, creates the work directory ${TMP_DIR}
. "${SCRIPT_DIR}/inc_functions"                                        # All functions: environment check, collecting data, HTML report, housekeeping

# Credentials and the work directory are removed on every exit, also on Ctrl+C
trap 'housekeeping; exit 130' INT    # 130 is standard exit code for Ctrl+C
trap 'housekeeping; exit 143' TERM   # 143 is standard for SIGTERM
trap 'housekeeping' EXIT

# Stop before asking for the password if the eBS environment, the work directory or sqlplus is missing
check_environment
if [ ${EXITSTATUS} = 1 ]; then
        return 1 2>/dev/null || exit 1
fi

#+-------------
#| APPS LOGIN
#| Asks for the APPS password and tests the login, the program stops if it fails.
#| ${apps_connection_string} is used by run_sql_script() and unset by housekeeping() at exit.
#+-------------

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

#+-------------
#| MAIN PROGRAM
#| Every function returns at once if an earlier step set EXITSTATUS=1.
#+-------------

print_program_start
split_parameters                                                       # Sections of parameters.lst to the work directory
fetch_db_information                                                   # Runs all SQL, 2 Database, also the database host and version
fetch_ebs_information                                                  # 3 eBS Applications, from the same SQL run
fetch_os_information                                                   # 1 Operating System, needs the database host
create_html_report "${1:-}"                                            # Report in section order 1, 2, 3, $1 = optional system name
print_program_end

exit ${EXITSTATUS}
