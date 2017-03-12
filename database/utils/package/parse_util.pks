CREATE OR REPLACE PACKAGE parse_util IS
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
   * utility package to parse SQL statements
   *
   * @headcom
   */
   
   /**
   * Parses a query using utl_xml.parsequery
   *
   * @param in_parse_user parsing user
   * @param in_query query to analyze
   * @returns XML parse tree
   */
   FUNCTION parse_query(
      in_parse_user IN VARCHAR2, 
      in_query      IN CLOB
   ) RETURN xmltype;
   
   /**
   * Gets target objects (tables, views, materialized views, synonyms) of an insert statement.
   * Returns multiple target objects for multi table insert statements only.
   *
   * @param in_parse_user parsing user
   * @param in_sql insert statement to analyze
   * @returns table of target objects
   */
   FUNCTION get_insert_targets(
      in_parse_user IN VARCHAR2, 
      in_sql        IN CLOB
   ) RETURN t_obj_type;
      
   /**
   * Gets the subquery clause of an insert statement.
   *
   * @param in_sql insert statement to get subquery from
   * @returns the subquery part of the insert statement
   */
   FUNCTION get_insert_subquery(in_sql IN CLOB) RETURN CLOB;
   
   /**
   * Gets the dependend columns of a given column in a parse treee.
   *
   * @in_parse_tree parse tree by utl_xml.parsequery
   * @in_column_pos column to be analyzed in the parse tree
   * @returns columns in xml <column><schemaName/><tableName/><columName/></column>
   */
   FUNCTION get_dep_cols(
      in_parse_tree IN XMLTYPE,
      in_column_pos IN INTEGER
   ) RETURN XMLTYPE;
   
END parse_util;
/
