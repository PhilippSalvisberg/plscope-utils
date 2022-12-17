/*
* Copyright 2017 Philipp Salvisberg <philipp.salvisberg@trivadis.com>
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

set define on
set echo off
set verify off

prompt ====================================================================
prompt Parameter defaults for username (1), password (2) and tablespace (3)
prompt ====================================================================

-- use these intermediate substitution variables to avoid parse errors in SQLDev
define param1 = 1
define param2 = 2
define param3 = 3

column 1 new_value &&param1 noprint
column 2 new_value &&param2 noprint
column 3 new_value &&param3 noprint

set feedback off

select null as "1",
       null as "2",
       null as "3"
  from dual
 where rownum = 0;

column username   new_value username   noprint
column password   new_value password   noprint
column tablespace new_value tablespace noprint

select coalesce('&&1', 'plscope') as username,
       coalesce('&&2', 'plscope') as password,
       coalesce('&&3', 'users') as tablespace
  from dual;

set feedback on

prompt ====================================================================
prompt This script creates the user &&username with all required privileges.
prompt Run this script as SYS or as ADMIN in the Oracle Cloud.
prompt ====================================================================

prompt ====================================================================
prompt User
prompt ====================================================================

create user &&username identified by &&password
  default tablespace &&tablespace
  temporary tablespace temp;

prompt ====================================================================
prompt Grants
prompt ====================================================================

grant connect                        to &&username;
grant resource                       to &&username;
grant create view to &&username;
grant create materialized view to &&username;
grant create synonym                 to &&username;
grant create public synonym          to &&username;
grant drop public synonym            to &&username;
grant unlimited tablespace           to &&username;
grant create any context             to &&username;
grant drop any context               to &&username;

-- to get access to DBA-views
grant select_catalog_role            to &&username;

-- to create views using DBA-views
grant select any dictionary          to &&username;

-- direct grants required for grant option
grant select on sys.dba_identifiers  to &&username with grant option;
grant select on sys.dba_statements   to &&username with grant option;
grant select on sys.dba_tables       to &&username with grant option;
grant select on sys.dba_views        to &&username with grant option;
grant select on sys.dba_mviews       to &&username with grant option;
grant select on sys.dba_dependencies to &&username with grant option;
grant select on sys.dba_synonyms     to &&username with grant option;
grant select on sys.dba_objects      to &&username with grant option;
grant select on sys.dba_tab_columns  to &&username with grant option;
grant select on sys.dba_source       to &&username with grant option;

-- direct grant for ETL demo package
grant select on v_$mystat            to &&username;

-- for debugging
grant debug connect session          to &&username;
grant debug any procedure to &&username;
grant execute on dbms_debug_jdwp     to &&username;

prompt ====================================================================
prompt Optional grants based on privileges
prompt ====================================================================

declare
   procedure exec_sql(in_sql in varchar2) is
   begin
      execute immediate sys.dbms_assert.noop(in_sql);
   end exec_sql; 
   --
   procedure options is
      l_count integer;
   begin
      select count(*)
        into l_count
        from all_objects
       where object_name in ('UTL_XML', 'UTL_XML_LIB')
         and rownum = 1;
      if l_count > 0 then
         -- to parse queries in PL/SQL packages
         exec_sql('grant execute on sys.utl_xml     to &&username'); -- for 12.2 only
         exec_sql('grant execute on sys.utl_xml_lib to &&username'); -- for >= 18.0 only
         -- for remote debugging
         exec_sql(q'[
            begin
              dbms_network_acl_admin.append_host_ace (
                host =>'*',
                ace  => sys.xs$ace_type(
                            privilege_list => sys.xs$name_list('JDWP') ,
                            principal_name => '&&username',
                            principal_type => sys.xs_acl.ptype_db
                        )
              );
            end;
         ]');
      end if;
   end options;
begin
   options;
end;
/
