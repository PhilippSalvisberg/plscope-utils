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
      dep_graph as (
         select /*+materialize */
       distinct
                owner,
                type as object_type,
                name as object_name,
                connect_by_root(owner) as ref_owner,
                connect_by_root(type) as ref_object_type,
                connect_by_root(name) as ref_object_name,
                sys_connect_by_path(type, '/') as ref_object_type_path,
                level as path_len
           from dep
        connect by prior dep.owner = dep.referenced_owner
            and prior dep.type = dep.referenced_type
            and prior dep.name = dep.referenced_name
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
