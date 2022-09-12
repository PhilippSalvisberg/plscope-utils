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

prompt
prompt ====================================================================
prompt Sanity check: this script will fail with ORA-01722 invalid number
prompt if run as SYSDBA, or if the current schema is SYS or SYSTEM.
prompt ====================================================================
prompt

-- Needed for the script to stop if any SQL exception is raised
whenever sqlerror exit failure rollback

set feedback 0

select to_number('MUST_NOT_BE_SYSDBA') 
  from dual
 where sys_context('USERENV', 'ISDBA') = 'TRUE';

select to_number('MUST_NOT_BE_SYS')
  from dual
 where sys_context('USERENV', 'CURRENT_SCHEMA') = 'SYS';
 
select to_number('MUST_NOT_BE_SYSTEM')
  from dual
 where sys_context('USERENV', 'CURRENT_SCHEMA') = 'SYSTEM';

set feedback on

-- Revert to the default handling of SQL exceptions
whenever sqlerror continue none

