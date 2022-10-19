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

set define off
set echo off
set serveroutput on size 100000

-- Handling of SQL exceptions: use the default behaviour of continuing
-- no matter what, so the readout should be checked carefully in the end.
whenever sqlerror continue none

prompt ====================================================================
prompt This script installs plscope-utils.
prompt
prompt Connect to the target user (schema) of your choice.
prompt See utils/user/plscope.sql for required privileges.
prompt ====================================================================

-- The sanity check will change the whenever sqlerror directive, then reset
-- it to continue none if successful.
@@schema_sanity_check

prompt ====================================================================
prompt Disable PL/Scope for this session
prompt ====================================================================

alter session set plscope_settings = 'identifiers:none, statements:none';

prompt ====================================================================
prompt Context
prompt ====================================================================
@./utils/context/plscope.ctx

prompt ====================================================================
prompt Types
prompt ====================================================================

@./utils/type/obj_type.sql
@./utils/type/col_type.sql
@./utils/type/col_lineage_type.sql
@./utils/type/t_obj_type.sql
@./utils/type/t_col_type.sql
@./utils/type/t_col_lineage_type.sql

prompt ====================================================================
prompt Packages
prompt ====================================================================

@./utils/package/dd_util.pks
show errors
@./utils/package/type_util.pks
show errors
@./utils/package/plscope_context.pks
show errors
@./utils/package/dd_util.pkb
show errors
@./utils/package/type_util.pkb
show errors
@./utils/package/plscope_context.pkb
show errors

prompt ====================================================================
prompt Views
prompt ====================================================================

@./utils/view/plscope_identifiers.sql
show errors
@./utils/view/plscope_statements.sql
show errors
@./utils/view/plscope_tab_usage.sql
show errors

set sqlterminator off
@./utils/view/plscope_naming.sql
show errors

set sqlterminator on

prompt ====================================================================
prompt Grants
prompt ====================================================================

grant select on plscope_identifiers to public;
grant select on plscope_statements to public;
grant select on plscope_tab_usage to public;
grant select on plscope_naming to public;
grant execute on dd_util to public;
grant execute on type_util to public;
grant execute on plscope_context to public;

prompt ====================================================================
prompt Synonyms and options based on privileges
prompt ====================================================================

set feedback off
set term off
spool install_options.tmp
declare
   l_count integer;
   --
   procedure cre_syn(in_name in varchar2) is
      l_templ varchar2(4000) :=
         'create or replace public synonym ${name} for ${user}.${name}';
      l_sql   varchar2(4000);
   begin
      l_sql := replace(l_templ, '${name}', in_name);
      l_sql := replace(l_sql, '${user}', user);
      execute immediate l_sql;
   end cre_syn;
   --
   procedure print(in_line in varchar2) is
   begin
      dbms_output.put_line(in_line);
   end print; 
   --
   procedure options is
   begin
      select count(*)
        into l_count
        from all_objects
       where object_name in ('UTL_XML', 'UTL_XML_LIB');
      if l_count > 0 then
         print('@./utils/package/parse_util.pks');
         print('show errors');
         print('@./utils/package/lineage_util.pks');
         print('show errors');
         print('@./utils/package/parse_util.pkb');
         print('show errors');
         print('@./utils/package/lineage_util.pkb');
         print('show errors');
         print('@./utils/view/plscope_col_usage.sql');
         print('show errors');
         print('@./utils/view/plscope_ins_lineage.sql');
         print('show errors');
         print('grant execute on lineage_util to public;');
         print('grant execute on parse_util to public;');
         print('grant select on plscope_col_usage to public;');
         print('grant select on plscope_ins_lineage to public;');
         cre_syn('plscope_col_usage');
         cre_syn('plscope_ins_lineage');
         cre_syn('lineage_util');
         cre_syn('parse_util');
      end if;
   end options;
begin
   cre_syn('plscope_identifiers');
   cre_syn('plscope_statements');
   cre_syn('plscope_tab_usage');
   cre_syn('plscope_naming');
   cre_syn('dd_util');
   cre_syn('type_util');
   cre_syn('plscope_context');
   options;
end;
/
spool off
set feedback on
set term on
@install_options.tmp

prompt ====================================================================
prompt Create and populate demo tables
prompt ====================================================================

-- use these intermediate substitution variables to avoid parse errors in SQLDev
define table_folder = 'table'
set define on
@./demo/&&table_folder/drop_demo_tables.sql
@./demo/&&table_folder/dept.sql
@./demo/&&table_folder/emp.sql
@./demo/&&table_folder/deptsal.sql
@./demo/&&table_folder/deptsal_err.sql
@./demo/view/source_view.sql
show errors
-- @formatter:off
set define off
-- @formatter:on

alter session set plscope_settings = 'identifiers:all, statements:all';
@./demo/synonym/source_syn.sql
@./demo/package/etl.pks
@./demo/package/example.pks
show errors
@./demo/package/etl.pkb
@./demo/package/example.pkb
show errors
alter session set plscope_settings = 'identifiers:none, statements:none';
