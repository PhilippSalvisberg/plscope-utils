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
   cols AS (
      SELECT ids.owner,
             ids.object_type,
             ids.object_name,
             ids.line,
             ids.col,
             ids.procedure_name,
             CASE 
                WHEN refs.usage = 'EXECUTE' THEN
                   refs.type
             END AS operation,
             ids.ref_owner,
             ids.ref_object_type,
             ids.ref_object_name,
             ids.name as column_name
        FROM plscope_identifiers ids
        JOIN plscope_identifiers refs
          ON refs.usage_id = ids.usage_context_id
             AND refs.owner = ids.owner
             AND refs.object_type = ids.object_type
             AND refs.object_name = ids.object_name
       WHERE ids.type = 'COLUMN'
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
             tc.column_name
        FROM plscope_tab_usage t
        LEFT JOIN dba_synonyms s
          ON s.owner            = t.ref_owner 
             AND s.synonym_name = t.ref_object_name
        LEFT JOIN dba_objects o 
          ON o.owner            = s.table_owner 
            AND o.object_name   = s.table_name
        LEFT JOIN cols c
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
       WHERE direct_dependency = 'YES' 
         AND c.owner IS NULL
         AND t.operation IN ('INSERT', 'SELECT')
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
       'YES' AS direct_dependency
  FROM cols
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
       'NO' AS direct_dependency
  FROM missing_cols
ORDER BY 1, 2, 3, 4, 5, 8, 9, 10, 11;
