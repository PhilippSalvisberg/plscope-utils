create or replace package body parse_util is
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
   -- utl_xml_parse_query (private)
   --
   $if sys.dbms_db_version.version >= 18 $then
      -- workaround for utl_xml.parsequery which is protected by an accessible_by_clause
      procedure utl_xml_parse_query (
         in_current_userid in number,
         in_schema_name    in varchar2,
         in_query          in clob,
         io_result         in out nocopy clob
      ) is
         language c 
         library sys.utl_xml_lib 
         name "kuxParseQuery"
         with context parameters (
            context,
            in_current_userid ocinumber,     -- usage not registered by PL/Scope in 19c
            in_current_userid indicator,     -- usage not registered by PL/Scope in 19c
            in_schema_name    ocistring,     -- usage not registered by PL/Scope in 19c
            in_schema_name    indicator,     -- usage not registered by PL/Scope in 19c
            in_query          ociloblocator, -- usage not registered by PL/Scope in 19c
            in_query          indicator,     -- usage not registered by PL/Scope in 19c
            io_result         ociloblocator, -- usage not registered by PL/Scope in 19c
            io_result         indicator      -- usage not registered by PL/Scope in 19c
         );
   $end

   --
   -- parse_query
   --
   function parse_query(
      in_parse_user in varchar2,
      in_query      in clob
   ) return sys.xmltype is
      l_clob clob;
      l_xml  sys.xmltype;
   begin
      if in_query is not null and sys.dbms_lob.getlength(in_query) > 0 then
         sys.dbms_lob.createtemporary(l_clob, true);
         
         -- parse query and get XML as CLOB
         -- parsing user must have access to objects in query
         $if sys.dbms_db_version.ver_le_12_2 $then
            sys.utl_xml.parsequery(in_parse_user, in_query, l_clob);
         $else
            utl_xml_parse_query(sys_context('USERENV','SESSION_USERID'), in_parse_user, in_query, l_clob);
         $end

         -- create XMLTYPE from CLOB
         if sys.dbms_lob.getlength(l_clob) > 0 then
            -- parse successful, calling user has rights to access underlying objects
            l_xml := sys.xmltype.createxml(l_clob);
         end if;
         sys.dbms_lob.freetemporary(l_clob);
      end if;
      return l_xml;
   end parse_query;
   
   --
   -- get_insert_targets
   --
   function get_insert_targets(
      in_parse_user in varchar2,
      in_sql        in clob
   ) return t_obj_type
   is
      t_obj t_obj_type := t_obj_type();
      l_xml sys.xmltype;
   begin
      if regexp_like(in_sql, '^(\s*)(INSERT)(.+)$', 'in') then
         l_xml := parse_query(in_parse_user => in_parse_user, in_query => in_sql);
         <<targets>>
         for r_tar in (
            select schema_name,
                   table_name
              from xmltable(q'{
                                 for $tar in /QUERY/FROM/FROM_ITEM
                                 return
                                    <target>
                                       <schemaName>{$tar/SCHEMA/text()}</schemaName>
                                       <tableName>{$tar/TABLE/text()}</tableName>
                                    </target>
                              }'
                      passing l_xml
                      columns schema_name varchar2(128 char) path '/target/schemaName',
                              table_name  varchar2(128 char) path '/target/tableName'
                   )
         )
         loop
            t_obj.extend;
            t_obj(t_obj.count) := obj_type(r_tar.schema_name, null, r_tar.table_name);
         end loop targets;
      end if;
      return t_obj;
   end get_insert_targets;
   
   --
   -- get_insert_subquery
   --
   function get_insert_subquery(in_sql in clob) return clob is
      l_sql clob;
   begin
      -- look for " WITH..."
      l_sql := regexp_substr(in_sql, '\s+WITH\s+(.+)', 1, 1, 'in');
      if l_sql is null or sys.dbms_lob.getlength(l_sql) = 0 then
         -- look for "(SELECT..." or "SELECT..."
         l_sql := regexp_substr(in_sql, '(\s|\()+SELECT\s+(.+)', 1, 1, 'in');
      end if;
      -- remove error_logging_clause
      l_sql := regexp_replace(l_sql, '(.+)(LOG\s+ERRORS.+)', '\1', 1, 1, 'in');
      return l_sql;
   end get_insert_subquery;
   
   --
   -- get_dep_cols
   --
   function get_dep_cols(
      in_parse_tree in sys.xmltype,
      in_column_pos in integer
   ) return sys.xmltype is
      l_result sys.xmltype;
   begin
      -- Note 1: column wildcard is not handled (<LITERAL>*</LITERAL> in SELECT_LIST_ITEM).
      -- Note 2: aliased colunm wildcard is lost, e.g. "select t.* from emp t" leads to a parse tree without literals!
      select xmlquery(
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
                passing in_parse_tree, in_column_pos as "columnPos"
                returning content
             )
        into l_result
        from sys.dual; -- NOSONAR: avoid public synonym
      return l_result;
   end get_dep_cols;

end parse_util;
/
