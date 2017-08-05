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

CREATE OR REPLACE VIEW plscope_col_usage AS
WITH
   scope_cols AS (
      SELECT ids.owner,
             ids.object_type,
             ids.object_name,
             ids.line,
             ids.col,
             ids.procedure_name,
             CASE
                WHEN refs.type IS NOT NULL THEN
                   refs.type
                ELSE
                   ids.usage
             END AS operation,
             ids.ref_owner,
             ids.ref_object_type,
             ids.ref_object_name,
             ids.name as column_name,
             ids.text
        FROM plscope_identifiers ids
        LEFT JOIN dba_statements refs
          ON refs.signature = parent_statement_signature
       WHERE ids.type = 'COLUMN'
         AND ids.usage != 'DECLARATION'
   ),
   missing_cols AS (
      SELECT t.owner,
             t.object_type,
             t.object_name,
             t.line,
             t.col,
             t.procedure_name,
             t.operation,
             coalesce(o.owner, t.ref_owner) AS ref_owner,
             coalesce(o.object_type, t.ref_object_type) AS ref_object_type,
             coalesce(o.object_name, t.ref_object_name) AS ref_object_name,
             tc.column_name,
             t.text
        FROM plscope_tab_usage t
        LEFT JOIN dba_synonyms s
          ON s.owner            = t.ref_owner
             AND s.synonym_name = t.ref_object_name
        LEFT JOIN dba_objects o
          ON o.owner            = s.table_owner
            AND o.object_name   = s.table_name
        LEFT JOIN scope_cols c
          ON t.owner                                        = c.owner
             AND t.object_type                              = c.object_type
             AND t.object_name                              = c.object_name
             AND t.procedure_name                           = c.procedure_name
             AND coalesce(o.owner, t.ref_owner)             = c.ref_owner
             AND coalesce(o.object_type, t.ref_object_type) = c.ref_object_type
             AND coalesce(o.object_name, t.ref_object_name) = c.ref_object_name
        JOIN dba_tab_columns tc
          ON tc.owner = t.owner
             AND tc.table_name = coalesce(o.object_name,t.ref_object_name)
       WHERE t.direct_dependency = 'YES'
         AND c.owner IS NULL
         AND t.operation IN ('INSERT', 'SELECT')
   ),
   base_cols AS (
      SELECT owner,
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
             'YES' AS direct_dependency,
             text
        FROM scope_cols
      UNION ALL
      SELECT owner,
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
             'NO' AS direct_dependency,
             text
        FROM missing_cols
   )
SELECT owner,
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
  FROM base_cols
UNION ALL
SELECT c.owner,
       c.object_type,
       c.object_name,
       c.line,
       c.col,
       c.procedure_name,
       c.operation,
       d.owner       AS ref_owner,
       d.object_type AS ref_object_type,
       d.object_name AS ref_object_name,
       d.column_name,
       'NO' AS direct_dependency,
       c.text
  FROM base_cols c,
       TABLE(
          lineage_util.get_dep_cols_from_view(
             in_owner       => c.ref_owner,
             in_object_name => c.ref_object_name,
             in_column_name => c.column_name,
             in_recursive   => 1
          )
       ) d
 WHERE c.ref_object_type = 'VIEW';
