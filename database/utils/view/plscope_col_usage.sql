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
 ORDER BY ids.owner,
          ids.object_type,
          ids.object_name,
          ids.line,
          ids.col,
          ids.path_len;
