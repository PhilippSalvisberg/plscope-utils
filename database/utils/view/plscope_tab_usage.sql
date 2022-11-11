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

create or replace view plscope_tab_usage as
   with
      table_usage_ids as (
         select /*+ materialize */
                ids.owner,
                ids.object_type,
                ids.object_name,
                ids.procedure_name,
                ids.usage,
                ids.line,
                ids.col,
                ids.ref_owner,
                ids.ref_object_type,
                ids.ref_object_name,
                ids.parent_statement_signature,
                ids.text
           from plscope_identifiers ids
          where ids.type in ('VIEW', 'TABLE', 'SYNONYM')
      ),
      -- direct and indirect dependencies; path_len = 0 for direct dependencies, 
      -- otherwise the length of the dependency chain, i.e. level - 1; cycles are
      -- possible here (with help from synonyms) so we need to detect them 
      dep_chains (
         owner,
         type,
         name,
         ref_owner,
         ref_type,
         ref_name,
         path_len
      ) as (
         -- direct dependencies
         select distinct
                ids.ref_owner,
                ids.ref_object_type,
                ids.ref_object_name,
                ids.ref_owner,
                ids.ref_object_type,
                ids.ref_object_name,
                0
           from table_usage_ids ids
          where ids.ref_object_type in ('VIEW', 'TABLE', 'SYNONYM')
          union all
         -- indirect dependencies
         select /*+ no_merge(dep) */ 
                par.owner,
                par.type,
                par.name,
                dep.referenced_owner,
                dep.referenced_type,
                dep.referenced_name,
                par.path_len + 1
           from dep_chains par
           join sys.dba_dependencies dep  -- NOSONAR: avoid public synonym
             on par.ref_owner = dep.owner
            and par.ref_type = dep.type
            and par.ref_name = dep.name
            and dep.referenced_type in (  -- list of referenced types of interest
                   'VIEW', 
                   'TABLE', 
                   'SYNONYM',
                   'MATERIALIZED VIEW'    -- does MATERIALIZED VIEW belong here?
                )
      )
      cycle ref_owner, ref_type, ref_name set is_cycle to 'Y' default 'N',
      -- eliminate duplicate dependencies, keeping the minimum path_len; add the 
      -- base_object_type column, which is the type of the first object (if any)
      -- which is not a synonym, in case we're going down a chain of synonyms;
      -- the is_base_object flag is set to 'YES' for that object, otherwise null
      dep_trans_closure as (
         select owner,
                type,
                name,
                ref_owner,
                ref_type,
                ref_name,
                min(path_len)  as path_len,
                nullif(                            -- @formatter:off
                   min(ref_type)
                   keep (
                      dense_rank first
                      order by 
                         case
                            when ref_type = 'SYNONYM' then
                               null
                            else
                               min(path_len)
                         end asc nulls last,
                         min(path_len)
                   )
                   over (
                      partition by owner, type, name
                   ),
                   'SYNONYM'
                )  as base_obj_type,               -- @formatter:on
                case                               -- @formatter:off
                   -- remark: disregarding the case when there are only SYNONYMs in the 
                   -- dependency chain: such chains are filtered out in the main query
                   when min(path_len) = min(min(path_len))
                         keep (
                            dense_rank first
                            order by 
                               case
                                  when ref_type = 'SYNONYM' then
                                     null
                                  else
                                     min(path_len)
                               end asc nulls last,
                               min(path_len)
                         )
                         over (
                            partition by owner, type, name
                         ) 
                   then
                      cast('YES' as varchar2(3 char))
                end  as is_base_object             -- @formatter:on
           from dep_chains
          group by owner,
                type,
                name,
                ref_owner,
                ref_type,
                ref_name
      )
      select ids.owner,
             ids.object_type,
             ids.object_name,
             ids.line,
             ids.col,
             ids.procedure_name,
             case
                when refs.type is not null then
                   refs.type
                else
                   ids.usage
             end as operation,
             dep.ref_owner,
             dep.ref_type  as ref_object_type,
             dep.ref_name  as ref_object_name,
             case
                when dep.path_len = 0 then
                   'YES'
                else
                   'NO'
             end as direct_dependency,
             ids.text,
             dep.is_base_object,
             dep.path_len
        from table_usage_ids ids
        join dep_trans_closure dep
          on dep.owner = ids.ref_owner
         and dep.type = ids.ref_object_type
         and dep.name = ids.ref_object_name
         and (dep.ref_type <> 'SYNONYM'     -- ignore synonyms unless directly referenced
                or dep.path_len = 0)
         and dep.base_obj_type is not null  -- drop syn. refs not leading to tables/views
        left join sys.dba_statements refs   -- NOSONAR: avoid public synonym
          on refs.signature = ids.parent_statement_signature;
