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
           left join sys.dba_statements refs -- NOSONAR: avoid public synonym
             on refs.signature = parent_statement_signature
          where ids.type = 'COLUMN'
            and ids.usage != 'DECLARATION'
      ),
      missing_cols as (
         select t.owner,
                t.object_type,
                t.object_name,
                t.line,
                t.col,
                t.procedure_name,
                t.operation,
                t.ref_owner,
                t.ref_object_type,
                t.ref_object_name,
                tc.column_name,
                t.text
           from ( select tu.owner,
                         tu.object_type,
                         tu.object_name,
                         tu.line,
                         tu.col,
                         tu.procedure_name,
                         tu.operation,
                         tu.ref_owner,
                         tu.ref_object_type,
                         tu.ref_object_name,
                         tu.text
                    from plscope_tab_usage tu
                    left join sys.dba_tables tab -- NOSONAR: avoid public synonyms
                      on tu.ref_object_type = 'TABLE'
                     and tab.owner = tu.ref_owner
                     and tab.table_name = tu.ref_object_name
                   where tu.is_base_object = 'YES'
                     and tu.operation in ('INSERT', 'SELECT')
                      -- PL/Scope records references to "columns" of object tables, not as
                      -- column references, but as object attribute references instead.
                      -- The scope_cols subquery cannot handle that, so we must exclude
                      -- object tables here too.
                     and not (tu.ref_object_type = 'TABLE' and tab.owner is null)
                ) t
           left join scope_cols c
             on t.owner = c.owner
            and t.object_type = c.object_type
            and t.object_name = c.object_name
            and t.procedure_name = c.procedure_name
            and t.ref_owner = c.ref_owner
            and t.ref_object_type = c.ref_object_type
            and t.ref_object_name = c.ref_object_name
           join sys.dba_tab_columns tc -- NOSONAR: avoid public synonym
             on tc.owner = t.ref_owner
            and tc.table_name = t.ref_object_name
          where c.owner is null
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
