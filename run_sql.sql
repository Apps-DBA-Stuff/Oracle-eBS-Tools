--+======================================================================================================================
--| File Name:
--| run_sql.sql
--|
--| Description:
--| All SQL of the eBS Instance Snapshot, run as APPS in one sqlplus session: first the Database queries (report
--| section 2 and the database host), then the eBS Applications queries (report section 3).
--| Each query below is one block that writes its rows to its own lookup file in the directory given as &1.
--| One row per line, columns separated by |. The report shows each lookup file as a table.
--|
--|   Lookup file                       Report          Contents
--|   db_version.lookup                 (program)       Database version, the program stops if it's missing
--|   db_overview.lookup                2.1             Overview
--|   db_parameters.lookup              2.2             All init parameters, the ones in parameters.lst are shown
--|   db_redo.lookup                    2.3             Online redo log members
--|   db_size.lookup                    2.4             Database size
--|   db_tablespaces.lookup             2.4             Tablespace usage
--|   db_resource_limits.lookup         2.5             Resource limits
--|   db_invalid_objects.lookup         2.5             Invalid objects
--|   db_os.lookup                      1.1, 1.2        Host name, CPU and memory of the database host
--|   ebs_overview.lookup               3.1             Overview
--|   ebs_profiles.lookup               3.2             All profile options, the ones in parameters.lst are shown
--|   ebs_profile_changes.lookup        3.2             Profile values changed since the instance was created
--|   ebs_debug_profiles.lookup         3.3             Trace and Debug profiles set to Y at site level or set for a user
--|   ebs_nodes.lookup                  3.4             Nodes
--|   ebs_adop_sessions.lookup          3.5             adop cycles
--|   ebs_context_files.lookup          3.6             Context files, run file system and database tier
--|   (bash, not SQL)                   3.7             Context file parameters, read from $CONTEXT_FILE in inc_functions
--|   ebs_managers.lookup               3.8             Concurrent managers
--|   ebs_workflow.lookup               3.9             Workflow
--|
--| Executed by run_sql_script() in inc_functions.
--| Works on 11.2.0.4, 12.1.0.2 and 19c (CDB/PDB) with the 10.1.2 sqlplus client of the application tier.
--+======================================================================================================================

-- Plain rows only: no headings, page breaks, feedback or substitution messages in the lookup files.
set termout off
set heading off
set pagesize 0
set feedback off
set verify off
set trimspool on
set linesize 4000

-- Continue after an error, so one failing query (i.e a missing grant, ORA-00942) doesn't stop the others.
-- The error is spooled to that query's lookup file, check_lookup_file() in inc_functions renames it to .err
whenever sqlerror continue

--+======================================================================================================================
--| DATABASE, report section 2 and the database host
--+======================================================================================================================

--+--------------------------------------------------------------------
--| Version dependent columns
--| Some columns don't exist on older versions, the right expression is chosen here once and used below as
--| &version_col, &cdb_col and &con_col:
--|   version_col   major.RU from version_full on 18c and higher (i.e 19.26), the full version before that
--|   cdb_col       v$database.cdb from 12c, 'NO' on 11g
--|   con_col       container (PDB) name from 12c, '-' on 11g
--+--------------------------------------------------------------------
column version_col new_value version_col noprint
column cdb_col new_value cdb_col noprint
column con_col new_value con_col noprint
select case when to_number(substr(version, 1, instr(version, '.') - 1)) >= 18
            then 'substr(version_full, 1, instr(version_full, ''.'', 1, 2) - 1)'
            else 'version' end version_col,
       case when to_number(substr(version, 1, instr(version, '.') - 1)) >= 12
            then 'cdb'
            else '''NO''' end cdb_col,
       case when to_number(substr(version, 1, instr(version, '.') - 1)) >= 12
            then 'sys_context(''USERENV'', ''CON_NAME'')'
            else '''-''' end con_col
from v$instance;

--+--------------------------------------------------------------------
--| db_version
--| Report: used by the program, stops the run if no version is returned
--| Database version, i.e 19.26.
--| Output: version
--+--------------------------------------------------------------------
spool &1/db_version.lookup
select &version_col from v$instance;
spool off

