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
      ),
      prep_ids as (
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
         union all
         select owner,
                ':' || nvl(sql_id, type) as name,  -- intermediate statement marker colon
                signature,
                type,
                object_name,
                object_type,
                'EXECUTE' as usage, -- new, artificial usage
                usage_id,
                line,
                col,
                usage_context_id,
                origin_con_id
           from dba_statements
      ),
      fids as (
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
           from prep_ids
          where owner like nvl(sys_context('PLSCOPE', 'OWNER'), user)
            and object_type like nvl(sys_context('PLSCOPE', 'OBJECT_TYPE'), '%')
            and object_name like nvl(sys_context('PLSCOPE', 'OBJECT_NAME'), '%')
      ),
      base_ids as (
         select fids.owner,
                fids.name,
                fids.signature,
                fids.type,
                fids.object_name,
                fids.object_type,
                fids.usage,
                fids.usage_id,
                case
                   when fk.usage_id is not null
                      or fids.usage_context_id = 0
                   then
                      'YES'
                   else
                      'NO'
                end as sane_fk,
                fids.line,
                fids.col,
                fids.usage_context_id,
                fids.origin_con_id
           from fids
           left join fids fk
             on fk.owner = fids.owner
            and fk.object_type = fids.object_type
            and fk.object_name = fids.object_name
            and fk.usage_id = fids.usage_context_id
      ),
      ids as (
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
                end as usage_context_id, -- fix broken hierarchies
                origin_con_id
           from base_ids
      ),
      tree as (
         select ids.owner,
                ids.object_type,
                ids.object_name,
                ids.line,
                ids.col,
                ids.name,
                replace(sys_connect_by_path(ids.name, '|'), '|', '/') as name_path,
                level as path_len,
                ids.type,
                ids.usage,
                ids.signature,
                ids.usage_id,
                ids.usage_context_id,
                ids.origin_con_id
           from ids
          start with ids.usage_context_id = 0
        connect by prior ids.usage_id = ids.usage_context_id
            and prior ids.owner = ids.owner
            and prior ids.object_type = ids.object_type
            and prior ids.object_name = ids.object_name
      )
   select /*+use_hash(tree) use_hash(refs) */
          tree.owner,
          tree.object_type,
          tree.object_name,
          tree.line,
          tree.col,
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
          last_value (
             case
                when tree.object_type = 'PACKAGE BODY'
                   and tree.type in ('PROCEDURE', 'FUNCTION')
                   and tree.path_len = 2
                then
                   case tree.usage
                      when 'DECLARATION' then
                         'PRIVATE'
                      when 'DEFINITION' then
                         'PUBLIC'
                   end
             end
          ) ignore nulls over (
             partition by tree.owner, tree.object_name, tree.object_type
             order by tree.line, tree.col, tree.path_len
          ) as procedure_scope,
          replace(tree.name, ':', null) as name, -- remove intermediate statement marker
          replace(tree.name_path, ':', null) as name_path, -- remove intermediate statement marker
          tree.path_len,
          tree.type,
          tree.usage,
          refs.owner as ref_owner,
          refs.object_type as ref_object_type,
          refs.object_name as ref_object_name,
          regexp_replace(src.text, chr(10) || '+$', null) as text, -- remove trailing new line character
          case
             when tree.name_path like '%:%'
                and tree.usage != 'EXECUTE'
             then
                -- ensure that this is really a child of a statement
                last_value (
                   case
                      when tree.usage = 'EXECUTE' then
                         tree.type
                   end
                ) ignore nulls over (
                   partition by tree.owner, tree.object_name, tree.object_type
                   order by tree.line, tree.col, tree.path_len
                )
          end as parent_statement_type,
          case
             when tree.name_path like '%:%'
                and tree.usage != 'EXECUTE'
             then
                -- ensure that this is really a child of a statement
                last_value (
                   case
                      when tree.usage = 'EXECUTE' then
                         tree.signature
                   end
                ) ignore nulls over (
                   partition by tree.owner, tree.object_name, tree.object_type
                   order by tree.line, tree.col, tree.path_len
                )
          end as parent_statement_signature,
          case
             when tree.name_path like '%:%'
                and tree.usage != 'EXECUTE'
             then
                -- ensure that this is really a child of a statement
                last_value (
                   case
                      when tree.usage = 'EXECUTE' then
                         tree.path_len
                   end
                ) ignore nulls over (
                   partition by tree.owner, tree.object_name, tree.object_type
                   order by tree.line, tree.col, tree.path_len
                )
          end as parent_statement_path_len,
          case
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
          end as is_used, -- wrong result, if used in statements which do not register usage, such as a variable for dynamic_sql_stmt in EXECUTE IMMEDIATE. Bug 26351814.
          tree.signature,
          tree.usage_id,
          tree.usage_context_id,
          tree.origin_con_id
     from tree
     left join dba_identifiers refs
       on refs.signature = tree.signature
      and refs.usage = 'DECLARATION'
     left join src
       on src.owner = tree.owner
      and src.type = tree.object_type
      and src.name = tree.object_name
      and src.line = tree.line;
