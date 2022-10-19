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
create or replace view plscope_naming as
   with
      /* 
      * You may configure regular expressions for every name check. 
      * Here's an example for overriding every attribute used in this view
      * to combine various naming conventions:
      *
           begin
              plscope_context.set_attr('GLOBAL_VARIABLE_REGEX',       '^(g|m)_.*');
              plscope_context.set_attr('LOCAL_RECORD_VARIABLE_REGEX', '^(r|l|v)_.*');
              plscope_context.set_attr('LOCAL_ARRAY_VARIABLE_REGEX',  '^(t|l|v)_.*');
              plscope_context.set_attr('LOCAL_OBJECT_VARIABLE_REGEX', '^(o|l|v)_.*');
              plscope_context.set_attr('LOCAL_VARIABLE_REGEX',        '(^(l|v|c)_.*)|(^[ij]$)');
              plscope_context.set_attr('CURSOR_REGEX',                '^(c|l)_.*');
              plscope_context.set_attr('CURSOR_PARAMETER_REGEX',      '(^(p|in|out|io)_.*)|(.*_(in|out|io)$)');
              plscope_context.set_attr('IN_PARAMETER_REGEX',          '(^(in|p)_.*)|(.*_in$)');
              plscope_context.set_attr('OUT_PARAMETER_REGEX',         '(^(out|p)_.*)|(.*_out$)');
              plscope_context.set_attr('IN_OUT_PARAMETER_REGEX',      '(^(io|p)_.*)|(.*_io$)');
              plscope_context.set_attr('RECORD_REGEX',                '^(r|tp?)_.*');
              plscope_context.set_attr('ARRAY_REGEX',                 '(^tp?_.*)|(^.*_(type?|l(ist)?|tab(type)?|t(able)?|arr(ay)?|ct|nt|ht)$)');
              plscope_context.set_attr('EXCEPTION_REGEX',             '(^ex?_.*)|(.*_exc(eption)?$)');
              plscope_context.set_attr('CONSTANT_REGEX',              '^(co?|gc?|m|l|k)_.*');
              plscope_context.set_attr('SUBTYPE_REGEX',               '(^tp?_.*$)|(.*_type?$)');
           end;
      *
      * To restore default-settings call: 
      *
           begin
              plscope_context.remove_all;
           end;
      * 
      */
      src as (
         select /*+ materialize */
                owner,
                type,
                name,
                line,
                text
           from sys.dba_source -- NOSONAR: avoid public synonym
          where owner like coalesce(sys_context('PLSCOPE', 'OWNER'), user)
            and type like coalesce(sys_context('PLSCOPE', 'OBJECT_TYPE'), '%')
            and name like coalesce(sys_context('PLSCOPE', 'OBJECT_NAME'), '%')
      ),
      ids as (
         select owner,
                name,
                type,
                object_name,
                object_type,
                usage,
                usage_id,
                line,
                col,
                usage_context_id
           from sys.dba_identifiers -- NOSONAR: avoid public synonym
          where owner like coalesce(sys_context('PLSCOPE', 'OWNER'), user)
            and object_type like coalesce(sys_context('PLSCOPE', 'OBJECT_TYPE'), '%')
            and object_name like coalesce(sys_context('PLSCOPE', 'OBJECT_NAME'), '%')
      ),
      tree (
         owner,
         object_type,
         object_name,
         line,
         col,
         procedure_name,
         name,
         name_path,
         path_len,
         type,
         type_path,
         parent_usage,
         parent_type,
         parent_name,
         parent_line,
         parent_col,
         usage,
         usage_id,
         usage_context_id
      ) as (
         select owner,
                object_type,
                object_name,
                line,
                col,
                case
                   when object_type in ('PROCEDURE', 'FUNCTION') then
                      name
                end as procedure_name,
                name,
                '/' || name as name_path,
                1 as path_len,
                type,
                '/' || type as type_path,
                null as parent_usage,
                null as parent_type,
                null as parent_name,
                null as parent_line,
                null as parent_col,
                usage,
                usage_id,
                usage_context_id
           from ids
          where usage_context_id = 0  -- top-level identifiers
         union all
         select ids.owner,
                ids.object_type,
                ids.object_name,
                ids.line,
                ids.col,
                case
                   when tree.procedure_name is not null then
                      tree.procedure_name
                   when ids.object_type in ('PACKAGE', 'PACKAGE BODY')
                      and ids.type in ('FUNCTION', 'PROCEDURE')
                      and ids.usage in ('DEFINITION', 'DECLARATION')
                      and ids.usage_context_id = 1
                   then
                      ids.name
                end as procedure_name,
                ids.name,
                case
                   when lengthb(tree.name_path) + lengthb('/') + lengthb(ids.name) <= 4000 then
                      tree.name_path
                      || '/'
                      || ids.name
                   else
                      -- prevent name_path from overflowing: keep the first 3 elements, then
                      -- remove enough elements to accomodate "..." + "/" + the tail end
                      regexp_substr(tree.name_path, '^(/([^/]+/){3})')
                      || '...'
                      || regexp_replace(
                         substr(tree.name_path, instr(tree.name_path, '/', 1, 4) + 1
                            + lengthb('.../') + lengthb(ids.name)),
                         '^[^/]*')
                      || '/'
                      || ids.name
                end as name_path,
                tree.path_len + 1 as path_len,
                ids.type,
                case
                   when lengthb(tree.type_path) + lengthb('/') + lengthb(ids.type) <= 4000 then
                      tree.type_path
                      || '/'
                      || ids.type
                   else
                      -- prevent name_path from overflowing: keep the first 3 elements, then
                      -- remove enough elements to accomodate "..." + "/" + the tail end
                      regexp_substr(tree.type_path, '^(/([^/]+/){3})')
                      || '...'
                      || regexp_replace(
                         substr(tree.type_path, instr(tree.type_path, '/', 1, 4) + 1
                            + lengthb('.../') + lengthb(ids.type)),
                         '^[^/]*')
                      || '/'
                      || ids.type
                end as type_path,
                tree.usage as parent_usage,
                tree.type as parent_type,
                tree.name as parent_name,
                tree.line as parent_line,
                tree.col as parent_col,
                ids.usage,
                ids.usage_id,
                ids.usage_context_id
           from tree
           join ids
             on tree.owner = ids.owner
            and tree.object_type = ids.object_type
            and tree.object_name = ids.object_name
            and tree.usage_id = ids.usage_context_id
      ) cycle owner, object_type, object_name, usage_id set is_cycle to 'Y' default 'N',
      prepared as (
         select tree.owner,
                tree.object_type,
                tree.object_name,
                last_value (
                   case
                      when tree.type in ('PROCEDURE', 'FUNCTION')
                         and tree.path_len = 2
                      then
                         tree.name
                   end
                ) ignore nulls over (
                   partition by tree.owner, tree.object_name, tree.object_type
                   order by tree.line, tree.col, tree.path_len
                ) as procedure_name,
                regexp_replace(src.text, chr(10) || '+$', null) as text, -- remove trailing new line character
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
           from tree
           left join src
             on src.owner = tree.owner
            and src.type = tree.object_type
            and src.name = tree.object_name
            and src.line = tree.line
          where tree.object_type in ('FUNCTION', 'PROCEDURE', 'TRIGGER', 'PACKAGE', 'PACKAGE BODY', 'TYPE', 'TYPE BODY')
      ),
      checked as (
         select owner,
                object_type,
                object_name,
                procedure_name,
                case
                   when usage = 'REFERENCE' then
                      parent_usage
                   else
                      usage
                end as usage,
                case
                   when usage = 'REFERENCE' then
                      parent_type
                   else
                      type
                end as type,
                case
                   when usage = 'REFERENCE' then
                      parent_name
                   else
                      name
                end as name,
                case
                   -- global variables (all types)
                   when parent_usage = 'DECLARATION'
                      and parent_type = 'VARIABLE'
                      and usage = 'REFERENCE'
                      and regexp_like(type_path, '/PACKAGE/VARIABLE/[A-Z0-9_ ]*$')
                   then
                      case
                         when regexp_like(parent_name, nvl(sys_context('PLSCOPE', 'GLOBAL_VARIABLE_REGEX'), '^g_.*'), 'i')
                         then
                            'OK'
                         else
                            'Global variable does not match regex "'
                            || nvl(sys_context('PLSCOPE', 'GLOBAL_VARIABLE_REGEX'), '^g_.*')
                            || '".'
                      end 
                      -- local record variables
                   when parent_usage = 'DECLARATION'
                      and parent_type = 'VARIABLE'
                      and usage = 'REFERENCE'
                      and (type = 'RECORD' or regexp_like(text, '.*%\s*rowtype.*', 'i'))
                      and object_type != 'TYPE'
                      and not regexp_like(type_path, '/(RECORD ITERATOR|RECORD|OBJECT)/VARIABLE/[A-Z0-9_ ]*$')
                   then
                      case
                         when regexp_like(parent_name, nvl(sys_context('PLSCOPE', 'LOCAL_RECORD_VARIABLE_REGEX'), '^r_.*'),
                            'i')
                         then
                            'OK'
                         else
                            'Local record variable does not match regex "'
                            || nvl(sys_context('PLSCOPE', 'LOCAL_RECORD_VARIABLE_REGEX'), '^r_.*')
                            || '".'
                      end
                      -- local array/table variables
                   when parent_usage = 'DECLARATION'
                      and parent_type = 'VARIABLE'
                      and usage = 'REFERENCE'
                      and type in ('ASSOCIATIVE ARRAY', 'VARRAY', 'INDEX TABLE', 'NESTED TABLE')
                      and object_type != 'TYPE'
                      and not regexp_like(type_path, '/(RECORD ITERATOR|RECORD|OBJECT)/VARIABLE/[A-Z0-9_ ]*$')
                   then
                      case
                         when regexp_like(parent_name, nvl(sys_context('PLSCOPE', 'LOCAL_ARRAY_VARIABLE_REGEX'), '^t_.*'),
                            'i')
                         then
                            'OK'
                         else
                            'Local array/table variable does not match regex "'
                            || nvl(sys_context('PLSCOPE', 'LOCAL_ARRAY_VARIABLE_REGEX'), '^t_.*')
                            || '".'
                      end
                      -- local object variables
                   when parent_usage = 'DECLARATION'
                      and parent_type = 'VARIABLE'
                      and usage = 'REFERENCE'
                      and type = 'OBJECT'
                      and object_type != 'TYPE'
                      and not regexp_like(type_path, '/(RECORD ITERATOR|RECORD|OBJECT)/VARIABLE/[A-Z0-9_ ]*$')
                   then
                      case
                         when regexp_like(parent_name, nvl(sys_context('PLSCOPE', 'LOCAL_OBJECT_VARIABLE_REGEX'), '^o_.*'),
                            'i')
                         then
                            'OK'
                         else
                            'Local object variable does not match regex "'
                            || nvl(sys_context('PLSCOPE', 'LOCAL_OBJECT_VARIABLE_REGEX'), '^o_.*')
                            || '".'
                      end
                      -- local variables for other types
                   when parent_usage = 'DECLARATION'
                      and parent_type = 'VARIABLE'
                      and usage = 'REFERENCE'
                      and object_type != 'TYPE'
                      and not regexp_like(type_path, '/(RECORD ITERATOR|RECORD|OBJECT)/VARIABLE/[A-Z0-9_ ]*$')
                   then
                      case
                         when regexp_like(parent_name, nvl(sys_context('PLSCOPE', 'LOCAL_VARIABLE_REGEX'), '^(l|c)_.*'), 'i')
                         then
                            'OK'
                         else
                            'Local variable does not match regex "'
                            || nvl(sys_context('PLSCOPE', 'LOCAL_VARIABLE_REGEX'), '^(l|c)_.*')
                            || '".'
                      end
                      -- cursors
                   when usage = 'DECLARATION'
                      and type = 'CURSOR'
                   then
                      case
                         when regexp_like(name, nvl(sys_context('PLSCOPE', 'CURSOR_REGEX'), '^c_.*'), 'i') then
                            'OK'
                         else
                            'Cursor does not match regex "'
                            || nvl(sys_context('PLSCOPE', 'CURSOR_REGEX'), '^c_.*')
                            || '".'
                      end
                      -- cursor parameters
                   when parent_usage = 'DECLARATION'
                      and parent_type = 'CURSOR'
                      and usage = 'DECLARATION'
                      and type like 'FORMAL%'
                   then
                      case
                         when regexp_like(name, nvl(sys_context('PLSCOPE', 'CURSOR_PARAMETER_REGEX'), '^p_.*'), 'i') then
                            'OK'
                         else
                            'Cursor parameter does not match regex "'
                            || nvl(sys_context('PLSCOPE', 'CURSOR_PARAMETER_REGEX'), '^p_.*')
                            || '".'
                      end
                      -- IN parameters
                   when usage = 'DECLARATION'
                      and type = 'FORMAL IN'
                   then
                      case
                         when regexp_like(name, nvl(sys_context('PLSCOPE', 'IN_PARAMETER_REGEX'), '^in_.*'), 'i')
                            or (object_type in ('TYPE', 'TYPE BODY') and name = 'SELF')
                         then
                            'OK'
                         else
                            'IN parameter does not match regex "'
                            || nvl(sys_context('PLSCOPE', 'IN_PARAMETER_REGEX'), '^in_.*')
                            || '".'
                      end
                      -- OUT parameters
                   when usage = 'DECLARATION'
                      and type = 'FORMAL OUT'
                   then
                      case
                         when regexp_like(name, nvl(sys_context('PLSCOPE', 'OUT_PARAMETER_REGEX'), '^out_.*'), 'i')
                            or (object_type in ('TYPE', 'TYPE BODY') and name = 'SELF')
                         then
                            'OK'
                         else
                            'OUT parameter does not match regex "'
                            || nvl(sys_context('PLSCOPE', 'OUT_PARAMETER_REGEX'), '^out_.*')
                            || '".'
                      end
                      -- IN OUT parameters
                   when usage = 'DECLARATION'
                      and type = 'FORMAL IN OUT'
                   then
                      case
                         when regexp_like(name, nvl(sys_context('PLSCOPE', 'IN_OUT_PARAMETER_REGEX'), '^io_.*'), 'i')
                            or (object_type in ('TYPE', 'TYPE BODY') and name = 'SELF')
                         then
                            'OK'
                         else
                            'IN OUT parameter does not match regex "'
                            || nvl(sys_context('PLSCOPE', 'IN_OUT_PARAMETER_REGEX'), '^io_.*')
                            || '".'
                      end
                      -- records
                   when usage = 'DECLARATION'
                      and type = 'RECORD'
                   then
                      case
                         when regexp_like(name, nvl(sys_context('PLSCOPE', 'RECORD_REGEX'), '^r_.*_type$'), 'i') then
                            'OK'
                         else
                            'Record does not match regex "'
                            || nvl(sys_context('PLSCOPE', 'RECORD_REGEX'), '^r_.*_type$')
                            || '".'
                      end
                      -- arrays/tables
                   when usage = 'DECLARATION'
                      and type in ('ASSOCIATIVE ARRAY', 'VARRAY', 'INDEX TABLE', 'NESTED TABLE')
                   then
                      case
                         when regexp_like(name, nvl(sys_context('PLSCOPE', 'ARRAY_REGEX'), '^t_.*_type$|^.*_ct$'), 'i') then
                            'OK'
                         else
                            'Array/table does not match regex "'
                            || nvl(sys_context('PLSCOPE', 'ARRAY_REGEX'), '^t_.*_type$')
                            || '".'
                      end
                      -- exceptions
                   when usage = 'DECLARATION'
                      and type = 'EXCEPTION'
                   then
                      case
                         when regexp_like(name, nvl(sys_context('PLSCOPE', 'EXCEPTION_REGEX'), '^e_.*'), 'i') then
                            'OK'
                         else
                            'Exception does not match regex "'
                            || nvl(sys_context('PLSCOPE', 'EXCEPTION_REGEX'), '^e_.*')
                            || '".'
                      end
                      -- constants
                   when usage = 'DECLARATION'
                      and type = 'CONSTANT'
                   then
                      case
                         when regexp_like(name, nvl(sys_context('PLSCOPE', 'CONSTANT_REGEX'), '^co_.*'), 'i') then
                            'OK'
                         else
                            'Constant does not match regex "'
                            || nvl(sys_context('PLSCOPE', 'CONSTANT_REGEX'), '^co_.*')
                            || '".'
                      end
                      -- subtypes
                   when usage = 'DECLARATION'
                      and type = 'SUBTYPE'
                   then
                      case
                         when regexp_like(name, nvl(sys_context('PLSCOPE', 'SUBTYPE_REGEX'), '.*_type$'), 'i') then
                            'OK'
                         else
                            'Subtype does not match regex "'
                            || nvl(sys_context('PLSCOPE', 'SUBTYPE_REGEX'), '.*_type$')
                            || '".'
                      end
                end as message,
                case
                   when usage = 'REFERENCE' then
                      parent_line
                   else
                      line
                end as line,
                case
                   when usage = 'REFERENCE' then
                      parent_col
                   else
                      col
                end as col,
                text
           from prepared
      )
   select owner,
          object_type,
          object_name,
          procedure_name,
          type,
          name,
          message,
          line,
          col,
          text
     from checked
    where message is not null
/
