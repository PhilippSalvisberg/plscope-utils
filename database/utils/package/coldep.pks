CREATE OR REPLACE PACKAGE coldep IS
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
   * coldep - utility package to dissolve column dependencies
   *
   * @headcom
   */

   /**
   * Dissolves the column dependencies of a given query.
   *
   * @param in_column_pos position/id of the column in the query to analyze
   * @param in_owner parsing user (owner of the view)
   * @param in_query query (view) to analyze
   * @returns a table of coldep_type
   */   
   FUNCTION dissolve (
      in_column_pos IN INTEGER,
      in_owner      IN VARCHAR2,
      in_query      IN CLOB
   ) RETURN t_coldep_type;

   /**
   * Dissolves the column dependencies of a given view column based on
   * various data dictionary views including view source code.
   *
   * @param in_owner owner of the view or synonym to analyze
   * @param in_object_name name of the view or synonym to analyze
   * @param in_column_name name fo the column to analyze
   * @returns a table of coldep_type
   */
   FUNCTION dissolve(
      in_owner       IN VARCHAR2,
      in_object_name IN VARCHAR2,
      in_column_name IN VARCHAR2
   ) RETURN t_coldep_type;
END coldep;
/
