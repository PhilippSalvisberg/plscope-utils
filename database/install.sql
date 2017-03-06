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
PROMPT See ./utils/user/create_user_plscope.sql for required privileges.
PROMPT ====================================================================

PROMPT ====================================================================
PROMPT Types
PROMPT ====================================================================

@./utils/type/coldep_type.sql
SHOW ERRORS
@./utils/type/t_coldep_type.sql
SHOW ERRORS

PROMPT ====================================================================
PROMPT Packages
PROMPT ====================================================================

@./utils/package/coldep.pks
SHOW ERRORS
@./utils/package/coldep.pkb
SHOW ERRORS


PROMPT ====================================================================
PROMPT Views
PROMPT ====================================================================

@./utils/view/plscope_identifiers.sql
SHOW ERRORS
@./utils/view/plscope_statements.sql
SHOW ERRORS
@./utils/view/plscope_tab_usage.sql
SHOW ERRORS
@./utils/view/plscope_col_usage.sql
SHOW ERRORS

PROMPT ====================================================================
PROMPT Grants
PROMPT ====================================================================

GRANT SELECT ON plscope_identifiers TO PUBLIC;
GRANT SELECT ON plscope_statements TO PUBLIC;
GRANT SELECT ON plscope_tab_usage TO PUBLIC;
GRANT SELECT ON plscope_col_usage TO PUBLIC;

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
END;
/

PROMPT ====================================================================
PROMPT Create and populate demo tables
PROMPT ====================================================================

@./demo/table/drop_demo_tables.sql
@./demo/table/dept.sql
@./demo/table/emp.sql
@./demo/table/deptsal.sql
@./demo/view/source_view.sql
SHOW ERRORS
@./demo/synonym/source_syn.sql
@./demo/package/etl.pks
SHOW ERRORS
@./demo/package/etl.pkb
SHOW ERRORS

SPOOL OFF
