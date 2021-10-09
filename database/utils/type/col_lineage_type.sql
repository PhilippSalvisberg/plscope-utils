/*
* Copyright 2011-2017 Philipp Salvisberg <philipp.salvisberg@trivadis.com>
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

create or replace type col_lineage_type force as
object (
   from_owner       varchar2(128 char),
   from_object_type varchar2(128 char),
   from_object_name varchar2(128 char),
   from_column_name varchar2(128 char),
   to_owner         varchar2(128 char),
   to_object_type   varchar2(128 char),
   to_object_name   varchar2(128 char),
   to_column_name   varchar2(128 char)
);
/
