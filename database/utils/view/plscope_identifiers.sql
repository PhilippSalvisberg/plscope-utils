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

create or replace view plscope_identifiers as
   with
      -- database source filtered by PLSCOPE context attributes
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
      -- PL/SQL identifiers filtered by PLSCOPE context attributes
      pls_ids as (
         select /*+ materialize */
                owner,
                name,
                signature,
                type,
                object_name,
                object_type,
                usage,
                usage_id,
                line,
                col,
                usage_context_id,
                origin_con_id
           from sys.dba_identifiers -- NOSONAR: avoid public synonym
          where owner like coalesce(sys_context('PLSCOPE', 'OWNER'), user)
            and object_type like coalesce(sys_context('PLSCOPE', 'OBJECT_TYPE'), '%')
            and object_name like coalesce(sys_context('PLSCOPE', 'OBJECT_NAME'), '%')
      ),
      -- SQL identifiers filtered by PLSCOPE context attributes
      sql_ids as (
         select /*+ materialize */
                owner,
                nvl(sql_id, type) as name,
                signature,
                type,
                object_name,
                object_type,
                nvl2(sql_id, 'SQL_ID', 'SQL_STMT') as usage, -- new, artificial usage
                usage_id,
                line,
                col,
                usage_context_id,
                origin_con_id
           from sys.dba_statements -- NOSONAR: avoid public synonym
          where owner like coalesce(sys_context('PLSCOPE', 'OWNER'), user)
            and object_type like coalesce(sys_context('PLSCOPE', 'OBJECT_TYPE'), '%')
            and object_name like coalesce(sys_context('PLSCOPE', 'OBJECT_NAME'), '%')
      ),
      -- full list of identifiers (PL/SQL and SQL) with columns is_sql_stmt and procedure_scope 
      fids as (
         select 'NO' as is_sql_stmt,
                pls_ids.owner,
                pls_ids.name,
                pls_ids.signature,
                pls_ids.type,
                pls_ids.object_name,
                pls_ids.object_type,
                pls_ids.usage,
                pls_ids.usage_id,
                pls_ids.line,
                pls_ids.col,
                pls_ids.usage_context_id,
                nvl2(sig.signature, 'PUBLIC', cast(null as varchar2(7 char))) as procedure_scope,
                pls_ids.origin_con_id
           from pls_ids
           left join pls_ids sig
             on sig.owner = pls_ids.owner
            and sig.object_type = 'PACKAGE'
            and sig.object_name = pls_ids.object_name
            and sig.usage = 'DECLARATION'
            and sig.signature = pls_ids.signature
         union all
         select 'YES' as is_sql_stmt,
                owner,
                name,
                signature,
                type,
                object_name,
                object_type,
                usage,
                usage_id,
                line,
                col,
                usage_context_id,
                null as procedure_scope,
                origin_con_id
           from sql_ids
      ),
      -- add column sane_fk to list of identifiers
      base_ids as (
         select fids.is_sql_stmt,
                fids.owner,
                fids.name,
                fids.signature,
                fids.type,
                fids.object_name,
                fids.object_type,
                fids.usage,
                fids.usage_id,
                case
                   when parent.usage_id is not null
                      or fids.usage_context_id = 0
                   then
                      'YES'
                   else
                      'NO'
                end as sane_fk,
                fids.line,
                fids.col,
                fids.usage_context_id,
                fids.procedure_scope,
                fids.origin_con_id
           from fids
           left join fids parent
             on parent.owner = fids.owner
            and parent.object_type = fids.object_type
            and parent.object_name = fids.object_name
            and parent.usage_id = fids.usage_context_id
      ),
      -- add columns usage_context_id, is_fixed_context_id to list of identifiers
      ids as (
         select is_sql_stmt,
                owner,
                name,
                signature,
                type,
                object_name,
                object_type,
                usage,
                usage_id,
                line,
                col,
                case
                   when sane_fk = 'YES' then
                      usage_context_id
                   else
                      last_value(case
                                    when sane_fk = 'YES' then
                                       usage_id
                                 end) ignore nulls over (
                         partition by owner, object_name, object_type
                         order by line, col, usage_id
                         rows between unbounded preceding and 1 preceding
                      )
                end as usage_context_id,        -- fix broken hierarchies
                case
                   when sane_fk = 'NO' then
                      cast('YES' as varchar2(3 char))
                end as is_fixed_context_id,     -- indicator of fixed hierarchies
                procedure_scope,
                origin_con_id
           from base_ids
      ),
      -- recursive with clause to extend the list of identifiers with the columns
      -- procedure_name, procedure_scope, name_path, path_len (level), procedure_signature,
      -- parent_statement_type, parent_statement_signature, parent_statement_path_len,
      -- is_def_child_of_decl
      tree (
         owner,
         object_type,
         object_name,
         line,
         col,
         procedure_name,
         procedure_scope,
         name,
         name_path,
         path_len,
         module_name,
         type,
         usage,
         signature,
         usage_id,
         usage_context_id,
         is_fixed_context_id,
         procedure_signature,
         is_sql_stmt,
         parent_statement_type,
         parent_statement_signature,
         parent_statement_path_len,
         is_def_child_of_decl,
         origin_con_id
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
                case
                   when object_type in ('PROCEDURE', 'FUNCTION') then
                      cast('PUBLIC' as varchar2(7 char))
                end as procedure_scope,
                name,
                '/' || name as name_path,
                1 as path_len,
                null as module_name,
                type,
                usage,
                signature,
                usage_id,
                usage_context_id,
                is_fixed_context_id,
                case
                   when object_type in ('PROCEDURE', 'FUNCTION') then
                      signature
                end as procedure_signature,
                is_sql_stmt,
                cast(null as varchar2(18 char)) as parent_statement_type,
                cast(null as varchar2(32 char)) as parent_statement_signature,
                cast(null as number) as parent_statement_path_len,
                cast(null as varchar2(3 char)) as is_def_child_of_decl,
                origin_con_id
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
                case
                   when tree.procedure_scope is not null then
                      tree.procedure_scope
                   when ids.object_type = 'PACKAGE'
                      and ids.type in ('FUNCTION', 'PROCEDURE')
                      and ids.usage = 'DECLARATION'
                      and ids.usage_context_id = 1
                   then
                      'PUBLIC'
                   when ids.object_type = 'PACKAGE BODY'
                      and ids.type in ('FUNCTION', 'PROCEDURE')
                      and ids.usage in ('DEFINITION', 'DECLARATION')
                      and ids.usage_context_id = 1
                   then
                      case ids.procedure_scope
                         when 'PUBLIC' then
                            'PUBLIC'
                         else
                            'PRIVATE'
                      end
                end as procedure_scope,
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
                case
                   when ids.type in ('FUNCTION', 'PROCEDURE')
                      and ids.usage = 'DEFINITION'
                   then
                      case
                         when tree.module_name is null then
                            ids.name
                         when lengthb(tree.module_name) + lengthb(':') + lengthb(ids.name) <= 4000 then
                            tree.module_name
                            || '.'
                            || ids.name
                         else
                            -- stop adding sub-module name on overflow (very unlikely)
                            tree.module_name
                      end
                   else
                      tree.module_name
                end as modul_name,
                ids.type,
                ids.usage,
                ids.signature,
                ids.usage_id,
                ids.usage_context_id,
                ids.is_fixed_context_id,
                case
                   when tree.procedure_signature is not null then
                      tree.procedure_signature
                   when ids.object_type in ('PACKAGE', 'PACKAGE BODY')
                      and ids.type in ('FUNCTION', 'PROCEDURE')
                      and ids.usage in ('DEFINITION', 'DECLARATION')
                      and ids.usage_context_id = 1
                   then
                      ids.signature
                end as procedure_signature,
                ids.is_sql_stmt,
                case
                   when tree.is_sql_stmt = 'YES' then
                      tree.type
                   else
                      tree.parent_statement_type
                end as parent_statement_type,
                case
                   when tree.is_sql_stmt = 'YES' then
                      tree.signature
                   else
                      tree.parent_statement_signature
                end as parent_statement_signature,
                case
                   when tree.is_sql_stmt = 'YES' then
                      tree.path_len
                   else
                      tree.parent_statement_path_len
                end as parent_statement_path_len,
                case
                   when ids.type in ('PROCEDURE', 'FUNCTION')
                      and ids.usage = 'DEFINITION'
                   then
                      case
                         when tree.usage = 'DECLARATION'
                            and ids.signature = tree.signature
                         then
                            'YES'
                         else
                            'NO'
                      end
                end as is_def_child_of_decl,
                ids.origin_con_id
           from tree
           join ids
             on tree.owner = ids.owner
            and tree.object_type = ids.object_type
            and tree.object_name = ids.object_name
            and tree.usage_id = ids.usage_context_id
      ) cycle owner, object_type, object_name, usage_id set is_cycle to 'Y' default 'N',
      -- add the columns name_usage, is_new_proc to the list of identifiers
      tree_plus as (
         select tree.*,                                                 -- @formatter:off
                case
                   when tree.usage = 'SQL_ID' then
                      tree.type || ' statement (sql_id: ' || tree.name || ')'
                   when tree.usage = 'SQL_STMT' then
                      tree.type || ' statement'
                   else
                      tree.name || ' (' || lower(tree.type) || ' ' || lower(tree.usage) || ')'
                end as name_usage,                                      -- @formatter:on
                case
                   when type in ('PROCEDURE', 'FUNCTION')
                      and usage = 'DEFINITION'
                      and nvl(
                         lag(
                            procedure_signature,
                            case is_def_child_of_decl
                               when 'YES' then
                                  2
                               else
                                  1
                            end
                         ) over (
                            partition by tree.owner, tree.object_type, tree.object_name
                            order by usage_id asc
                         ),
                         '----'
                      ) != procedure_signature
                   then
                      'YES'
                end as is_new_proc
           from tree
      )
   -- add indent to column name_usage, fix column usage and adds the columns text, is_used,
   -- proc_ends_before_line, proc_ends_before_col, ref_line, ref_col to the list of identifiers
   select tree.owner,
          tree.object_type,
          tree.object_name,
          tree.line,
          tree.col,
          tree.procedure_name,
          tree.procedure_scope,
          cast( -- NOSONAR: G-9030, false positive, will be truncated, default cannot be applied here
             -- left indent name_usage according to path_len, wrapping to the left
             -- if necessary so as not to exceed a limit of 250 characters
             case
                when mod(2 * (tree.path_len - 1), 250) + length(tree.name_usage) <= 250 then
                   lpad(' ', mod(2 * (tree.path_len - 1), 250)) || tree.name_usage
                else
                   substr(tree.name_usage, 250 - mod(2 * (tree.path_len - 1), 250)
                      - length(tree.name_usage))
                   || lpad(' ', 250 - length(tree.name_usage))
                   || substr(tree.name_usage, 1, 250 - mod(2 * (tree.path_len - 1), 250))
             end
             as varchar2(250 char)
          ) as name_usage,
          tree.name,
          tree.name_path,
          tree.path_len,
          tree.module_name,
          tree.type,
          case
             -- make SQL_ID and SQL_STMT pseudo-usages appear as EXECUTE
             when tree.usage in ('SQL_ID', 'SQL_STMT') then
                'EXECUTE'
             else
                tree.usage
          end as usage,
          refs.owner as ref_owner,                 -- decl_owner
          refs.object_type as ref_object_type,     -- decl_object_type
          refs.object_name as ref_object_name,     -- decl_object_name
          regexp_replace(src.text, chr(10) || '+$', null) as text,  -- remove trailing new line character
          tree.parent_statement_type,
          tree.parent_statement_signature,
          tree.parent_statement_path_len,
          case
             -- wrong result, if used in statements which do not register usage, 
             -- such as a variable for dynamic_sql_stmt in EXECUTE IMMEDIATE.
             -- Bug 26351814.
             when tree.object_type in ('PACKAGE BODY', 'PROCEDURE', 'FUNCTION', 'TYPE BODY')
                and tree.usage = 'DECLARATION'
                and tree.type not in ('LABEL')
             then
                case
                   when count(
                         case
                            when tree.usage not in ('DECLARATION', 'ASSIGNMENT')
                               or (tree.type in ('FORMAL OUT', 'FORMAL IN OUT')
                                  and tree.usage = 'ASSIGNMENT')
                            then
                               1
                         end
                      ) over (
                         partition by tree.owner, tree.object_name, tree.object_type, tree.signature
                      ) = 0
                   then
                      'NO'
                   else
                      'YES'
                end
          end as is_used,
          tree.signature,
          tree.usage_id,
          tree.usage_context_id,
          tree.is_fixed_context_id,
          tree.procedure_signature,
          --tree.is_def_child_of_decl,    --uncomment if needed for debugging
          --tree.is_new_proc,             --uncomment if needed for debugging
          case
             when tree.is_new_proc = 'YES' then
                coalesce(
                   first_value(
                      case
                         when tree.is_new_proc = 'YES'
                            or tree.usage_context_id = 1
                         then
                            tree.line
                      end
                   ) ignore nulls over (
                      partition by tree.owner, tree.object_type, tree.object_name
                      order by tree.usage_id
                      rows between 1 following and unbounded following
                   ),
                   max(tree.line) over (
                         partition by tree.owner, tree.object_type, tree.object_name
                   ) + 1
                )
          end as proc_ends_before_line,
          case
             when tree.is_new_proc = 'YES' then
                nvl(
                   first_value(
                      case
                         when tree.is_new_proc = 'YES'
                            or tree.usage_context_id = 1
                         then
                            tree.col
                      end
                   ) ignore nulls over (
                      partition by tree.owner, tree.object_type, tree.object_name
                      order by tree.usage_id
                      rows between 1 following and unbounded following
                   ),
                   1
                )
          end as proc_ends_before_col,
          refs.line as ref_line,         -- decl_line
          refs.col as ref_col,           -- decl_col
          tree.origin_con_id
     from tree_plus tree
     left join sys.dba_identifiers refs -- must not use pls_ids to consider all identifiers, NOSONAR: G-8210
       on refs.signature = tree.signature
      and refs.usage = 'DECLARATION'
     left join src
       on src.owner = tree.owner
      and src.type = tree.object_type
      and src.name = tree.object_name
      and src.line = tree.line;
