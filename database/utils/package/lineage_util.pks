create or replace package lineage_util is
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

   /**
   * Sets the default value for the in_recursive parameter in get_dep_cals_from_insert calls.
   * This procedure is used to control the behaviour of the plscope_ins_lineage view.
   * The default value is 1 (true).
   *
   * @param in_recursive 1=true, 0=false
   */
   procedure set_recursive(in_recursive in integer);

   /**
   * Gets the current default value of the in_recursive parameter in get_dep_cals_from_insert calls.
   *
   * @returns 1=true, 0=false
   */
   function get_recursive return integer;

   /**
   * Gets the dependent columns of a given column in a query.
   *
   * @param in_parse_user parsing user
   * @param in_query query (view) to analyze
   * @param in_column_pos position/id of the column in the query to analyze
   * @param in_recursive 1=true, 0=false
   * @returns a table of col_type
   */
   function get_dep_cols_from_query(
      in_parse_user in varchar2,
      in_query      in clob,
      in_column_pos in integer,
      in_recursive  in integer default 1
   ) return t_col_type;

   /**
   * Gets the dependent columns of a given column in a view.
   *
   * @param in_owner owner of the view or synonym to analyze
   * @param in_object_name name of the view or synonym to analyze
   * @param in_column_name name fo the column to analyze
   * @param in_recursive 1=true, 0=false
   * @returns a table of col_type
   */
   function get_dep_cols_from_view(
      in_owner       in varchar2,
      in_object_name in varchar2,
      in_column_name in varchar2,
      in_recursive   in integer default 1
   ) return t_col_type;
   
   /**
   * Gets the dependent columns of a given PL/Scope SQL insert statement
   *
   * @param in_signature signature of PL/Scope Insert statement
   * @param in_recursive 1=true, 0=false
   * @returns a table of col_lineage_type
   */
   function get_dep_cols_from_insert(
      in_signature in varchar2,
      in_recursive in integer default get_recursive()
   ) return t_col_lineage_type;

   /**
   * Get Insert target columns from a given PL/Scope SQL insert statement
   *
   * @param in_signature signature of PL/Scope Insert statement
   * @returns a table of col_type 
   */
   function get_target_cols_from_insert(
      in_signature in varchar2
   ) return t_col_type;
end lineage_util;
/
