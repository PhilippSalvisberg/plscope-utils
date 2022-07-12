create or replace package parse_util is
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
   function parse_query(
      in_parse_user in varchar2,
      in_query      in clob
   ) return sys.xmltype;
   
   /**
   * Gets target objects (tables, views, materialized views, synonyms) of an insert statement.
   * Returns multiple target objects for multi table insert statements only.
   *
   * @param in_parse_user parsing user
   * @param in_sql insert statement to analyze
   * @returns table of target objects
   */
   function get_insert_targets(
      in_parse_user in varchar2,
      in_sql        in clob
   ) return t_obj_type;
      
   /**
   * Gets the subquery clause of an insert statement.
   *
   * @param in_sql insert statement to get subquery from
   * @returns the subquery part of the insert statement
   */
   function get_insert_subquery(in_sql in clob) return clob;
   
   /**
   * Gets the dependend columns of a given column in a parse treee.
   *
   * @in_parse_tree parse tree by utl_xml.parsequery
   * @in_column_pos column to be analyzed in the parse tree
   * @returns columns in xml <column><schemaName/><tableName/><columName/></column>
   */
   function get_dep_cols(
      in_parse_tree in sys.xmltype,
      in_column_pos in integer
   ) return sys.xmltype;

end parse_util;
/