--+--------------------------------------------------------------------
--| db_overview
--| Report: 2.1 Overview
--| Key|value rows, the order column o keeps the rows in report order.
--| Database Name is the CDB name on a multitenant database. Pluggable Database Name only on a multitenant
--| database, Fast Recovery Area size only when a location is set.
--| Status = the instance status, on RAC one instance=status per instance (gv$instance).
--| Output: key|value
--+--------------------------------------------------------------------
spool &1/db_overview.lookup
select k || '|' || v from (
select 1 o, 'Database Name' k, name v from v$database
union all select 2, 'Pluggable Database Name', &con_col from v$database where &cdb_col = 'YES'
union all select 3, 'Status',
          decode(count(*), 1, max(status),
                 listagg(instance_name || '=' || status, ', ') within group (order by inst_id))
          from gv$instance
union all select 4, 'Created', to_char(created, 'YYYY-MM-DD HH24:MI') from v$database
union all select 5, 'Edition', banner from v$version where banner like 'Oracle%'
union all select 6, 'Version', &version_col from v$instance
union all select 7, 'Startup Time', to_char(startup_time, 'YYYY-MM-DD HH24:MI') from v$instance
union all select 8, 'Uptime (days)', to_char(round(sysdate - startup_time, 1), 'FM99990.0') from v$instance
union all select 9, 'Database Role', database_role from v$database
union all select 10, 'Archive Log Mode', log_mode from v$database
union all select 11, 'Force Logging', force_logging from v$database
union all select 12, 'Flashback', flashback_on from v$database
union all select 13, 'Multitenant', &cdb_col from v$database
union all select 14, 'Character Set', value from nls_database_parameters where parameter = 'NLS_CHARACTERSET'
union all select 15, 'National Character Set', value from nls_database_parameters where parameter = 'NLS_NCHAR_CHARACTERSET'
union all select 16, 'Fast Recovery Area', nvl(value, 'not configured') from v$parameter where name = 'db_recovery_file_dest'
union all select 17, 'Fast Recovery Area Size (GB)', to_char(round(value / power(1024, 3), 1), 'FM9999990.0')
          from v$parameter
          where name = 'db_recovery_file_dest_size'
          and exists (select 1 from v$parameter where name = 'db_recovery_file_dest' and value is not null)
) order by o;
spool off

--+--------------------------------------------------------------------
--| db_parameters
--| Report: 2.2 Init Parameters
--| All init parameters. build_vital_parameters() picks the ones in parameters.lst.
--| A | in a value is replaced by / so it doesn't split the columns.
--| Output: name|value
--+--------------------------------------------------------------------
spool &1/db_parameters.lookup
select name || '|' || replace(value, '|', '/')
from v$parameter
order by name;
spool off

--+--------------------------------------------------------------------
--| db_redo
--| Report: 2.3 Transaction Management / Online / Standby Redo Log Files
--| One row per log member, the user's query (custom_queries.md). Standby redo logs are in v$standby_log, not listed here.
--| Output: thread|group|member|size mb|blocksize
--+--------------------------------------------------------------------
spool &1/db_redo.lookup
select g.thread# || '|' || g.group# || '|' || f.member || '|' || g.bytes / 1024 / 1024 || '|' || g.blocksize
from v$log g, v$logfile f
where g.group# = f.group#
order by g.thread# asc, g.group# asc, f.member asc;
spool off

--+--------------------------------------------------------------------
--| db_size
--| Report: 2.4 Storage
--| Used space is allocated minus dba_free_space, dba_segments is too slow on large EBS databases.
--| Output: key|value
--+--------------------------------------------------------------------
spool &1/db_size.lookup
select k || '|' || v from (
select 1 o, 'Datafiles Allocated (GB)' k, to_char(round(sum(bytes) / power(1024, 3), 1), 'FM9999990.0') v
       from dba_data_files
union all select 2, 'Datafiles Used (GB)',
       to_char(round(((select sum(bytes) from dba_data_files) - (select nvl(sum(bytes), 0) from dba_free_space))
                     / power(1024, 3), 1), 'FM9999990.0')
       from dual
union all select 3, 'Tempfiles (GB)', to_char(round(nvl(sum(bytes), 0) / power(1024, 3), 1), 'FM9999990.0')
       from dba_temp_files
union all select 4, 'Datafile Count', to_char(count(*)) from dba_data_files
union all select 5, 'Tablespace Count', to_char(count(*)) from dba_tablespaces
) order by o;
spool off

