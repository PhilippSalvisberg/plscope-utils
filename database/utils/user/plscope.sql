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
SET ECHO ON
SPOOL plscope.log
DEFINE username = PLSCOPE

PROMPT ====================================================================
PROMPT This script creates the user &&username with all required privileges. 
PROMPT Run this script as SYS.
PROMPT Please change default tablespace and password.
PROMPT ====================================================================

PROMPT ====================================================================
PROMPT User
PROMPT ====================================================================

CREATE USER &&username IDENTIFIED BY plscope
  DEFAULT TABLESPACE USERS
  TEMPORARY TABLESPACE TEMP;
  
PROMPT ====================================================================
PROMPT Grants
PROMPT ====================================================================

GRANT CONNECT, RESOURCE to &&username;
GRANT CREATE VIEW TO &&username;
GRANT CREATE SYNONYM TO &&username;
GRANT CREATE PUBLIC SYNONYM TO &&username;
GRANT UNLIMITED TABLESPACE to &&username;

-- to get access to DBA-views
GRANT SELECT_CATALOG_ROLE TO &&username;

-- to create views using DBA-views
GRANT SELECT ANY DICTIONARY TO &&username;

-- to parse queries in PL/SQL packages
GRANT EXECUTE ON sys.utl_xml TO &&username;

-- direct grants required for grant option
GRANT SELECT ON sys.dba_identifiers  TO &&username WITH GRANT OPTION;
GRANT SELECT ON sys.dba_statements   TO &&username WITH GRANT OPTION;
GRANT SELECT ON sys.dba_tables       TO &&username WITH GRANT OPTION;
GRANT SELECT ON sys.dba_dependencies TO &&username WITH GRANT OPTION;
GRANT SELECT ON sys.dba_synonyms     TO &&username WITH GRANT OPTION;
GRANT SELECT ON sys.dba_objects      TO &&username WITH GRANT OPTION;
GRANT SELECT ON sys.dba_tab_columns  TO &&username WITH GRANT OPTION;

-- to debug in SQL Developer
GRANT DEBUG CONNECT SESSION, DEBUG ANY PROCEDURE TO &&username;
GRANT EXECUTE ON dbms_debug_jdwp to &&username;
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
/

SPOOL OFF
