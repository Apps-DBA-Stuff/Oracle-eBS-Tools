## EBS Instance Snapshot

## Summary:
When I start working with a new EBS System I in most cases want to gather information about the system really quick so i can  

## Overview

Written for Linux (only tested on OEL8)

The toolkit includes the below files scripts:

1. create_instance_snapshot.sh                         # The main shellscript
2. inc_fech_os_info                                    # Shell script fetching information about the operating system.
3. inc_fetch_db_info                                   # Shell script
4. inc_fetch_ebs_info
5. inc_help
6. inc_prepare
7. inc_htmp_report
8. db_info.sql    # SQL script
9. ebs_info.sql


Create a directory and place the files in the repo in the newly created directory. Source the eBS environment.
1. run create_instance_snapshot.sh


## Installation

- Create a directory for the scripts in the location of choice.
- Place the files in the created directory.
- Make the scripts executable:

chmod +x pwdgen
chmod +x change_product_pwds.sh
chmod +x set_default_product_pwds.sh


## Usage

### Collect EBS Instance Information

./create_instance_snapshot.sh


### Change All Product Passwords to Random Values

-- See to that tbe eBS Environment has been sourced before using.
./change_product_pwds.sh

This script will:
- Use `pwdgen` to generate random passwords
- Apply them to all Oracle EBS product schemas (GL, AR, AP, PO, INV, etc.)
- Producing a logfile with information.

### Reset All Product Passwords to Defaults

-- See to that tbe eBS Environment has been sourced before using.
./set_default_product_pwds.sh

This script will: 
- Restore the original default passwords for all product schemas.

## Security Notes

- Always store generated passwords securely
- Consider your organization's password policies before using these scripts
- Test in a non-production environment first

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome!

## Disclaimer

These scripts are provided as-is. All material is offered for free and in good faith but not guaranteed to be correct, up to date or suitable for any particular situation or purpose. 
Always test in a development environment before using in production. Ensure you have proper backups and follow your organization's change management procedures.
No liability is accepted in respect of the material and informatoin or its use.

These scripts were created on Linux 8 and have only been tested on that version. Compatibility with other Linux distributions or versions is not guaranteed.