--+--------------------------------------------------------------------
--| db_tablespaces
--| Report: 2.4 Storage
--| Tablespace usage, fullest first. Max is the autoextend max size (or the size for a file without
--| autoextend), used percent is calculated against it.
--| Autoextend = YES when all datafiles autoextend, NO when none does, otherwise "n of m".
--| Output: tablespace|contents|datafiles|autoextend|allocated gb|max gb|used gb|used pct
--+--------------------------------------------------------------------
spool &1/db_tablespaces.lookup
select d.tablespace_name || '|' || t.contents || '|' || d.files || '|' ||
       decode(d.ae_files, 0, 'NO', d.files, 'YES', d.ae_files || ' of ' || d.files) || '|' ||
       to_char(round(d.mb / 1024, 1), 'FM9999990.0') || '|' ||
       to_char(round(d.maxmb / 1024, 1), 'FM9999990.0') || '|' ||
       to_char(round((d.mb - nvl(f.mb, 0)) / 1024, 1), 'FM9999990.0') || '|' ||
       to_char(round((d.mb - nvl(f.mb, 0)) * 100 / d.maxmb, 1), 'FM990.0')
from (select tablespace_name, count(*) files,
             sum(decode(autoextensible, 'YES', 1, 0)) ae_files,
             sum(bytes) / 1048576 mb,
             sum(greatest(bytes, decode(autoextensible, 'YES', maxbytes, bytes))) / 1048576 maxmb
      from dba_data_files
      group by tablespace_name) d,
     (select tablespace_name, sum(bytes) / 1048576 mb
      from dba_free_space
      group by tablespace_name) f,
     dba_tablespaces t
where d.tablespace_name = f.tablespace_name (+)
and   d.tablespace_name = t.tablespace_name
order by (d.mb - nvl(f.mb, 0)) / d.maxmb desc;
spool off

--+--------------------------------------------------------------------
--| db_resource_limits
--| Report: 2.5 Health
--| Processes, sessions and parallel servers against their limit. Percent is the highest
--| use since startup. v$resource_limit is empty in a PDB, then the current use is counted from v$process,
--| v$session and v$px_process instead (max since startup = n/a).
--| Output: resource|current|max since startup|limit|pct of limit
--+--------------------------------------------------------------------
spool &1/db_resource_limits.lookup
select resource_name || '|' || current_utilization || '|' || max_utilization || '|' || trim(limit_value) || '|' ||
       case when trim(limit_value) in ('UNLIMITED', '0') then null
            else to_char(round(max_utilization * 100 / to_number(trim(limit_value)), 1), 'FM990.0') end
from v$resource_limit
where resource_name in ('processes', 'sessions', 'parallel_max_servers')
union all
select r.name || '|' || r.cur || '|n/a|' || p.value || '|' ||
       case when to_number(p.value) > 0 then to_char(round(r.cur * 100 / to_number(p.value), 1), 'FM990.0') end
from (select 'processes' name, count(*) cur from v$process
      union all select 'sessions', count(*) from v$session
      union all select 'parallel_max_servers', count(*) from v$px_process) r,
     v$parameter p
where p.name = r.name
and   not exists (select 1 from v$resource_limit)
order by 1;
spool off

--+--------------------------------------------------------------------
--| db_invalid_objects
--| Report: 2.5 Health
--| Number of invalid objects per owner and object type, most first.
--| Output: owner|object type|count
--+--------------------------------------------------------------------
spool &1/db_invalid_objects.lookup
select owner || '|' || object_type || '|' || count(*)
from dba_objects
where status = 'INVALID'
group by owner, object_type
order by count(*) desc, owner, object_type;
spool off

