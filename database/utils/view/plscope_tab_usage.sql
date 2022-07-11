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
      dep as (
         select owner as owner,
                'TABLE' as type,
                table_name as name,
                null as referenced_owner,
                null as referenced_type,
                null as referenced_name
           from dba_tables
         union all
         select owner,
                type,
                name,
                referenced_owner,
                referenced_type,
                referenced_name
           from dba_dependencies
          where type in ('VIEW', 'MATERIALIZED VIEW', 'SYNONYM')
      ),
      -- recursive with clause to calculate ref_object_type_path
      dep_graph_base (
         owner,
         object_type,
         object_name,
         ref_owner,
         ref_object_type,
         ref_object_name,
         ref_object_type_path,
         path_len
      ) as (
         select owner,
                type,
                name,
                owner as ref_owner,
                type as ref_object_type,
                name as ref_object_name,
                '/' || type as ref_object_type_path,
                1 as path_len
           from dep
         union all
         select dep.owner,
                dep.type,
                dep.name,
                dep_graph_base.ref_owner,
                dep_graph_base.ref_object_type,
                dep_graph_base.ref_object_name,
                case
                   when lengthb(dep_graph_base.ref_object_type_path) + lengthb('/') + lengthb(dep.type) <= 4000 then
                      dep_graph_base.ref_object_type_path
                      || '/'
                      || dep.type
                   else
                      -- prevent ref_object_type_path from overflowing: keep the first 3 elements, then
                      -- remove enough elements to accomodate "..." + "/" + the tail end
                      regexp_substr(dep_graph_base.ref_object_type_path, '^(/([^/]+/){3})')
                      || '...'
                      || regexp_replace(
                         substr(dep_graph_base.ref_object_type_path, instr(dep_graph_base.ref_object_type_path, '/', 1, 4) + 1
                            + lengthb('.../') + lengthb(dep.type)),
                         '^[^/]*')
                      || '/'
                      || dep.type
                end as ref_object_type_path,
                dep_graph_base.path_len + 1 as path_len
           from dep_graph_base
           join dep
             on dep_graph_base.owner = dep.referenced_owner
            and dep_graph_base.object_type = dep.referenced_type
            and dep_graph_base.object_name = dep.referenced_name
      ) cycle owner, object_type, object_name set is_cycle to 'Y' default 'N',
      -- remove duplicate rows
      dep_graph as (
         select distinct
                owner,
                object_type,
                object_name,
                ref_owner,
                ref_object_type,
                ref_object_name,
                ref_object_type_path,
                path_len
           from dep_graph_base
      ),
      tab_usage as (
         select /*+use_hash(ids) use_hash(dep_graph) use_hash(refs)*/
                ids.owner,
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
                dep_graph.ref_owner,
                dep_graph.ref_object_type,
                dep_graph.ref_object_name,
                case
                   when dep_graph.path_len = 1 then
                      'YES'
                   else
                      'NO'
                end as direct_dependency,
                dep_graph.ref_object_type_path,
                lead(dep_graph.ref_object_type_path) over (
                   order by ids.owner, ids.object_type, ids.object_name, ids.line, ids.col, dep_graph.path_len
                ) as next_ref_object_type_path,
                ids.text
           from plscope_identifiers ids
           join dep_graph
             on dep_graph.owner = ids.ref_owner
            and dep_graph.object_type = ids.ref_object_type
            and dep_graph.object_name = ids.ref_object_name
           left join dba_statements refs
             on refs.signature = parent_statement_signature
          where ids.type in ('VIEW', 'TABLE', 'SYNONYM')
      )
   select owner,
          object_type,
          object_name,
          line,
          col,
          procedure_name,
          operation,
          ref_owner,
          ref_object_type,
          ref_object_name,
          direct_dependency,
          text
     from tab_usage
    where (ref_object_type != 'SYNONYM' or next_ref_object_type_path in ('/VIEW/SYNONYM', '/TABLE/SYNONYM'));
