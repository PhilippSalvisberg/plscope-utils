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

create or replace view plscope_col_usage as
   with
      scope_cols as (
         select /*+use_hash(ids) use_hash(refs) */
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
                ids.ref_owner,
                ids.ref_object_type,
                ids.ref_object_name,
                ids.name as column_name,
                ids.text
           from plscope_identifiers ids
           left join dba_statements refs
             on refs.signature = parent_statement_signature
          where ids.type = 'COLUMN'
            and ids.usage != 'DECLARATION'
      ),
      missing_cols as (
         select /*+use_hash(t) use_hash(s) use_hash(o) use_hash(c) use_hash(tc) */
                t.owner,
                t.object_type,
                t.object_name,
                t.line,
                t.col,
                t.procedure_name,
                t.operation,
                coalesce(o.owner, t.ref_owner) as ref_owner,
                coalesce(o.object_type, t.ref_object_type) as ref_object_type,
                coalesce(o.object_name, t.ref_object_name) as ref_object_name,
                tc.column_name,
                t.text
           from plscope_tab_usage t
           left join dba_synonyms s
             on s.owner = t.ref_owner
            and s.synonym_name = t.ref_object_name
           left join dba_objects o
             on o.owner = s.table_owner
            and o.object_name = s.table_name
           left join scope_cols c
             on t.owner = c.owner
            and t.object_type = c.object_type
            and t.object_name = c.object_name
            and t.procedure_name = c.procedure_name
            and coalesce(o.owner, t.ref_owner) = c.ref_owner
            and coalesce(o.object_type, t.ref_object_type) = c.ref_object_type
            and coalesce(o.object_name, t.ref_object_name) = c.ref_object_name
           join dba_tab_columns tc
             on tc.owner = t.owner
            and tc.table_name = coalesce(o.object_name, t.ref_object_name)
          where t.direct_dependency = 'YES'
            and c.owner is null
            and t.operation in ('INSERT', 'SELECT')
      ),
      base_cols as (
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
                column_name,
                'YES' as direct_dependency,
                text
           from scope_cols
         union all
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
                column_name,
                'NO' as direct_dependency,
                text
           from missing_cols
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
          column_name,
          direct_dependency,
          text
     from base_cols
   union all
   select c.owner,
          c.object_type,
          c.object_name,
          c.line,
          c.col,
          c.procedure_name,
          c.operation,
          d.owner as ref_owner,
          d.object_type as ref_object_type,
          d.object_name as ref_object_name,
          d.column_name,
          'NO' as direct_dependency,
          c.text
     from base_cols c
    cross join table(
             lineage_util.get_dep_cols_from_view(
                in_owner       => c.ref_owner,
                in_object_name => c.ref_object_name,
                in_column_name => c.column_name,
                in_recursive   => 1
             )
          ) d
    where c.ref_object_type = 'VIEW';
