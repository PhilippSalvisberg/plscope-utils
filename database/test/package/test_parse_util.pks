create or replace package test_parse_util authid current_user is
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
   
   -- %suite
   -- %suitepath(plscope.test)
   
   -- %test
   procedure test_parse_query;

   -- %test
   procedure test_get_insert_targets;

   -- %test
   procedure test_get_insert_subquery;
   
   -- %test
   procedure test_get_dep_cols;

end test_parse_util;
/
