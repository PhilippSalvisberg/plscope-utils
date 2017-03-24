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
SET SERVEROUTPUT ON SIZE 100000
SPOOL install.log

PROMPT ====================================================================
PROMPT This script installs plscope-utils.
PROMPT
PROMPT Connect to the target user (schema) of your choice.
PROMPT See utils/user/plscope.sql for required privileges.
PROMPT ====================================================================

PROMPT ====================================================================
PROMPT Disable PL/Scope for this session
PROMPT ====================================================================

ALTER SESSION SET plscope_settings='identifiers:none, statements:none';

PROMPT ====================================================================
PROMPT Types
PROMPT ====================================================================

@./utils/type/obj_type.sql
@./utils/type/col_type.sql
@./utils/type/col_lineage_type.sql
@./utils/type/t_obj_type.sql
@./utils/type/t_col_type.sql
@./utils/type/t_col_lineage_type.sql

PROMPT ====================================================================
PROMPT Packages
PROMPT ====================================================================

@./utils/package/dd_util.pks
SHOW ERRORS
@./utils/package/lineage_util.pks
SHOW ERRORS
@./utils/package/parse_util.pks
SHOW ERRORS
@./utils/package/type_util.pks
SHOW ERRORS
@./utils/package/dd_util.pkb
SHOW ERRORS
@./utils/package/lineage_util.pkb
SHOW ERRORS
@./utils/package/parse_util.pkb
SHOW ERRORS
@./utils/package/type_util.pkb
SHOW ERRORS

PROMPT ====================================================================
PROMPT Views
PROMPT ====================================================================

@./utils/view/plscope_identifiers.sql
SHOW ERRORS
@./utils/view/plscope_identifiers2.sql
SHOW ERRORS
@./utils/view/plscope_statements.sql
SHOW ERRORS
@./utils/view/plscope_tab_usage.sql
SHOW ERRORS
@./utils/view/plscope_col_usage.sql
SHOW ERRORS
@./utils/view/plscope_ins_lineage.sql
SHOW ERRORS

PROMPT ====================================================================
PROMPT Grants
PROMPT ====================================================================

GRANT SELECT ON plscope_identifiers TO PUBLIC;
GRANT SELECT ON plscope_statements TO PUBLIC;
GRANT SELECT ON plscope_tab_usage TO PUBLIC;
GRANT SELECT ON plscope_col_usage TO PUBLIC;
GRANT SELECT ON plscope_ins_lineage TO PUBLIC;
GRANT EXECUTE ON dd_util TO PUBLIC;
GRANT EXECUTE ON lineage_util TO PUBLIC;
GRANT EXECUTE ON parse_util TO PUBLIC;
GRANT EXECUTE ON type_util TO PUBLIC;

PROMPT ====================================================================
PROMPT Synonyms
PROMPT ====================================================================

-- anonymous PL/SQL block to handle target user
DECLARE
   PROCEDURE cre_syn (in_name IN VARCHAR2) IS
      l_templ VARCHAR2(4000) := 
         'CREATE OR REPLACE PUBLIC SYNONYM ${name} FOR ${user}.${name}';
      l_sql VARCHAR2(4000);
   BEGIN
      l_sql := replace(l_templ, '${name}', in_name);
      l_sql := replace(l_sql, '${user}', USER);
      EXECUTE IMMEDIATE l_sql;
   END cre_syn;
BEGIN
   cre_syn('plscope_identifiers');
   cre_syn('plscope_statements');
   cre_syn('plscope_tab_usage');
   cre_syn('plscope_col_usage');
   cre_syn('plscope_ins_lineage');
   cre_syn('dd_util');
   cre_syn('lineage_util');
   cre_syn('parse_util');
   cre_syn('type_util');
END;
/

PROMPT ====================================================================
PROMPT Create and populate demo tables
PROMPT ====================================================================

@./demo/table/drop_demo_tables.sql
@./demo/table/dept.sql
@./demo/table/emp.sql
@./demo/table/deptsal.sql
@./demo/table/deptsal_err.sql
@./demo/view/source_view.sql
SHOW ERRORS

ALTER SESSION SET plscope_settings='identifiers:all, statements:all';
@./demo/synonym/source_syn.sql
@./demo/package/etl.pks
SHOW ERRORS
@./demo/package/etl.pkb
SHOW ERRORS
ALTER SESSION SET plscope_settings='identifiers:none, statements:none';

SPOOL OFF