--+--------------------------------------------------------------------
--| db_os
--| Report: 1.2 DB Tier, only shown when the database runs on a separate host
--| Host name, CPU and memory of the database host. The host name is also used for 1.1 Tiers, to see
--| if the database runs on the application tier node. v$osstat is a live view, no Diagnostics Pack needed
--| (DBA_HIST_OSSTAT would need it). NUM_CPU_CORES and NUM_CPU_SOCKETS are missing on some platforms,
--| they are shown as -
--| Output: key|value
--+--------------------------------------------------------------------
spool &1/db_os.lookup
select k || '|' || v from (
select 1 o, 'Host Name' k, host_name v from v$instance
union all select 2, 'Platform', platform_name from v$database
union all select 3, 'CPUs', nvl(to_char(max(decode(stat_name, 'NUM_CPUS', value))), '-') from v$osstat
union all select 4, 'CPU Cores', nvl(to_char(max(decode(stat_name, 'NUM_CPU_CORES', value))), '-') from v$osstat
union all select 5, 'CPU Sockets', nvl(to_char(max(decode(stat_name, 'NUM_CPU_SOCKETS', value))), '-') from v$osstat
union all select 6, 'cpu_count (instance)', value from v$parameter where name = 'cpu_count'
union all select 7, 'Memory (GB)',
          nvl(to_char(max(decode(stat_name, 'PHYSICAL_MEMORY_BYTES', value)) / 1073741824, 'FM9999990.0'), '-')
          from v$osstat
) order by o;
spool off

--+======================================================================================================================
--| EBS APPLICATIONS, report section 3
--+======================================================================================================================

