# EBS Instance Snapshot

## Summary

When I start working with a new EBS system, I almost always want to gather basic information about it quickly, so I can get an overview of what I'm dealing with before I touch anything: release and patch level, installed products, languages, nodes, database version and the most important configuration details.

Oracle already provides tools for this, such as the AD Configuration script (`adutconf.sql`) and many more. These can be used for troubleshooting or simply to document the status of an installation. For a first look and overview, though, I seldom need Oracle's comprehensive scripts and wanted something more lightweight.

EBS Instance Snapshot is the lightweight alternative I created for that first look. AI was used for debugging, for creating the HTML report part, and for cleaning up the scripts (finding duplication and suggesting a better code structure).

- Collects what I consider the essential startup information, nothing more.
- Short, readable output as an HTML report.
- No downloads from MOS needed. Works on any EBS instance where you have APPS access.

It is not meant to replace Oracle's tools, but to give a quick and consistent starting point every time I begin working on a new system.

## What the report contains

- <section 1, e.g. EBS release and patch level>
- <section 2, e.g. installed products and languages>
- <section 3, e.g. nodes and services>
- <section 4, e.g. database version and init parameters>
- <section 5, e.g. selected profile options and context file parameters>

## Requirements

- Oracle Linux 8 (only tested on OL8)
- Oracle E-Business Suite <12.1 / 12.2>
- APPS access to the database

## Files

```
create_instance_snapshot.sh   The main shell script
inc_functions                 Functions that collect all needed information
variables                     Variables used by the scripts
run_sql.sql                   All SQL for the database and EBS sections
parameters.lst                Init parameters, profile options and context file
                              parameters to check. Add or remove entries as needed.
```

## Installation

Create a directory for the scripts, place the files in it and make the main script executable:

```bash
mkdir -p /path/of/choice/ebs_snapshot
cd /path/of/choice/ebs_snapshot
chmod +x create_instance_snapshot.sh
chmod +x run_sql.sql
chmod +x inc_functions
```

## Usage

Source the EBS environment (for 12.2, the run file system), then run the script:

Output: `ebs_snapshot_<TWO_TASK>_<timestamp>.html` in the current directory.

## Security Notes

- The script connects as APPS. To use a dedicated read-only user instead, change the connection in the script and give that user the required SELECT grants and synonyms (the SQL relies on APPS synonyms).
- Review the scripts and functions before use so you know they do what you expect.
- Test in a non-production environment first.

## License

This project is licensed under the MIT License. See the LICENSE file for details.

## Contributing

Contributions are welcome. Open an issue or a pull request.

## Disclaimer

These scripts are provided as-is. All material is offered for free and in good faith, but is not guaranteed to be correct, up to date or suitable for any particular situation or purpose. Always test in a development environment before using in production, make sure you have proper backups, and follow your organization's change management procedures. No liability is accepted for the material and information or its use.

The scripts were created on Oracle Linux 8 and have only been tested there. Compatibility with other Linux distributions or versions is not guaranteed.
