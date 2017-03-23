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

CREATE OR REPLACE VIEW plscope_identifiers AS
WITH 
   ids AS (
      SELECT owner,
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
        FROM dba_identifiers
      UNION ALL
      SELECT owner, 
             NVL(sql_id, type) AS name, 
             signature, 
             type, 
             object_name, 
             object_type, 
             'EXECUTE' AS usage, -- new, artificial usage
             usage_id, 
             line, 
             col, 
             usage_context_id,
             origin_con_id            
        FROM dba_statements
   )
 SELECT ids.owner,
        ids.object_type,
        ids.object_name, 
        ids.line, 
        ids.col, 
        last_value (
           CASE 
              WHEN ids.object_type = 'PACKAGE BODY'
                   AND ids.type in ('PROCEDURE', 'FUNCTION')
                   AND level = 2 THEN
                 ids.name 
           END
        ) IGNORE NULLS OVER (
           PARTITION BY ids.owner, ids.object_name, ids.object_type 
           ORDER BY ids.line, ids.col, level
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS procedure_name,
        last_value (
           CASE 
              WHEN ids.object_type = 'PACKAGE BODY'
                   AND ids.type in ('PROCEDURE', 'FUNCTION')
                   AND level = 2 THEN
                 CASE ids.usage
                    WHEN 'DECLARATION' THEN
                       'PRIVATE'
                    WHEN 'DEFINITION' THEN
                       'PUBLIC'
                 END
           END
        ) IGNORE NULLS OVER (
           PARTITION BY ids.owner, ids.object_name, ids.object_type 
           ORDER BY ids.line, ids.col, level
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS procedure_scope,       
        ids.name,
        sys_connect_by_path(ids.name, '/') AS name_path,
        level as path_len,
        ids.type,
        ids.usage,
        CASE 
           WHEN ids.object_type IN ('PACKAGE BODY', 'PROCEDURE', 'FUNCTION', 'TYPE BODY')
                AND ids.type IN ('VARIABLE', 'CONSTANT', 'CURSOR')
                AND ids.usage = 'DECLARATION'
           THEN
              CASE
                 WHEN 
                    count(
                       CASE 
                          WHEN ids.usage NOT IN ('DECLARATION', 'ASSIGNMENT') THEN 
                             1 
                       END
                    ) OVER (
                       PARTITION BY ids.owner, ids.object_name, ids.object_type, ids.signature
                    ) = 0
                 THEN
                    'NO'
                 ELSE
                    'YES'
              END
        END AS is_used, -- wrong result if hierarchy is incomplete, e.g. variable used in function not compiled with PL/Scope
        refs.owner AS ref_owner,
        refs.object_type AS ref_object_type,
        refs.object_name AS ref_object_name,
        ids.signature, 
        ids.usage_id, 
        ids.usage_context_id,
        ids.origin_con_id
   FROM ids
   LEFT JOIN dba_identifiers refs 
     ON refs.signature = ids.signature
        AND refs.usage = 'DECLARATION'
  START WITH ids.usage_context_id = 0
CONNECT BY  PRIOR ids.usage_id    = ids.usage_context_id
        AND PRIOR ids.owner       = ids.owner
        AND PRIOR ids.object_type = ids.object_type
        AND PRIOR ids.object_name = ids.object_name;
