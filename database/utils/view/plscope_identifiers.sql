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
   base_ids AS (
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
             ':' || NVL(sql_id, type) AS name,  -- intermediate statement marker colon
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
             coalesce(
                least(
                   usage_context_id,
                   max(usage_id) over (
                      PARTITION BY owner, object_name, object_type
                      ORDER BY usage_id
                      ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
                   )
                ),
                0
             ) AS usage_context_id, -- fix broken hierarchies
             origin_con_id
        FROM base_ids
       WHERE owner LIKE nvl(sys_context('PLSCOPE', 'OWNER'), USER)
   ),
   tree AS (
       SELECT ids.owner,
              ids.object_type,
              ids.object_name,
              ids.line,
              ids.col,
              ids.name,
              replace(sys_connect_by_path(ids.name, '|'),'|','/') AS name_path,
              level as path_len,
              ids.type,
              ids.usage,
              ids.signature,
              ids.usage_id,
              ids.usage_context_id,
              ids.origin_con_id
         FROM ids
        START WITH ids.usage_context_id = 0
      CONNECT BY  PRIOR ids.usage_id    = ids.usage_context_id
              AND PRIOR ids.owner       = ids.owner
              AND PRIOR ids.object_type = ids.object_type
              AND PRIOR ids.object_name = ids.object_name
   )
 SELECT tree.owner,
        tree.object_type,
        tree.object_name,
        tree.line,
        tree.col,
        last_value (
           CASE
              WHEN tree.type in ('PROCEDURE', 'FUNCTION') AND tree.path_len = 2  THEN
                 tree.name
           END
        ) IGNORE NULLS OVER (
           PARTITION BY tree.owner, tree.object_name, tree.object_type
           ORDER BY tree.line, tree.col, tree.path_len
        ) AS procedure_name,
        last_value (
           CASE 
              WHEN tree.object_type = 'PACKAGE BODY'
                AND tree.type in ('PROCEDURE', 'FUNCTION')
                AND tree.path_len = 2
              THEN
                 CASE tree.usage
                    WHEN 'DECLARATION' THEN
                       'PRIVATE'
                    WHEN 'DEFINITION' THEN
                       'PUBLIC'
                 END
           END
        ) IGNORE NULLS OVER (
           PARTITION BY tree.owner, tree.object_name, tree.object_type 
           ORDER BY tree.line, tree.col, tree.path_len
        ) AS procedure_scope,
        REPLACE(tree.name, ':', NULL) AS name, -- remove intermediate statement marker
        REPLACE(tree.name_path, ':', NULL) AS name_path, -- remove intermediate statement marker
        tree.path_len,
        tree.type,
        tree.usage,
        refs.owner AS ref_owner,
        refs.object_type AS ref_object_type,
        refs.object_name AS ref_object_name,
        (
           -- this correlated subquery will be evaluated only,
           -- if the column TEXT is selected
           SELECT regexp_replace(src.text, chr(10)||'+$', null) -- remove trailing new line character
             FROM dba_source src
            WHERE src.owner = tree.owner
              AND src.type = tree.object_type
              AND src.name = tree.object_name
              AND src.line = tree.line
        ) AS text,
        CASE
           WHEN tree.name_path LIKE '%:%' AND tree.usage != 'EXECUTE' THEN
              -- ensure that this is really a child of a statement
              last_value (
                 CASE
                    WHEN tree.usage = 'EXECUTE' THEN
                       tree.type
                 END
              ) IGNORE NULLS OVER (
                 PARTITION BY tree.owner, tree.object_name, tree.object_type
                 ORDER BY tree.line, tree.col, tree.path_len
              )
        END AS parent_statement_type,
        CASE
           WHEN tree.name_path LIKE '%:%' AND tree.usage != 'EXECUTE' THEN
              -- ensure that this is really a child of a statement
              last_value (
                 CASE
                    WHEN tree.usage = 'EXECUTE' THEN
                       tree.signature
                 END
              ) IGNORE NULLS OVER (
                 PARTITION BY tree.owner, tree.object_name, tree.object_type
                 ORDER BY tree.line, tree.col, tree.path_len
              )
        END AS parent_statement_signature,
        CASE
           WHEN tree.name_path LIKE '%:%' AND tree.usage != 'EXECUTE' THEN
              -- ensure that this is really a child of a statement
              last_value (
                 CASE
                    WHEN tree.usage = 'EXECUTE' THEN
                       tree.path_len
                 END
              ) IGNORE NULLS OVER (
                 PARTITION BY tree.owner, tree.object_name, tree.object_type
                 ORDER BY tree.line, tree.col, tree.path_len
              )
        END AS parent_statement_path_len,
        CASE 
           WHEN tree.object_type IN ('PACKAGE BODY', 'PROCEDURE', 'FUNCTION', 'TYPE BODY')
              AND tree.usage = 'DECLARATION'
              AND tree.type NOT IN ('LABEL')
           THEN
              CASE
                 WHEN 
                    count(
                       CASE 
                          WHEN tree.usage NOT IN ('DECLARATION', 'ASSIGNMENT') 
                             OR (tree.type IN ('FORMAL OUT', 'FORMAL IN OUT')
                                 AND tree.usage = 'ASSIGNMENT')
                          THEN 
                             1 
                       END
                    ) OVER (
                       PARTITION BY tree.owner, tree.object_name, tree.object_type, tree.signature
                    ) = 0
                 THEN
                    'NO'
                 ELSE
                    'YES'
              END
        END AS is_used, -- wrong result, if used in statements which do not register usage, such as a variable for dynamic_sql_stmt in EXECUTE IMMEDIATE. Bug?
        tree.signature,
        tree.usage_id,
        tree.usage_context_id,
        tree.origin_con_id
   FROM tree
   LEFT JOIN dba_identifiers refs
     ON refs.signature = tree.signature
        AND refs.usage = 'DECLARATION';
