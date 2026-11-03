## EBS Instance Snapshot

## Summary:
When I start working with a new EBS system, I almost always want to gather basic information about it quickly, so I can get an overview of what I'm dealing with before I touch anything: release and patch level, installed products, languages, nodes, database version and the most important configuration details.

Oracle already provides tools for this, such as AD Configuration script ('adutconf.sql'), and many more. These can be used for troubleshooting of simply document the status of the installation. 
To get a first glance and overview of the installation I seldom need to use the comprehensive scripts from Oracle but feel a need for a more lightweight version.

EBS Instance Snapshot is my own lightweight alternative for that first look:

- Collects what I consider the essential startup information, nothing more.
- Short, readable output provided as a html report.
- No downloads from MOS needed, works on any EBS instance where you have APPS access, or better yet, a read only for this purpose.

It is not meant to replace Oracle's tools, but to give a quick and consistent starting point every time I begin working on a new system.

## Overview

Written for Linux (only tested on OEL8)

The toolkit includes the below files:

1. create_instance_snapshot.sh                         # The main shellscript
2. inc_functions                                       # Shell script fetching all needed information
3. variables                                           # Contains variables 
4. run_sql.sql                                         # All SQL for the Database and eBS sections 
5. parameters.lst                                      # A list of parameters to fetch from the system, init parameters, profile options and context parameters to check. Parameters can be added or withdrawn when needed.                          
   


Create a directory and place the above listed files in the newly created directory. Source the eBS environment and execute create_instance_snapshot.sh


## Installation

- Create a directory for the scripts in the location of choice.
- Place the files in the created directory.
- Make the scripts executable:

chmod +x create_instance_snapshot.sh
chmod +x inc_functions
chmod +x run_sql.sql 


## Usage

### Collect EBS Instance Information

./create_instance_snapshot.sh

Output : ./ebs_snapshot_$TWO_TASK_<DATE_time>.html

## Security Notes

- Consider creating a read only apps user and change the script to access the database using that user instead of apps.
- Verify the scripts and functions before use so they perform what you actually expect.
- Test in a non-production environment first.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome!

## Disclaimer

These scripts are provided as-is. All material is offered for free and in good faith but not guaranteed to be correct, up to date or suitable for any particular situation or purpose. 
Always test in a development environment before using in production. Ensure you have proper backups and follow your organization's change management procedures.
No liability is accepted in respect of the material and informatoin or its use.

These scripts were created on Linux 8 and have only been tested on that version. Compatibility with other Linux distributions or versions is not guaranteed.
