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

CREATE OR REPLACE VIEW plscope_identifiers2 AS
WITH 
   base_ids AS (
      SELECT owner,
             name, 
             signature, 
             type, 
             object_name, 
             object_type, 
             usage, 
             usage_id,
             max(usage_id) OVER (PARTITION BY owner, object_type, object_name) AS max_usage_id,
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
             NULL AS max_usage_id,
             line, 
             col, 
             usage_context_id,
             origin_con_id            
        FROM dba_statements
   ),
   gen AS (
      SELECT ROWNUM as row_num
        FROM XMLTABLE('1 to 100000')
   ),
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
        FROM base_ids
      UNION ALL
      SELECT b1.owner,
             'SOMETHING' AS name, 
             NULL AS signature, 
             'SOMETHING' AS type, 
             b1.object_name, 
             b1.object_type, 
             'MISSING' AS usage, 
             gen.row_num AS usage_id, 
             NULL AS line, 
             NULL AS col, 
             gen.row_num - 1 AS usage_context_id,
             b1.origin_con_id
        FROM base_ids b1
        JOIN gen
          ON gen.row_num < b1.max_usage_id 
        LEFT JOIN base_ids b2
          ON b2.owner = b1.owner
             AND b2.object_type = b1.object_type
             AND b2.object_name = b1.object_name
             AND b2.usage_id = gen.row_num
       WHERE b1.usage_context_id = 0
         AND b2.owner IS NULL
   )
 SELECT ids.owner,
        ids.object_type,
        ids.object_name,
        to_number(replace(regexp_substr(sys_connect_by_path(ids.line, '/'),'(\d+)/*$'),'/')) AS line,
        to_number(replace(regexp_substr(sys_connect_by_path(ids.col, '/'),'(\d+)/*$'),'/')) AS col,
        last_value (
           CASE 
              WHEN ids.object_type = 'PACKAGE BODY'
                   AND ids.type in ('PROCEDURE', 'FUNCTION')
                   AND level = 2 
              THEN
                 ids.name 
           END
        ) IGNORE NULLS OVER (
           PARTITION BY ids.owner, ids.object_name, ids.object_type 
           ORDER BY to_number(replace(regexp_substr(sys_connect_by_path(ids.line, '/'),'(\d+)/*$'),'/')), 
                    to_number(replace(regexp_substr(sys_connect_by_path(ids.col, '/'),'(\d+)/*$'),'/')), 
                    level
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS procedure_name,
        last_value (
           CASE 
              WHEN ids.object_type = 'PACKAGE BODY'
                   AND ids.type in ('PROCEDURE', 'FUNCTION')
                   AND level = 2 
              THEN
                 CASE ids.usage
                    WHEN 'DECLARATION' THEN
                       'PRIVATE'
                    WHEN 'DEFINITION' THEN
                       'PUBLIC'
                 END
           END
        ) IGNORE NULLS OVER (
           PARTITION BY ids.owner, ids.object_name, ids.object_type 
           ORDER BY to_number(replace(regexp_substr(sys_connect_by_path(ids.line, '/'),'(\d+)/*$'),'/')), 
                    to_number(replace(regexp_substr(sys_connect_by_path(ids.col, '/'),'(\d+)/*$'),'/')), 
                    level
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS procedure_scope,       
        ids.name,
        sys_connect_by_path(ids.name, '/') AS name_path,
        level as path_len,
        ids.type,
        ids.usage,
        CASE 
           WHEN ids.object_type IN ('PACKAGE BODY', 'PROCEDURE', 'FUNCTION', 'TYPE BODY')
                AND ids.usage = 'DECLARATION'
           THEN
              CASE
                 WHEN 
                    count(
                       CASE 
                          WHEN ids.usage NOT IN ('DECLARATION', 'ASSIGNMENT') 
                               OR (ids.type IN ('FORMAL OUT', 'FORMAL IN OUT')
                                   AND ids.usage = 'ASSIGNMENT')
                          THEN 
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
        END AS is_used, -- wrong result, if used in statements which do not register usage such as EXECUTE IMMEDIATE. Bug?
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
