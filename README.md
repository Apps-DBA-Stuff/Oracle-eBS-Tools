Summary:
When starting working with a new eBS system I really quick want an overview of the system. Oracle has script that can be used to collect information about the whole installation, codelevels, profile values, concurrent managers etc but  i want  

Overview
Written for Linux (only tested on OEL8)

The toolkit includes the below files scripts:

pwdgen # Shellscript to generate passwords for different accounts, can be from 12 to 64 characters containing capital letters and digits 0-9
products.txt # Contains all the product users in eBS R12
change_product_pwds.sh # Shellscript used to change the password for all eBS product accounts, calling pwdgen to create passwords.
set_default_product_pwds.sh # Shell script resetting the password for all eBS product accounts to default if needed.
Create a directory and place the files in the repo in the newly created directory. Source the eBS environment.

run change_product_pwds.sh to set new passwords for all ebs Products users.
run set_default_product_pwds.sh to set all the passwords back to defa ult.
The script pwdgen can also be used standalone. $TWO_TASK needs to be set for pwdgen to work Standalone. It can then be used just go as a simple password generator.

Scope and limitations


change_product_pwds.sh and set_default_product_pwds.sh are only for Oracle EBS product schemas (GL, AR, AP, PO, INV, WMS etc.) as listed in products.txt. Do not use them for:

APPS, APPLSYS or APPS_NE: change these with FNDCPASS ... SYSTEM APPLSYS or AFPASSWD -a, followed by AutoConfig.
SYSADMIN or other application (FND) users.
SYS, SYSTEM or other database administration accounts.
Note that set_default_product_pwds.sh resets every product schema to its default password, which is the same as the username (e.g. GL/GL). Only use it in non-production environments or when you need to restore the default state.

Installation
Create a directory for the scripts in the location of choice.
Place the files in the created directory.
Make the scripts executable:
chmod +x pwdgen chmod +x change_product_pwds.sh chmod +x set_default_product_pwds.sh

Usage
Generate Random Passwords
-- While designed for EBS, the pwdgen script can be used standalone to generate random passwords between 12 and 64 characters for any installation (default 12 characters). For standalone use, simply set the $TWO_TASK environment variable to any value before running.

./pwdgen USERNAME [LENGTH]

Change All Product Passwords to Random Values
-- See to that tbe eBS Environment has been sourced before using. ./change_product_pwds.sh

This script will:

Use pwdgen to generate random passwords
Apply them to all Oracle EBS product schemas (GL, AR, AP, PO, INV, etc.)
Producing a logfile with information.
Reset All Product Passwords to Defaults
-- See to that tbe eBS Environment has been sourced before using. ./set_default_product_pwds.sh

This script will:

Restore the original default passwords for all product schemas.
Security Notes
Always store generated passwords securely
Consider your organization's password policies before using these scripts
Test in a non-production environment first

License
This project is licensed under the MIT License - see the LICENSE file for details.

Contributing
Contributions are welcome!

Disclaimer
These scripts are provided as-is. All material is offered for free and in good faith but not guaranteed to be correct, up to date or suitable for any particular situation or purpose. Always test in a development environment before using in production. Ensure you have proper backups and follow your organization's change management procedures. No liability is accepted in respect of the material and informatoin or its use.

These scripts were created on Linux 8 and have only been tested on that version. Compatibility with other Linux distributions or versions is not guaranteed.
