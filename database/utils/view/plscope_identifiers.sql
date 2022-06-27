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
      src as (
         select /*+ materialize */
                owner,
                type,
                name,
                line,
                text
           from dba_source
          where owner like nvl(sys_context('PLSCOPE', 'OWNER'), user)
            and type like nvl(sys_context('PLSCOPE', 'OBJECT_TYPE'), '%')
            and name like nvl(sys_context('PLSCOPE', 'OBJECT_NAME'), '%')
            and origin_con_id = sys_context('USERENV', 'CON_ID')
      ),
      pls_ids as (
         select owner,
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
           from dba_identifiers
          where owner like nvl(sys_context('PLSCOPE', 'OWNER'), user)
            and object_type like nvl(sys_context('PLSCOPE', 'OBJECT_TYPE'), '%')
            and object_name like nvl(sys_context('PLSCOPE', 'OBJECT_NAME'), '%')
            and origin_con_id = sys_context('USERENV', 'CON_ID')
      ),
      sql_ids as (
         select owner,
                nvl(sql_id, type)  as name,
                signature,
                type,
                object_name,
                object_type,
                'SQL_STMT'  as usage, -- new, artificial usage
                usage_id,
                line,
                col,
                usage_context_id,
                origin_con_id
           from dba_statements
          where owner like nvl(sys_context('PLSCOPE', 'OWNER'), user)
            and object_type like nvl(sys_context('PLSCOPE', 'OBJECT_TYPE'), '%')
            and object_name like nvl(sys_context('PLSCOPE', 'OBJECT_NAME'), '%')
            and origin_con_id = sys_context('USERENV', 'CON_ID')
      ),
      fids as (
         select 'NO'                               as is_sql_stmt,
                a.owner,
                a.name,
                a.signature,
                a.type,
                a.object_name,
                a.object_type,
                a.usage,
                a.usage_id,
                a.line,
                a.col,
                a.usage_context_id,
                nvl2(b.signature, 'PUBLIC', null)  as procedure_scope,
                a.origin_con_id
           from pls_ids a,
                dba_identifiers b
          where b.owner (+)         = a.owner
            and b.object_type (+)   = 'PACKAGE'
            and b.object_name (+)   = a.object_name
            and b.usage (+)         = 'DECLARATION'
            and b.signature (+)     = a.signature
            and b.origin_con_id (+) = a.origin_con_id
         union all
         select 'YES'                              as is_sql_stmt,
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
                null                               as procedure_scope,
                origin_con_id
           from sql_ids
      ),
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
           from fids,
                fids parent
          where parent.owner (+)       = fids.owner
            and parent.object_type (+) = fids.object_type
            and parent.object_name (+) = fids.object_name
            and parent.usage_id (+)    = fids.usage_context_id
      ),
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
                         order by line, col
                         rows between unbounded preceding and 1 preceding
                      )
                end  as usage_context_id,        -- fix broken hierarchies
                case
                   when sane_fk = 'NO' then
                      'YES'
                end  as is_fixed_context_id,     -- indicator of fixed hierarchies
                procedure_scope,
                origin_con_id
           from base_ids
      ),
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
                end                          as procedure_name,
                case
                   when object_type in ('PROCEDURE', 'FUNCTION') then
                      'PUBLIC'
                end                          as procedure_scope,
                name,
                '/' || name                  as name_path,
                1                            as path_len,
                type,
                usage,
                signature,
                usage_id,
                usage_context_id,
                is_fixed_context_id,
                case
                   when object_type in ('PROCEDURE', 'FUNCTION') then
                      signature
                end                          as procedure_signature,
                is_sql_stmt,
                cast(null as varchar2(18))   as parent_statement_type,
                cast(null as varchar2(32))   as parent_statement_signature,
                cast(null as number)         as parent_statement_path_len,
                origin_con_id
           from ids
          where usage_context_id = 0  -- top-level identifiers
         union all
         select b.owner,
                b.object_type,
                b.object_name,
                b.line,
                b.col,
                case
                   when a.procedure_name is not null then
                      a.procedure_name
                   when b.object_type in ('PACKAGE', 'PACKAGE BODY')
                      and b.type in ('FUNCTION', 'PROCEDURE')
                      and b.usage in ('DEFINITION', 'DECLARATION')
                      and b.usage_context_id = 1
                   then
                      b.name
                end                             as procedure_name,
                case
                   when a.procedure_scope is not null then
                      a.procedure_scope
                   when b.object_type = 'PACKAGE'
                      and b.type in ('FUNCTION', 'PROCEDURE')
                      and b.usage = 'DECLARATION'
                      and b.usage_context_id = 1
                   then
                      'PUBLIC'
                   when b.object_type = 'PACKAGE BODY'
                      and b.type in ('FUNCTION', 'PROCEDURE')
                      and b.usage in ('DEFINITION', 'DECLARATION')
                      and b.usage_context_id = 1
                   then
                      decode(b.procedure_scope,
                           'PUBLIC', 'PUBLIC',
                           'PRIVATE')
                end                             as procedure_scope,
                b.name,
                a.name_path || '/' || b.name    as name_path,
                a.path_len + 1                  as path_len,
                b.type,
                b.usage,
                b.signature,
                b.usage_id,
                b.usage_context_id,
                b.is_fixed_context_id,
                case
                   when a.procedure_signature is not null then
                      a.procedure_signature
                   when b.object_type in ('PACKAGE', 'PACKAGE BODY')
                      and b.type in ('FUNCTION', 'PROCEDURE')
                      and b.usage in ('DEFINITION', 'DECLARATION')
                      and b.usage_context_id = 1
                   then
                      b.signature
                end                             as procedure_signature,
                b.is_sql_stmt,
                case
                   when a.is_sql_stmt = 'YES' then
                      a.type
                   else
                      a.parent_statement_type
                end                             as parent_statement_type,
                case
                   when a.is_sql_stmt = 'YES' then
                      a.signature
                   else
                      a.parent_statement_signature
                end                             as parent_statement_signature,
                case
                   when a.is_sql_stmt = 'YES' then
                      a.path_len
                   else
                      a.parent_statement_path_len
                end                             as parent_statement_path_len,
                b.origin_con_id
           from tree a,
                ids b
          where a.owner       = b.owner
            and a.object_type = b.object_type
            and a.object_name = b.object_name
            and a.usage_id    = b.usage_context_id
      )
   select tree.owner,
          tree.object_type,
          tree.object_name,
          tree.line,
          tree.col,
          tree.procedure_name,
          tree.procedure_scope,
          lpad(' ', 2 * (tree.path_len - 1))
                || case
                      when tree.usage = 'SQL_STMT' then
                         tree.type || ' statement (sql_id: ' || tree.name || ')'
                      else
                         tree.name || ' (' || lower(tree.type) || ' ' || lower(tree.usage) || ')'
                   end                    as name_usage,
          tree.name,
          tree.name_path,
          tree.path_len,
          tree.type,
          tree.usage,
          refs.owner                      as ref_owner,           -- decl_owner
          refs.object_type                as ref_object_type,     -- decl_object_type
          refs.object_name                as ref_object_name,     -- decl_object_name
          regexp_replace(src.text, chr(10) 
               || '+$', null)             as text,  -- remove trailing new line character
          tree.parent_statement_type,
          tree.parent_statement_signature,
          tree.parent_statement_path_len,
          case
             -- wrong result, if used in statements which do not register usage, 
             -- such as a variable for dynamic_sql_stmt in EXECUTE IMMEDIATE.
             -- Bug 26351814.
             --
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
          end                             as is_used,
          tree.signature,
          tree.usage_id,
          tree.usage_context_id,
          tree.is_fixed_context_id,
          tree.procedure_signature,
          refs.line                       as ref_line,         -- decl_line
          refs.col                        as ref_col,          -- decl_col
          tree.origin_con_id
     from tree,
          dba_identifiers refs,
          src
    where refs.signature (+) = tree.signature
      and refs.usage (+)     = 'DECLARATION'
      and src.owner (+)      = tree.owner
      and src.type (+)       = tree.object_type
      and src.name (+)       = tree.object_name
      and src.line (+)       = tree.line;