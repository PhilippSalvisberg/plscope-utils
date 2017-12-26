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

SET DEFINE OFF
SET SCAN OFF
SET ECHO OFF
SET LINESIZE 200
SET PAGESIZE 100
SET SERVEROUTPUT ON SIZE 1000000
SPOOL install_test.log

PROMPT ====================================================================
PROMPT This script installs test packages for plscope-utils.
PROMPT Tests require an installed utPLSQL v3.
PROMPT
PROMPT Connect to the plscope user.
PROMPT ====================================================================

PROMPT ====================================================================
PROMPT Disable PL/Scope for this session
PROMPT ====================================================================

ALTER SESSION SET plscope_settings='identifiers:none, statements:none';

PROMPT ====================================================================
PROMPT Packages
PROMPT ====================================================================

@./test/package/test_dd_util.pks
SHOW ERRORS
@./test/package/test_lineage_util.pks
SHOW ERRORS
@./test/package/test_parse_util.pks
SHOW ERRORS
@./test/package/test_type_util.pks
SHOW ERRORS
@./test/package/test_plscope_context.pks
SHOW ERRORS
@./test/package/test_etl.pks
SHOW ERRORS
@./test/package/test_dd_util.pkb
SHOW ERRORS
@./test/package/test_lineage_util.pkb
SHOW ERRORS
@./test/package/test_parse_util.pkb
SHOW ERRORS
@./test/package/test_type_util.pkb
SHOW ERRORS
@./test/package/test_plscope_context.pkb
SHOW ERRORS
@./test/package/test_etl.pkb
SHOW ERRORS

PROMPT ====================================================================
PROMPT Run tests with 12.2 code coverage
PROMPT ====================================================================

DECLARE
   l_testsuite_run NUMBER;
BEGIN
   dbms_plsql_code_coverage.create_coverage_tables(true);
   l_testsuite_run := dbms_plsql_code_coverage.start_coverage('plscope-utils');
   ut.run;
   dbms_plsql_code_coverage.stop_coverage;
END;
/

PROMPT ====================================================================
PROMPT Code coverage - Overview
PROMPT ====================================================================

COLUMN object_name FORMAT A30
COLUMN covered_percent FORMAT 990.00
WITH
   block_lines AS (
      SELECT u.name AS object_name,
             b.line,
             b.col,
             CASE
                WHEN b.line = 1 AND b.col = 1 AND b.covered = 0 THEN
                   -- fix wrong coverage of unit definition
                   -- it is not possible that this block is not covered
                   -- unless the unit is not executed at all
                   1
                WHEN upper(substr(s.text, b.col, 3)) = 'FOR' THEN
                   -- fix wrong coverage of FOR-LOOP
                   1
                WHEN upper(substr(s.text, b.col)) LIKE 'END%LOOP%' THEN
                   -- fix wrong coverage for END LOOP
                   1
                ELSE
                   b.covered
             END AS covered,
             b.not_feasible
        FROM dbmspcc_runs r
        JOIN dbmspcc_units u
          ON u.run_id = r.run_id
        JOIN dbmspcc_blocks b
          ON b.object_id = u.object_id
        JOIN dba_source s
          ON s.owner = u.owner
             AND s.type = u.type
             AND s.name = u.name
             AND s.line = b.line
       WHERE r.run_comment = 'plscope-utils'
         AND u.name NOT LIKE 'TEST%'
   )
SELECT object_name,
       round((sum(least(covered + not_feasible, 1)) * 100) / count(*), 2) AS covered_percent
  FROM block_lines
 GROUP BY object_name
 ORDER BY covered_percent;

PROMPT ====================================================================
PROMPT Code coverage - Uncovered and feasible lines
PROMPT ====================================================================

COLUMN line FORMAT 99990
COLUMN text FORMAT A120
WITH
   block_lines AS (
      SELECT u.name AS object_name,
             b.line,
             b.col,
             CASE
                WHEN b.line = 1 AND b.col = 1 AND b.covered = 0 THEN
                   -- fix wrong coverage of unit definition
                   -- it is not possible that this block is not covered
                   -- unless the unit is not executed at all
                   1
                WHEN upper(substr(s.text, b.col, 3)) = 'FOR' THEN
                   -- fix wrong coverage of FOR-LOOP
                   1
                WHEN upper(substr(s.text, b.col)) LIKE 'END%LOOP%' THEN
                   -- fix wrong coverage for END LOOP
                   1
                ELSE
                   b.covered
             END AS covered,
             b.not_feasible,
             regexp_replace(s.text, chr(10)||'+$', null) AS text
        FROM dbmspcc_runs r
        JOIN dbmspcc_units u
          ON u.run_id = r.run_id
        JOIN dbmspcc_blocks b
          ON b.object_id = u.object_id
        JOIN dba_source s
          ON s.owner = u.owner
             AND s.type = u.type
             AND s.name = u.name
             AND s.line = b.line
       WHERE r.run_comment = 'plscope-utils'
         AND u.name NOT LIKE 'TEST%'
   )
SELECT object_name, line, text
  FROM block_lines
 WHERE covered = 0
   AND not_feasible = 0;

SPOOL OFF
