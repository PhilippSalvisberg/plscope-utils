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
CREATE OR REPLACE VIEW plscope_naming AS
WITH
   /* 
   * You may configure regular expressions for every name check. 
   * Here's an example for overriding every attribute used in this view
   * to combine various naming conventions:
   *
        BEGIN
           plscope_context.set_attr('GLOBAL_VARIABLE_REGEX',       '^(g|m)_.*');
           plscope_context.set_attr('LOCAL_RECORD_VARIABLE_REGEX', '^(r|l|v)_.*');
           plscope_context.set_attr('LOCAL_ARRAY_VARIABLE_REGEX',  '^(t|l|v)_.*');
           plscope_context.set_attr('LOCAL_OBJECT_VARIABLE_REGEX', '^(o|l|v)_.*');
           plscope_context.set_attr('LOCAL_VARIABLE_REGEX',        '(^(l|v)_.*)|(^[ij]$)');
           plscope_context.set_attr('CURSOR_REGEX',                '^(c|l)_.*');
           plscope_context.set_attr('CURSOR_PARAMETER_REGEX',      '(^(p|in|out|io)_.*)|(.*_(in|out|io)$)');
           plscope_context.set_attr('IN_PARAMETER_REGEX',          '(^(in|p)_.*)|(.*_in$)');
           plscope_context.set_attr('OUT_PARAMETER_REGEX',         '(^(out|p)_.*)|(.*_out$)');
           plscope_context.set_attr('IN_OUT_PARAMETER_REGEX',      '(^(io|p)_.*)|(.*_io$)');
           plscope_context.set_attr('RECORD_REGEX',                '^(r|tp?)_.*');
           plscope_context.set_attr('ARRAY_REGEX',                 '(^tp?_.*)|(^.*_(type?|l(ist)?|tab(type)?|t(able)?|arr(ay)?|ct|nt|ht)$)');
           plscope_context.set_attr('EXCEPTION_REGEX',             '(^ex?_.*)|(.*_exc(eption)?$)');
           plscope_context.set_attr('CONSTANT_REGEX',              '^(co?|gc?|m|l)_.*');
           plscope_context.set_attr('SUBTYPE_REGEX',               '(^tp?_.*$)|(.*_type?$)');
        END;
   *
   * To restore default-settings call: 
   *
        BEGIN
           plscope_context.remove_all;
        END;
   * 
   */
   ids AS (
      SELECT owner,
             name,
             type,
             object_name,
             object_type,
             usage,
             usage_id,
             line,
             col,
             usage_context_id
        FROM sys.dba_identifiers
       WHERE owner LIKE nvl(sys_context('PLSCOPE', 'OWNER'), USER)
   ),   
   tree AS (
       SELECT ids.owner,
              ids.object_type,
              ids.object_name,
              ids.line,
              ids.col,
              ids.name,
              level as path_len,
              ids.type,
              sys_connect_by_path(ids.type, '/') AS type_path,
              ids.usage,
              ids.usage_id,
              ids.usage_context_id,
              prior ids.type AS parent_type,
              prior ids.usage AS parent_usage,
              prior ids.line AS parent_line,
              prior ids.col AS parent_col,
              prior ids.name AS parent_name
         FROM ids
        START WITH ids.usage_context_id = 0
      CONNECT BY  PRIOR ids.usage_id    = ids.usage_context_id
              AND PRIOR ids.owner       = ids.owner
              AND PRIOR ids.object_type = ids.object_type
              AND PRIOR ids.object_name = ids.object_name
   ),
   prepared AS (
      SELECT tree.owner,
             tree.object_type,
             tree.object_name,
             last_value (
                CASE
                   WHEN tree.type in ('PROCEDURE', 'FUNCTION') AND tree.path_len = 2 THEN
                      tree.name
                END
             ) IGNORE NULLS OVER (
                PARTITION BY tree.owner, tree.object_name, tree.object_type
                ORDER BY tree.line, tree.col, tree.path_len
             ) AS procedure_name,
             (
                -- this correlated subquery will be evaluated only,
                -- if the column TEXT is selected
                SELECT regexp_replace(src.text, chr(10)||'+$', null) -- remove trailing new line character
                  FROM sys.dba_source src
                 WHERE src.owner = tree.owner
                   AND src.type = tree.object_type
                   AND src.name = tree.object_name
                   AND src.line = tree.line
             ) AS text,
             tree.usage,
             tree.type,
             tree.name,
             tree.line,
             tree.col,
             tree.type_path,
             tree.parent_usage,
             tree.parent_type,
             tree.parent_name,
             tree.parent_line,
             tree.parent_col
        FROM tree
       WHERE tree.object_type IN ('FUNCTION', 'PROCEDURE', 'TRIGGER', 'PACKAGE', 'PACKAGE BODY', 'TYPE', 'TYPE BODY')
   ),
   checked AS (
      SELECT owner,
             object_type,
             object_name,
             procedure_name,
             CASE 
                WHEN usage = 'REFERENCE' THEN
                   parent_usage 
                ELSE
                   usage
             END AS usage,
             CASE 
                WHEN usage = 'REFERENCE' THEN
                   parent_type 
                ELSE
                   type
             END AS type,
             CASE 
                WHEN usage = 'REFERENCE' THEN
                   parent_name 
                ELSE
                   name
             END AS name,
             CASE
                -- global variables (all types)
                WHEN     parent_usage = 'DECLARATION'
                     AND parent_type = 'VARIABLE'
                     AND usage = 'REFERENCE'
                     AND regexp_like(type_path, '/PACKAGE/VARIABLE/[A-Z0-9_ ]*$')
                THEN
                   CASE 
                      WHEN regexp_like(parent_name, nvl(sys_context('PLSCOPE', 'GLOBAL_VARIABLE_REGEX'), '^g_.*'), 'i') THEN
                         'OK'
                      ELSE
                         'Global variable does not match regex "' || nvl(sys_context('PLSCOPE', 'GLOBAL_VARIABLE_REGEX'), '^g_.*') || '".'
                   END 
                -- local record variables
                WHEN     parent_usage = 'DECLARATION'
                     AND parent_type = 'VARIABLE'
                     AND usage = 'REFERENCE'
                     AND (type = 'RECORD' OR regexp_like(text, '.*%\s*rowtype.*', 'i'))
                     AND object_type != 'TYPE'
                     AND NOT regexp_like(type_path, '/(RECORD|OBJECT)/VARIABLE/[A-Z0-9_ ]*$')
                THEN
                   CASE
                      WHEN regexp_like(parent_name, nvl(sys_context('PLSCOPE', 'LOCAL_RECORD_VARIABLE_REGEX'), '^r_.*'), 'i') THEN
                         'OK'
                      ELSE
                         'Local record variable does not match regex "' || nvl(sys_context('PLSCOPE', 'LOCAL_RECORD_VARIABLE_REGEX'), '^r_.*') || '".'
                   END
                -- local array/table variables
                WHEN     parent_usage = 'DECLARATION'
                     AND parent_type = 'VARIABLE'
                     AND usage = 'REFERENCE'
                     AND type IN ('ASSOCIATIVE ARRAY', 'VARRAY', 'INDEX TABLE', 'NESTED TABLE')
                     AND object_type != 'TYPE'
                     AND NOT regexp_like(type_path, '/(RECORD|OBJECT)/VARIABLE/[A-Z0-9_ ]*$')
                THEN
                   CASE
                      WHEN regexp_like(parent_name, nvl(sys_context('PLSCOPE', 'LOCAL_ARRAY_VARIABLE_REGEX'), '^t_.*'), 'i') THEN
                         'OK'
                      ELSE
                         'Local array/table variable does not match regex "' || nvl(sys_context('PLSCOPE', 'LOCAL_ARRAY_VARIABLE_REGEX'), '^t_.*') || '".'
                   END
                -- local object variables
                WHEN     parent_usage = 'DECLARATION'
                     AND parent_type = 'VARIABLE'
                     AND usage = 'REFERENCE'
                     AND type = 'OBJECT'
                     AND object_type != 'TYPE'
                     AND NOT regexp_like(type_path, '/(RECORD|OBJECT)/VARIABLE/[A-Z0-9_ ]*$')
                THEN
                   CASE
                      WHEN regexp_like(parent_name, nvl(sys_context('PLSCOPE', 'LOCAL_OBJECT_VARIABLE_REGEX'), '^o_.*'), 'i') THEN
                         'OK'
                      ELSE
                         'Local object variable does not match regex "' || nvl(sys_context('PLSCOPE', 'LOCAL_OBJECT_VARIABLE_REGEX'), '^o_.*') || '".'
                   END
                -- local variables for other types
                WHEN     parent_usage = 'DECLARATION'
                     AND parent_type = 'VARIABLE'
                     AND usage = 'REFERENCE'
                     AND object_type != 'TYPE'
                     AND NOT regexp_like(type_path, '/(RECORD|OBJECT)/VARIABLE/[A-Z0-9_ ]*$')
                THEN
                   CASE
                      WHEN regexp_like(parent_name, nvl(sys_context('PLSCOPE', 'LOCAL_VARIABLE_REGEX'), '^l_.*'), 'i') THEN
                         'OK'
                      ELSE
                         'Local variable does not match regex "' || nvl(sys_context('PLSCOPE', 'LOCAL_VARIABLE_REGEX'), '^l_.*') || '".'
                   END
                -- cursors
                WHEN     usage = 'DECLARATION'
                     AND type = 'CURSOR'
                THEN
                   CASE
                      WHEN regexp_like(name, nvl(sys_context('PLSCOPE', 'CURSOR_REGEX'), '^c_.*'), 'i') THEN
                         'OK'
                      ELSE
                         'Cursor does not match regex "' || nvl(sys_context('PLSCOPE', 'CURSOR_REGEX'), '^c_.*') || '".'
                   END
                -- cursor parameters
                WHEN     parent_usage = 'DECLARATION'
                     AND parent_type = 'CURSOR'
                     AND usage = 'DECLARATION'
                     AND type LIKE 'FORMAL%'
                THEN
                   CASE
                      WHEN regexp_like(name, nvl(sys_context('PLSCOPE', 'CURSOR_PARAMETER_REGEX'), '^p_.*'), 'i') THEN
                         'OK'
                      ELSE
                         'Cursor parameter does not match regex "' || nvl(sys_context('PLSCOPE', 'CURSOR_PARAMETER_REGEX'), '^p_.*') || '".'
                   END
                -- IN parameters
                WHEN     usage = 'DECLARATION'
                     AND type = 'FORMAL IN'
                THEN
                   CASE
                      WHEN    regexp_like(name, nvl(sys_context('PLSCOPE', 'IN_PARAMETER_REGEX'), '^in_.*'), 'i') 
                           OR (object_type IN ('TYPE', 'TYPE BODY') AND name = 'SELF')
                      THEN
                         'OK'
                      ELSE
                         'IN parameter does not match regex "' || nvl(sys_context('PLSCOPE', 'IN_PARAMETER_REGEX'), '^in_.*') || '".'
                   END
                -- OUT parameters
                WHEN     usage = 'DECLARATION'
                     AND type = 'FORMAL OUT'
                THEN
                   CASE
                      WHEN    regexp_like(name, nvl(sys_context('PLSCOPE', 'OUT_PARAMETER_REGEX'), '^out_.*'), 'i') 
                           OR (object_type IN ('TYPE', 'TYPE BODY') AND name = 'SELF')
                      THEN
                         'OK'
                      ELSE
                         'OUT parameter does not match regex "' || nvl(sys_context('PLSCOPE', 'OUT_PARAMETER_REGEX'), '^out_.*') || '".'
                   END
                -- IN OUT parameters
                WHEN     usage = 'DECLARATION'
                     AND type = 'FORMAL IN OUT'
                THEN
                   CASE
                      WHEN    regexp_like(name, nvl(sys_context('PLSCOPE', 'IN_OUT_PARAMETER_REGEX'), '^io_.*'), 'i')  
                           OR (object_type IN ('TYPE', 'TYPE BODY') AND name = 'SELF')
                      THEN
                         'OK'
                      ELSE
                         'IN OUT parameter does not match regex "' || nvl(sys_context('PLSCOPE', 'IN_OUT_PARAMETER_REGEX'), '^io_.*') || '".'
                   END
                -- records
                WHEN     usage = 'DECLARATION'
                     AND type = 'RECORD'
                THEN
                   CASE
                      WHEN regexp_like(name, nvl(sys_context('PLSCOPE', 'RECORD_REGEX'), '^r_.*_type$'), 'i') THEN
                         'OK'
                      ELSE
                         'Record does not match regex "' || nvl(sys_context('PLSCOPE', 'RECORD_REGEX'), '^r_.*_type$') || '".'
                   END
                -- arrays/tables
                WHEN     usage = 'DECLARATION'
                     AND type IN ('ASSOCIATIVE ARRAY', 'VARRAY', 'INDEX TABLE', 'NESTED TABLE')
                THEN
                   CASE
                      WHEN regexp_like(name, nvl(sys_context('PLSCOPE', 'ARRAY_REGEX'), '^t_.*_type$'), 'i') THEN
                         'OK'
                      ELSE
                         'Array/table does not match regex "' || nvl(sys_context('PLSCOPE', 'ARRAY_REGEX'), '^t_.*_type$') || '".'
                   END
                -- exceptions
                WHEN     usage = 'DECLARATION'
                     AND type = 'EXCEPTION'
                THEN
                   CASE
                      WHEN regexp_like(name, nvl(sys_context('PLSCOPE', 'EXCEPTION_REGEX'), '^e_.*'), 'i') THEN
                         'OK'
                      ELSE
                         'Exception does not match regex "' || nvl(sys_context('PLSCOPE', 'EXCEPTION_REGEX'), '^e_.*') || '".'
                   END
                -- constants
                WHEN     usage = 'DECLARATION'
                     AND type = 'CONSTANT'
                THEN
                   CASE
                      WHEN regexp_like(name, nvl(sys_context('PLSCOPE', 'CONSTANT_REGEX'), '^co_.*'), 'i') THEN
                         'OK'
                      ELSE
                         'Constant does not match regex "' || nvl(sys_context('PLSCOPE', 'CONSTANT_REGEX'), '^co_.*') || '".'
                   END
                -- subtypes
                WHEN     usage = 'DECLARATION'
                     AND type = 'SUBTYPE'
                THEN
                   CASE
                      WHEN regexp_like(name, nvl(sys_context('PLSCOPE', 'SUBTYPE_REGEX'), '.*_type$'), 'i') THEN
                         'OK'
                      ELSE
                         'Subtype does not match regex "' || nvl(sys_context('PLSCOPE', 'SUBTYPE_REGEX'), '.*_type$') || '".'
                   END
             END AS message,
             CASE 
                WHEN usage = 'REFERENCE' THEN
                   parent_line 
                ELSE
                   line
             END AS line,
             CASE 
                WHEN usage = 'REFERENCE' THEN
                   parent_col 
                ELSE
                   col
             END AS col,
             text
        FROM prepared
   )
SELECT owner, 
       object_type, 
       object_name, 
       procedure_name,
       type,
       name,
       message,
       line,
       col,
       text
  FROM checked
 WHERE message IS NOT NULL;
