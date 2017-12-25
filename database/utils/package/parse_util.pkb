CREATE OR REPLACE PACKAGE BODY parse_util IS
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

   --
   -- parse_query
   --
   FUNCTION parse_query(
      in_parse_user IN VARCHAR2, 
      in_query      IN CLOB
   ) RETURN xmltype IS
      l_clob    CLOB;
      l_xml     xmltype;
   BEGIN
      IF in_query IS NOT NULL AND sys.dbms_lob.getlength(in_query) > 0 THEN
         sys.dbms_lob.createtemporary(l_clob, TRUE);
         
         -- parse query and get XML as CLOB
         -- parsing user must have access to objects in query
         sys.utl_xml.parsequery(in_parse_user, in_query, l_clob);
   
         -- create XMLTYPE from CLOB
         IF sys.dbms_lob.getlength(l_clob) > 0 THEN
            -- parse successful, calling user has rights to access underlying objects
            l_xml := sys.xmltype.createxml(l_clob);
         END IF;
         sys.dbms_lob.freetemporary(l_clob);
      END IF;
      RETURN l_xml;
   END parse_query;
   
   --
   -- get_insert_targets
   --
   FUNCTION get_insert_targets(
      in_parse_user IN VARCHAR2, 
      in_sql        IN CLOB
   ) RETURN t_obj_type
   IS
      t_obj t_obj_type := t_obj_type();
      l_xml xmltype;
   BEGIN
      IF regexp_like(in_sql, '^(\s*)(INSERT)(.+)$', 'in') THEN
         l_xml := parse_query(in_parse_user => in_parse_user, in_query => in_sql);
         <<targets>>
         FOR r_tar IN (
            SELECT schema_name,
                   table_name
              FROM xmltable(q'{
                                 for $tar in /QUERY/FROM/FROM_ITEM
                                 return
                                    <target>
                                       <schemaName>{$tar/SCHEMA/text()}</schemaName>
                                       <tableName>{$tar/TABLE/text()}</tableName>
                                    </target>
                              }'
                      PASSING l_xml
                      COLUMNS schema_name VARCHAR2(128 CHAR) PATH '/target/schemaName',
                              table_name  VARCHAR2(128 CHAR) PATH '/target/tableName'
                   )
         ) LOOP
            t_obj.extend;
            t_obj(t_obj.count) := obj_type(
                                     r_tar.schema_name,
                                     NULL,
                                     r_tar.table_name
                                  );
         END LOOP targets;
      END IF;
      RETURN t_obj;
   END get_insert_targets;
   
   --
   -- get_insert_subquery
   --
   FUNCTION get_insert_subquery(in_sql IN CLOB) RETURN CLOB IS
      l_sql CLOB;
   BEGIN
      -- look for " WITH..."
      l_sql := regexp_substr(in_sql, '\s+WITH\s+(.+)', 1, 1, 'in');
      IF l_sql IS NULL OR sys.dbms_lob.getlength(l_sql) = 0 THEN
         -- look for "(SELECT..." or "SELECT..."
         l_sql := regexp_substr(in_sql, '(\s|\()+SELECT\s+(.+)', 1, 1, 'in');
      END IF;
      -- remove error_logging_clause
      l_sql := regexp_replace(l_sql, '(.+)(LOG\s+ERRORS.+)', '\1', 1, 1, 'in');
      RETURN l_sql;
   END get_insert_subquery;
   
   --
   -- get_dep_cols
   --
   FUNCTION get_dep_cols(
      in_parse_tree IN XMLTYPE,
      in_column_pos IN INTEGER
   ) RETURN XMLTYPE IS
      l_result XMLTYPE;
   BEGIN
      -- TODO: handle <LITERAL>*</LITERAL> in SELECT_LIST_ITEM
      -- Note: "select t.* from emp t" leads to a parse tree without literals!
      SELECT XMLQUERY(
                q'{
                  declare function local:analyze-col($col as element()) as element()* {
                     let $tableAlias := $col/ancestor::QUERY[1]/FROM/FROM_ITEM//TABLE_ALIAS[local-name(..) != 'COLUMN_REF' 
                                                                                            and text() = $col/TABLE_ALIAS/text()]
                     let $tableAliasTable := if ($tableAlias) then (
                                                $tableAlias/preceding::TABLE[1]
                                             ) else (
                                             )
                     let $queryAlias := $col/ancestor::QUERY[1]/FROM/FROM_ITEM//QUERY_ALIAS[local-name(..) != 'COLUMN_REF' 
                                                                                            and text() = $col/TABLE_ALIAS/text()]
                     let $column := $col/COLUMN
                     let $ret := if ($queryAlias) then (
                                    for $rcol in $col/ancestor::QUERY/WITH/WITH_ITEM[QUERY_ALIAS/text() = $queryAlias/text()]
                                                 //SELECT_LIST_ITEM//COLUMN_REF[ancestor::SELECT_LIST_ITEM/COLUMN_ALIAS/text() = $column/text() 
                                                                                or COLUMN/text() = $column/text()]
                                    let $rret := if ($rcol) then (
                                                    local:analyze-col($rcol)
                                                 ) else (
                                                 )
                                    return $rret
                                 ) else (
                                    let $tables := if ($tableAliasTable) then (
                                                      $tableAliasTable
                                                   ) else (
                                                      for $tab in $col/ancestor::QUERY[1]/FROM/FROM_ITEM//*[self::TABLE or self::QUERY_ALIAS]
                                                      return $tab
                                                   )
                                    for $tab in $tables
                                    return
                                       typeswitch($tab)
                                       case element(QUERY_ALIAS)
                                          return
                                             let $rcol := $col/ancestor::QUERY/WITH/WITH_ITEM[QUERY_ALIAS/text() = $tab/text()]
                                                          //SELECT_LIST_ITEM//COLUMN_REF[ancestor::SELECT_LIST_ITEM/COLUMN_ALIAS/text() = $column/text() 
                                                                                         or COLUMN/text() = $column/text()]
                                             let $rret := if ($rcol) then (
                                                             for $c in $rcol 
                                                             return local:analyze-col($c) 
                                                          ) else (
                                                          )
                                             return $rret
                                       default
                                          return
                                             <column>
                                                <schemaName>
                                                   {$tab/../SCHEMA/text()}
                                                </schemaName>
                                                <tableName>
                                                   {$tab/text()}
                                                </tableName>
                                                <columnName>
                                                   {$column/text()}
                                                </columnName>
                                             </column>
                                 )
                     return $ret
                  };
                  
                  for $col in //SELECT/SELECT_LIST/SELECT_LIST_ITEM[not(ancestor::SELECT_LIST_ITEM)][$columnPos]//COLUMN_REF
                  let $res := local:analyze-col($col)
                  return $res
                }'
                PASSING in_parse_tree, in_column_pos AS "columnPos" 
                RETURNING CONTENT
             ) 
        INTO l_result 
        FROM dual;
        RETURN l_result;
   END get_dep_cols;

END parse_util;
/
