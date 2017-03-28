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
   root_ids AS (
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
   ),
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
        FROM root_ids
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
             'MISSING' AS usage, -- artifical usage
             gen.row_num AS usage_id, 
             NULL AS line, 
             NULL AS col, 
             gen.row_num - 1 AS usage_context_id,
             b1.origin_con_id
        FROM base_ids b1
        JOIN gen
          ON gen.row_num < b1.max_usage_id -- ids after the last registered one, are not visible
        LEFT JOIN base_ids b2
          ON b2.owner = b1.owner
             AND b2.object_type = b1.object_type
             AND b2.object_name = b1.object_name
             AND b2.usage_id = gen.row_num
       WHERE b1.usage_context_id = 0
         AND b2.owner IS NULL
   ),
   tree AS (
       SELECT ids.owner,
              ids.object_type,
              ids.object_name,
              to_number(replace(regexp_substr(sys_connect_by_path(ids.line, '/'),'\d+/*$'),'/')) AS line,
              to_number(replace(regexp_substr(sys_connect_by_path(ids.col, '/'),'\d+/*$'),'/')) AS col,
              ids.name,
              sys_connect_by_path(ids.name, '/') AS name_path,
              level as path_len,
              ids.type,
              ids.usage,
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
              AND PRIOR ids.object_name = ids.object_name
   )
SELECT owner,
       object_type,
       object_name,
       line,
       col,
       last_value (
         CASE 
             WHEN object_type = 'PACKAGE BODY'
                  AND type in ('PROCEDURE', 'FUNCTION')
                  AND path_len = 2 
             THEN
                name 
          END
       ) IGNORE NULLS OVER (
          PARTITION BY owner, object_name, object_type 
          ORDER BY line, col, path_len
          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS procedure_name,
       last_value (
          CASE 
            WHEN object_type = 'PACKAGE BODY'
                  AND type in ('PROCEDURE', 'FUNCTION')
                  AND path_len = 2 
             THEN
                CASE usage
                   WHEN 'DECLARATION' THEN
                      'PRIVATE'
                   WHEN 'DEFINITION' THEN
                      'PUBLIC'
                END
          END
       ) IGNORE NULLS OVER (
          PARTITION BY owner, object_name, object_type 
          ORDER BY line, col, path_len
          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS procedure_scope,       
       name,
       name_path,
       path_len,
       type,
       usage,
       CASE 
          WHEN object_type IN ('PACKAGE BODY', 'PROCEDURE', 'FUNCTION', 'TYPE BODY')
               AND usage = 'DECLARATION'
          THEN
             CASE
                WHEN 
                   count(
                      CASE 
                         WHEN usage NOT IN ('DECLARATION', 'ASSIGNMENT') 
                              OR (type IN ('FORMAL OUT', 'FORMAL IN OUT')
                                  AND usage = 'ASSIGNMENT')
                         THEN 
                            1 
                      END
                   ) OVER (
                      PARTITION BY owner, object_name, object_type, signature
                   ) = 0
                THEN
                   'NO'
                ELSE
                   'YES'
             END
       END AS is_used, -- wrong result, if used in statements which do not register usage such as EXECUTE IMMEDIATE. Bug?
       ref_owner,
       ref_object_type,
       ref_object_name,
       signature, 
       usage_id, 
       usage_context_id,
       origin_con_id
  FROM tree;
