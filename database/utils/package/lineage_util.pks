CREATE OR REPLACE PACKAGE lineage_util IS
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
   PROCEDURE set_recursive (in_recursive IN INTEGER);

   /**
   * Gets the current default value of the in_recursive parameter in get_dep_cals_from_insert calls.
   *
   * @returns 1=true, 0=false
   */
   FUNCTION get_recursive RETURN INTEGER;

   /**
   * Gets the dependent columns of a given column in a query.
   *
   * @param in_parse_user parsing user
   * @param in_query query (view) to analyze
   * @param in_column_pos position/id of the column in the query to analyze
   * @param in_recursive 1=true, 0=false
   * @returns a table of col_type
   */   
   FUNCTION get_dep_cols_from_query(
      in_parse_user  IN VARCHAR2,
      in_query       IN CLOB,
      in_column_pos  IN INTEGER,
      in_recursive   IN INTEGER DEFAULT 1
   ) RETURN t_col_type;

   /**
   * Gets the dependent columns of a given column in a view.
   *
   * @param in_owner owner of the view or synonym to analyze
   * @param in_object_name name of the view or synonym to analyze
   * @param in_column_name name fo the column to analyze
   * @param in_recursive 1=true, 0=false
   * @returns a table of col_type
   */
   FUNCTION get_dep_cols_from_view(
      in_owner       IN VARCHAR2,
      in_object_name IN VARCHAR2,
      in_column_name IN VARCHAR2,
      in_recursive   IN INTEGER DEFAULT 1
   ) RETURN t_col_type;
   
   /**
   * Gets the dependent columns of a given PL/Scope SQL insert statement
   *
   * @param in_signature signature of PL/Scope Insert statement
   * @param in_recursive 1=true, 0=false
   * @returns a table of col_lineage_type
   */
   FUNCTION get_dep_cols_from_insert(
      in_signature IN VARCHAR2,
      in_recursive IN INTEGER DEFAULT get_recursive()
   ) RETURN t_col_lineage_type;

   /**
   * Get Insert target columns from a given PL/Scope SQL insert statement
   *
   * @param in_signature signature of PL/Scope Insert statement
   * @returns a table of col_type 
   */
   FUNCTION get_target_cols_from_insert(
      in_signature IN VARCHAR2
   ) RETURN t_col_type;
END lineage_util;
/