--+--------------------------------------------------------------------
--| ebs_overview
--| Report: 3.1 Overview
--| Key|value rows, the order column o keeps the rows in report order. The code levels are scalar subqueries
--| so a missing code level still gives a row (with an empty value).
--| Instance Created = the first node registered in FND_NODES, the date the instance was installed or last
--| cloned (the seeded data in the other tables has Oracle's own dates). Also the start for 3.2 Changed Profiles.
--| Output: key|value
--+--------------------------------------------------------------------
spool &1/ebs_overview.lookup
select k || '|' || v from (
select 1 o, 'Release' k, release_name v from fnd_product_groups
union all select 2, 'Applications System Name', applications_system_name from fnd_product_groups
union all select 2.5, 'Instance Created', to_char(min(creation_date), 'YYYY-MM-DD HH24:MI') from fnd_nodes
union all select 3, 'Site Name', replace(fnd_profile.value('SITENAME'), '|', '/') from dual
union all select 4, 'Applications Framework Agent', fnd_profile.value('APPS_FRAMEWORK_AGENT') from dual
union all select 5, 'AD Code Level', (select codelevel from ad_trackable_entities where abbreviation = 'ad') from dual
union all select 6, 'TXK Code Level', (select codelevel from ad_trackable_entities where abbreviation = 'txk') from dual
union all select 7, 'ATG Code Level', (select codelevel from ad_trackable_entities where abbreviation = 'atg_pf') from dual
union all select 8, 'EBS CPU Level', (select codelevel from ad_trackable_entities where abbreviation = 'ebscpu') from dual
union all select 9, 'Base Language', (select language_code from fnd_languages where installed_flag = 'B') from dual
union all select 10, 'Installed Languages',
          (select listagg(language_code, ', ') within group (order by language_code)
           from fnd_languages
           where installed_flag in ('B', 'I'))
          from dual
union all select 11, 'Multi-Org', multi_org_flag from fnd_product_groups
union all select 13, 'Installed Products', to_char(count(*)) from fnd_product_installations where status = 'I'
union all select 14, 'Shared Products', to_char(count(*)) from fnd_product_installations where status = 'S'
union all select 15, 'Active Users', to_char(count(*)) from fnd_user where end_date is null or end_date > sysdate
) order by o;
spool off

--+--------------------------------------------------------------------
--| ebs_profiles
--| Report: 3.2 Profile Options
--| All profile options (about 10,000, takes under a second) with the Site level value (level 10001)
--| and the values set on User level (level 10004), one row per user. A profile without user values has
--| one row, user columns = -. Shows if someone has i.e debugging turned on for a user.
--| build_profile_options() picks the profiles listed in parameters.lst.
--| Output: name|user name|site value|user|user value
--+--------------------------------------------------------------------
spool &1/ebs_profiles.lookup
select o.profile_option_name || '|' || replace(t.user_profile_option_name, '|', '/') || '|' ||
       nvl(replace(s.profile_option_value, '|', '/'), '(not set)') || '|' ||
       nvl(u.user_name, '-') || '|' ||
       decode(v.level_id, null, '-', nvl(replace(v.profile_option_value, '|', '/'), '(empty)'))
from fnd_profile_options o, fnd_profile_options_tl t, fnd_profile_option_values s,
     fnd_profile_option_values v, fnd_user u
where t.profile_option_name = o.profile_option_name
and   t.language = 'US'
and   s.application_id (+) = o.application_id
and   s.profile_option_id (+) = o.profile_option_id
and   s.level_id (+) = 10001
and   v.application_id (+) = o.application_id
and   v.profile_option_id (+) = o.profile_option_id
and   v.level_id (+) = 10004
and   u.user_id (+) = v.level_value
order by o.profile_option_name, u.user_name;
spool off

--+--------------------------------------------------------------------
--| ebs_profile_changes
--| Report: 3.2 Profile Options, Changed Since Instance Created
--| Profile values on any level changed after the instance was installed or last cloned (the first node
--| in FND_NODES), newest first, the latest 200. Changes by ANONYMOUS (user_id -1) are left out, they are
--| made by AutoConfig and setup scripts, not by a person.
--| Level value = the application, responsibility, user or server the value is set for.
--| Output: user name|name|level|level value|value|changed|changed by
--+--------------------------------------------------------------------
spool &1/ebs_profile_changes.lookup
select line from (
select replace(t.user_profile_option_name, '|', '/') || '|' || o.profile_option_name || '|' ||
       decode(v.level_id, 10001, 'Site', 10002, 'Application', 10003, 'Responsibility', 10004, 'User',
                          10005, 'Server', 10006, 'Organization', 10007, 'Server+Resp', to_char(v.level_id)) || '|' ||
       decode(v.level_id,
              10001, '-',
              10002, (select a.application_short_name from fnd_application a
                      where a.application_id = v.level_value),
              10003, (select replace(r.responsibility_name, '|', '/') from fnd_responsibility_tl r
                      where r.responsibility_id = v.level_value
                      and   r.application_id = v.level_value_application_id
                      and   r.language = 'US'),
              10004, (select u.user_name from fnd_user u where u.user_id = v.level_value),
              10005, (select n.node_name from fnd_nodes n where n.node_id = v.level_value),
              to_char(v.level_value)) || '|' ||
       nvl(replace(v.profile_option_value, '|', '/'), '(empty)') || '|' ||
       to_char(v.last_update_date, 'YYYY-MM-DD HH24:MI') || '|' ||
       nvl((select fu.user_name from fnd_user fu where fu.user_id = v.last_updated_by), to_char(v.last_updated_by)) line
from fnd_profile_option_values v, fnd_profile_options o, fnd_profile_options_tl t
where o.application_id = v.application_id
and   o.profile_option_id = v.profile_option_id
and   t.profile_option_name = o.profile_option_name
and   t.language = 'US'
and   v.last_updated_by <> -1
and   v.last_update_date > (select min(creation_date) from fnd_nodes)
order by v.last_update_date desc
)
where rownum <= 200;
spool off

--+--------------------------------------------------------------------
--| ebs_debug_profiles
--| Report: 3.3 Trace and Debug Profiles
--| Profiles with Trace or Debug in the user or internal name that are set to Y at site level or have any
--| value at user level. One row per user, the site value is shown on every row, so N at site level with
--| Y for a user is seen on the same row. A profile without user values has one row, user columns = -.
--| Output: user name|name|site value|user|user value
--+--------------------------------------------------------------------
spool &1/ebs_debug_profiles.lookup
select replace(t.user_profile_option_name, '|', '/') || '|' || o.profile_option_name || '|' ||
       nvl(replace(s.profile_option_value, '|', '/'), '(not set)') || '|' ||
       nvl(u.user_name, '-') || '|' ||
       decode(v.level_id, null, '-', nvl(replace(v.profile_option_value, '|', '/'), '(empty)'))
from fnd_profile_options o, fnd_profile_options_tl t, fnd_profile_option_values s,
     fnd_profile_option_values v, fnd_user u
where t.profile_option_name = o.profile_option_name
and   t.language = 'US'
and   s.application_id (+) = o.application_id
and   s.profile_option_id (+) = o.profile_option_id
and   s.level_id (+) = 10001
and   v.application_id (+) = o.application_id
and   v.profile_option_id (+) = o.profile_option_id
and   v.level_id (+) = 10004
and   u.user_id (+) = v.level_value
and   (s.profile_option_value = 'Y' or v.level_id = 10004)
and   (   upper(t.user_profile_option_name) like '%TRACE%'
       or upper(t.user_profile_option_name) like '%DEBUG%'
       or upper(o.profile_option_name) like '%TRACE%'
       or upper(o.profile_option_name) like '%DEBUG%')
order by t.user_profile_option_name, u.user_name;
spool off

--+--------------------------------------------------------------------
--| ebs_nodes
--| Report: 3.4 FND NODES
--| Application and database nodes registered in fnd_nodes and the services they run (Y/N).
--| AUTHENTICATION is an internal row, not a node.
--| Output: node|host|ip|cp|forms|web|admin|db|status
--+--------------------------------------------------------------------
spool &1/ebs_nodes.lookup
select node_name || '|' || nvl(host || '.' || domain, '-') || '|' || server_address || '|' ||
       support_cp || '|' || support_forms || '|' || support_web || '|' || support_admin || '|' || support_db || '|' ||
       status
from fnd_nodes
where node_name <> 'AUTHENTICATION'
order by node_name;
spool off

--+--------------------------------------------------------------------
--| ebs_adop_sessions
--| Report: 3.5 ADOP Cycle Status
--| The latest 10 adop cycles, newest first. The phase status Y/N/R/F/X is decoded to text.
--| Output: session|node|started|prepare|apply|finalize|cutover|cleanup|abort
--+--------------------------------------------------------------------
spool &1/ebs_adop_sessions.lookup
select adop_session_id || '|' || node_name || '|' ||
       to_char(nvl(prepare_start_date, apply_start_date), 'YYYY-MM-DD HH24:MI') || '|' ||
       decode(prepare_status,  'Y', 'Completed', 'N', 'Not run', 'R', 'Running', 'F', 'Failed', 'X', 'Skipped', prepare_status) || '|' ||
       decode(apply_status,    'Y', 'Completed', 'N', 'Not run', 'R', 'Running', 'F', 'Failed', 'X', 'Skipped', apply_status) || '|' ||
       decode(finalize_status, 'Y', 'Completed', 'N', 'Not run', 'R', 'Running', 'F', 'Failed', 'X', 'Skipped', finalize_status) || '|' ||
       decode(cutover_status,  'Y', 'Completed', 'N', 'Not run', 'R', 'Running', 'F', 'Failed', 'X', 'Skipped', cutover_status) || '|' ||
       decode(cleanup_status,  'Y', 'Completed', 'N', 'Not run', 'R', 'Running', 'F', 'Failed', 'X', 'Skipped', cleanup_status) || '|' ||
       decode(abort_status,    'Y', 'Aborted', 'N', '-', 'X', '-', abort_status)
from (select * from ad_adop_sessions order by adop_session_id desc)
where rownum <= 10;
spool off

--+--------------------------------------------------------------------
--| ebs_context_files
--| Report: 3.6 Context Files
--| Context files registered by AutoConfig: the database tier, and the application tier on the run file
--| system only. The run file system context file has s_file_edition_type = run in its XML text.
--| Output: tier|context name|path
--+--------------------------------------------------------------------
spool &1/ebs_context_files.lookup
select decode(c.ctx_type, 'A', 'Application', 'D', 'Database', c.ctx_type) || '|' || c.name || '|' || c.path
from fnd_oam_context_files c
where c.name not in ('TEMPLATE', 'METADATA')
and   (c.ctx_type = 'D' or dbms_lob.instr(c.text, 's_file_edition_type">run<') > 0)
order by c.ctx_type, c.node_name, c.path;
spool off

--+--------------------------------------------------------------------
--| ebs_managers
--| Report: 3.8 Concurrent Managers
--| Enabled concurrent managers that are in use (target above 0 or running processes), Internal Manager
--| first. Managers with target 0 (deactivated, or not used like MRPMGR) are left out. Based on the user's
--| query (fnd_concurrent_queues_vl joined to fnd_concurrent_queues_tl for the US name and description).
--| Target = max_processes, the Target in Administer Concurrent Managers. target_processes is not
--| used, it doesn't match the form (i.e 0 for a running Internal Manager).
--| Actual = running_processes.
--| State = control_code with its meaning from fnd_lookups (CP_CONTROL_CODE), i.e E = Deactivated.
--| An empty control_code is a manager running normally, shown as Active. Enabled doesn't mean started:
--| a deactivated manager, a work shift with 0 processes or no work shift all give target 0.
--| Cache size = requests the manager reads per fetch, - when not set.
--| Sleep = seconds between checks for new requests, per work shift (fnd_concurrent_queue_size),
--| more than one value when the manager has several work shifts.
--| Log file = the log of each running process of the manager, in $APPLCSF/$APPLLOG of its node.
--| Output: manager|description|short name|queue id|node|target|actual|state|cache size|sleep seconds|log file
--+--------------------------------------------------------------------
spool &1/ebs_managers.lookup
select fndcmqtl.user_concurrent_queue_name || '|' ||
       nvl(replace(fndcmqtl.description, '|', '/'), '-') || '|' ||
       fndcmqvl.concurrent_queue_name || '|' ||
       fndcmqvl.concurrent_queue_id || '|' ||
       nvl(fndcmqvl.target_node, '-') || '|' ||
       fndcmqvl.max_processes || '|' ||
       fndcmqvl.running_processes || '|' ||
       nvl((select l.meaning
            from fnd_lookups l
            where l.lookup_type = 'CP_CONTROL_CODE'
            and   l.lookup_code = fndcmqvl.control_code), nvl(fndcmqvl.control_code, 'Active')) || '|' ||
       nvl(to_char(fndcmqvl.cache_size), '-') || '|' ||
       nvl((select listagg(s.sleep_seconds, ', ') within group (order by s.concurrent_time_period_id)
            from fnd_concurrent_queue_size s
            where s.queue_application_id = fndcmqvl.application_id
            and   s.concurrent_queue_id = fndcmqvl.concurrent_queue_id), nvl(to_char(fndcmqvl.sleep_seconds), '-')) || '|' ||
       nvl((select listagg(p.logfile_name, ', ') within group (order by p.concurrent_process_id)
            from fnd_concurrent_processes p
            where p.queue_application_id = fndcmqvl.application_id
            and   p.concurrent_queue_id = fndcmqvl.concurrent_queue_id
            and   p.process_status_code = 'A'), '-')
from fnd_concurrent_queues_vl fndcmqvl, fnd_concurrent_queues_tl fndcmqtl
where fndcmqvl.concurrent_queue_name = fndcmqtl.concurrent_queue_name
and   fndcmqvl.enabled_flag = 'Y'
and   fndcmqtl.language = 'US'
and   (fndcmqvl.max_processes > 0 or fndcmqvl.running_processes > 0)
order by decode(fndcmqvl.concurrent_queue_name, 'FNDICM', 0, 1), fndcmqtl.user_concurrent_queue_name;
spool off

--+--------------------------------------------------------------------
--| ebs_workflow
--| Report: 3.9 Workflow
--| Workflow Notification Mailer first, then the agent listeners and other service components.
--| Each component runs inside a container, a concurrent manager (service), i.e Workflow Agent Listener
--| Service. When the container isn't running (actual 0), its components show STOPPED.
--| Startup mode AUTOMATIC = started with the container, MANUAL = started by hand in OAM.
--| Output: component|type|startup mode|status|container|container processes actual / target
--+--------------------------------------------------------------------
spool &1/ebs_workflow.lookup
select c.component_name || '|' || c.component_type || '|' || c.startup_mode || '|' || c.component_status || '|' ||
       nvl(q.user_concurrent_queue_name, '-') || '|' ||
       nvl(to_char(q.running_processes), '-') || ' / ' || nvl(to_char(q.max_processes), '-')
from fnd_svc_components c, fnd_concurrent_queues_vl q
where q.application_id (+) = c.application_id
and   q.concurrent_queue_id (+) = c.concurrent_queue_id
order by decode(c.component_type, 'WF_MAILER', 0, 1), c.component_name;
spool off

exit
