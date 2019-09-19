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

SET DEFINE ON
SET ECHO OFF
SET VERIFY OFF

PROMPT ====================================================================
PROMPT Parameter defaults for username (1), password (2) and tablespace (3)
PROMPT ====================================================================

COLUMN 1 NEW_VALUE 1 NOPRINT;
COLUMN 2 NEW_VALUE 2 NOPRINT;
COLUMN 3 NEW_VALUE 3 NOPRINT;

SET FEEDBACK OFF

SELECT NULL AS "1", 
       NULL AS "2" , 
       NULL AS "3" 
  FROM dual 
 WHERE rownum = 0;

COLUMN username   NEW_VALUE username   NOPRINT
COLUMN password   NEW_VALUE password   NOPRINT
COLUMN tablespace NEW_VALUE tablespace NOPRINT

SELECT coalesce('&&1', 'plscope') AS username,
       coalesce('&&2', 'plscope') AS password,
       coalesce('&&3', 'users')   AS tablespace
  FROM dual;

SET FEEDBACK ON

PROMPT ====================================================================
PROMPT This script creates the user &&username with all required privileges.
PROMPT Run this script as SYS or as ADMIN in the Oracle Cloud.
PROMPT ====================================================================

PROMPT ====================================================================
PROMPT User
PROMPT ====================================================================

CREATE USER &&username IDENTIFIED BY &&password
  DEFAULT TABLESPACE &&tablespace
  TEMPORARY TABLESPACE TEMP;

PROMPT ====================================================================
PROMPT Grants
PROMPT ====================================================================

GRANT CONNECT                        TO &&username;
GRANT RESOURCE                       TO &&username;
GRANT CREATE VIEW                    TO &&username;
GRANT CREATE SYNONYM                 TO &&username;
GRANT CREATE PUBLIC SYNONYM          TO &&username;
GRANT DROP PUBLIC SYNONYM            TO &&username;
GRANT UNLIMITED TABLESPACE           TO &&username;
GRANT CREATE ANY CONTEXT             TO &&username;
GRANT DROP ANY CONTEXT               TO &&username;

-- to get access to DBA-views
GRANT SELECT_CATALOG_ROLE            TO &&username;

-- to create views using DBA-views
GRANT SELECT ANY DICTIONARY          TO &&username;

-- direct grants required for grant option
GRANT SELECT ON sys.dba_identifiers  TO &&username WITH GRANT OPTION;
GRANT SELECT ON sys.dba_statements   TO &&username WITH GRANT OPTION;
GRANT SELECT ON sys.dba_tables       TO &&username WITH GRANT OPTION;
GRANT SELECT ON sys.dba_views        TO &&username WITH GRANT OPTION;
GRANT SELECT ON sys.dba_dependencies TO &&username WITH GRANT OPTION;
GRANT SELECT ON sys.dba_synonyms     TO &&username WITH GRANT OPTION;
GRANT SELECT ON sys.dba_objects      TO &&username WITH GRANT OPTION;
GRANT SELECT ON sys.dba_tab_columns  TO &&username WITH GRANT OPTION;
GRANT SELECT ON sys.dba_source       TO &&username WITH GRANT OPTION;

-- direct grant for ETL demo package
GRANT SELECT ON v$mystat             TO &&username;

-- for debugging
GRANT DEBUG CONNECT SESSION          TO &&username;
GRANT DEBUG ANY PROCEDURE            TO &&username;
GRANT EXECUTE ON dbms_debug_jdwp     TO &&username;

PROMPT ====================================================================
PROMPT Optional grants based on privileges
PROMPT ====================================================================

DECLARE
   PROCEDURE exec_sql (in_sql IN VARCHAR2) IS
   BEGIN
      EXECUTE IMMEDIATE in_sql;
   END exec_sql; 
   --
   PROCEDURE options IS
      l_count INTEGER;
   BEGIN
      SELECT count(*)
        INTO l_count
        FROM all_objects
       WHERE object_name IN ('UTL_XML', 'UTL_XML_LIB');
      IF l_count > 0 THEN
         -- to parse queries in PL/SQL packages
         exec_sql('GRANT EXECUTE ON sys.utl_xml     TO &&username'); -- for 12.2 only
         exec_sql('GRANT EXECUTE ON sys.utl_xml_lib TO &&username'); -- for >= 18.0 only
         -- for remote debugging
         exec_sql(q'[
            BEGIN
              dbms_network_acl_admin.append_host_ace (
                host =>'*',
                ace  => sys.xs$ace_type(
                            privilege_list => sys.xs$name_list('JDWP') ,
                            principal_name => '&&username',
                            principal_type => sys.xs_acl.ptype_db
                        )
              );
            END;
         ]');
      END IF;
   END options;
BEGIN
   options;
END;
/
