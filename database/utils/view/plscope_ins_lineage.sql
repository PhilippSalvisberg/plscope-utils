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

create or replace view plscope_ins_lineage as
   with
      ids as (
         select /*+materialize */
                owner,
                object_type,
                object_name,
                line,
                col,
                procedure_name,
                signature
           from plscope_identifiers
          where type = 'INSERT'
      )
   select ids.owner,
          ids.object_type,
          ids.object_name,
          ids.line,
          ids.col,
          ids.procedure_name,
          l.from_owner,
          l.from_object_type,
          l.from_object_name,
          l.from_column_name,
          l.to_owner,
          l.to_object_type,
          l.to_object_name,
          l.to_column_name
     from ids
    cross join table(lineage_util.get_dep_cols_from_insert(ids.signature)) l;
