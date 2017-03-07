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
SPOOL plscope.log

PROMPT ====================================================================
PROMPT This script creates the user PLSCOPE with all required privileges. 
PROMPT Run this script as SYS.
PROMPT Please change default tablespace and password.
PROMPT ====================================================================

PROMPT ====================================================================
PROMPT User
PROMPT ====================================================================

CREATE USER plscope IDENTIFIED BY plscope
  DEFAULT TABLESPACE USERS
  TEMPORARY TABLESPACE TEMP;
  
PROMPT ====================================================================
PROMPT Grants
PROMPT ====================================================================

GRANT CONNECT, RESOURCE to plscope;
GRANT CREATE VIEW TO plscope;
GRANT CREATE SYNONYM TO plscope;
GRANT CREATE PUBLIC SYNONYM TO plscope;
GRANT UNLIMITED TABLESPACE to plscope;

-- to get access to DBA-views
GRANT SELECT_CATALOG_ROLE TO plscope;

-- to create views using DBA-views
GRANT SELECT ANY DICTIONARY TO plscope;

-- to parse queries in PL/SQL packages
GRANT EXECUTE ON sys.utl_xml TO plscope;

-- direct grants required for grant option
GRANT SELECT ON sys.dba_identifiers TO plscope WITH GRANT OPTION;
GRANT SELECT ON sys.dba_statements TO plscope WITH GRANT OPTION;
GRANT SELECT ON sys.dba_tables TO plscope WITH GRANT OPTION;
GRANT SELECT ON sys.dba_dependencies TO plscope WITH GRANT OPTION;
GRANT SELECT ON sys.dba_synonyms TO plscope WITH GRANT OPTION;
GRANT SELECT ON sys.dba_objects TO plscope WITH GRANT OPTION;
GRANT SELECT ON sys.dba_tab_columns TO plscope WITH GRANT OPTION;

PROMPT ====================================================================
PROMPT Enable PL/Scope on this instance
PROMPT ====================================================================

ALTER SYSTEM SET plscope_settings='identifiers:all, statements:all' SCOPE=BOTH;

PROMPT ====================================================================
PROMPT Recompile DBMS_OUTPUT package and its synonym for demo purposes
PROMPT ====================================================================

ALTER PACKAGE dbms_output COMPILE;

-- without recompile the result result in PLSCOPE_IDENTIFIERS is incomplete
ALTER PUBLIC SYNONYM dbms_output COMPILE;
ALTER PUBLIC SYNONYM v$mystat COMPILE;

SPOOL OFF
