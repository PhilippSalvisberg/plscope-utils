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
set scan off
set echo off
set linesize 200
set pagesize 100
set serveroutput on size 1000000

PROMPT ====================================================================
PROMPT This script installs test packages for plscope-utils.
PROMPT Tests require an installed utPLSQL v3.
PROMPT
PROMPT Connect to the plscope user.
PROMPT ====================================================================

PROMPT ====================================================================
PROMPT Disable PL/Scope for this session
PROMPT ====================================================================

alter session set plscope_settings = 'identifiers:none, statements:none';

PROMPT ====================================================================
PROMPT Packages
PROMPT ====================================================================

@./test/package/test_dd_util.pks
show errors
@./test/package/test_type_util.pks
show errors
@./test/package/test_plscope_context.pks
show errors
@./test/package/test_etl.pks
show errors
@./test/package/test_plscope_identifiers.pks
show errors
@./test/package/test_dd_util.pkb
show errors
@./test/package/test_type_util.pkb
show errors
@./test/package/test_plscope_context.pkb
show errors
@./test/package/test_etl.pkb
show errors
@./test/package/test_plscope_identifiers.pkb
show errors

PROMPT ====================================================================
PROMPT Options based on privileges
PROMPT ====================================================================

set feedback off
set term off
spool install_options.tmp
<<install_options>>
declare
   procedure print(in_line in varchar2) is
   begin
      dbms_output.put_line(in_line);
   end print; 
   --
   procedure options is
      l_count integer;
   begin
      select count(*)
        into l_count
        from all_objects
       where object_name in ('UTL_XML', 'UTL_XML_LIB');
      if l_count > 0 then
         print('@./test/package/test_lineage_util.pks');
         print('SHOW ERRORS');
         print('@./test/package/test_parse_util.pks');
         print('SHOW ERRORS');
         print('@./test/package/test_lineage_util.pkb');
         print('SHOW ERRORS');
         print('@./test/package/test_parse_util.pkb');
         print('SHOW ERRORS');
      end if;
   end options;
begin
   options;
end install_options;
/
spool off
set feedback on
set term on
@install_options.tmp

PROMPT ====================================================================
PROMPT Run tests with 12.2 code coverage
PROMPT ====================================================================

declare
   l_testsuite_run
number;
begin
   dbms_plsql_code_coverage.create_coverage_tables(true);
   l_testsuite_run := dbms_plsql_code_coverage.start_coverage('plscope-utils');
   ut.run;
   dbms_plsql_code_coverage.stop_coverage;
end;
/

PROMPT ====================================================================
PROMPT Code coverage - Overview
PROMPT ====================================================================

column object_name format a30
column covered_percent format 990.00
with
   block_lines as (
      select u.name as object_name,
             b.line,
             b.col,
             case
                when b.line = 1
                   and b.col = 1
                   and b.covered = 0
                then
                   -- fix wrong coverage of unit definition
                   -- it is not possible that this block is not covered
                   -- unless the unit is not executed at all
                   1
                when upper(substr(s.text, b.col, 3)) = 'FOR' then
                   -- fix wrong coverage of FOR-LOOP
                   1
                when upper(substr(s.text, b.col)) like 'END%LOOP%' then
                   -- fix wrong coverage for END LOOP
                   1
                else
                   b.covered
             end as covered,
             b.not_feasible
        from dbmspcc_runs r
        join dbmspcc_units u
          on u.run_id = r.run_id
        join dbmspcc_blocks b
          on b.object_id = u.object_id
        join dba_source s
          on s.owner = u.owner
         and s.type = u.type
         and s.name = u.name
         and s.line = b.line
       where r.run_comment = 'plscope-utils'
         and u.name not like 'TEST%'
   )
select object_name,
       round((sum(least(covered + not_feasible, 1)) * 100) / count(*), 2) as covered_percent
  from block_lines
 group by object_name
 order by covered_percent;

PROMPT ====================================================================
PROMPT Code coverage - Uncovered and feasible lines
PROMPT ====================================================================

column line format 99990
column text format a120
with
   block_lines as (
      select u.name as object_name,
             b.line,
             b.col,
             case
                when b.line = 1
                   and b.col = 1
                   and b.covered = 0
                then
                   -- fix wrong coverage of unit definition
                   -- it is not possible that this block is not covered
                   -- unless the unit is not executed at all
                   1
                when upper(substr(s.text, b.col, 3)) = 'FOR' then
                   -- fix wrong coverage of FOR-LOOP
                   1
                when upper(substr(s.text, b.col)) like 'END%LOOP%' then
                   -- fix wrong coverage for END LOOP
                   1
                else
                   b.covered
             end as covered,
             b.not_feasible,
             regexp_replace(s.text, chr(10) || '+$', null) as text
        from dbmspcc_runs r
        join dbmspcc_units u
          on u.run_id = r.run_id
        join dbmspcc_blocks b
          on b.object_id = u.object_id
        join dba_source s
          on s.owner = u.owner
         and s.type = u.type
         and s.name = u.name
         and s.line = b.line
       where r.run_comment = 'plscope-utils'
         and u.name not like 'TEST%'
   )
select object_name, line, text
  from block_lines
 where covered = 0
   and not_feasible = 0;
