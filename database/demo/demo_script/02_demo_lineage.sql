-- 1. parse the insert statement using sys.utl_xml.parsequery
SELECT full_text, parse_util.parse_query(s.owner, s.full_text) 
  FROM all_statements s
 WHERE s.type = 'INSERT'
   AND s.object_name = 'LOAD_FROM_TAB'
   AND type = 'INSERT';

-- 2. get taget tables via XQuery
SELECT schema_name,
       table_name
  FROM all_statements s,
       xmltable(q'{
                     for $tar in /QUERY/FROM/FROM_ITEM
                     return
                        <target>
                           <schemaName>{$tar/SCHEMA/text()}</schemaName>
                           <tableName>{$tar/TABLE/text()}</tableName>
                        </target>
                  }'
          PASSING parse_util.parse_query(s.owner, s.full_text)
          COLUMNS schema_name VARCHAR2(128 CHAR) PATH '/target/schemaName',
                  table_name  VARCHAR2(128 CHAR) PATH '/target/tableName'
       )
 WHERE s.type = 'INSERT'
   AND s.object_name = 'LOAD_FROM_TAB'
   AND type = 'INSERT';

-- 3. get target tables from table function
SELECT t.* 
  FROM all_statements s,
       TABLE(parse_util.get_insert_targets(s.owner, s.full_text)) t
 WHERE s.type = 'INSERT'
   AND s.object_name = 'LOAD_FROM_TAB';
         
-- 4. get fully qualified target tables from table functions
SELECT t.* 
  FROM all_statements s,
       TABLE(dd_util.get_objects(s.owner, parse_util.get_insert_targets(s.owner, s.full_text))) t
 WHERE s.type = 'INSERT'
   AND s.object_name = 'LOAD_FROM_TAB';

-- 5. get subquery from insert statement
SELECT s.full_text, 
       regexp_substr(s.full_text, '(\s|\()+SELECT\s+(.+)', 1, 1, 'i') AS subquery 
  FROM all_statements s,
       TABLE(dd_util.get_objects(s.owner, parse_util.get_insert_targets(s.owner, s.full_text))) t
 WHERE s.type = 'INSERT'
   AND s.object_name = 'LOAD_FROM_TAB';
   
-- 6. get subquery from function, handling more cases (e.g. with_clause, error_logging_clause)    
SELECT s.full_text, 
       parse_util.get_insert_subquery(s.full_text) AS subquery 
  FROM all_statements s,
       TABLE(dd_util.get_objects(s.owner, parse_util.get_insert_targets(s.owner, s.full_text))) t
 WHERE s.type = 'INSERT'
   AND s.object_name = 'LOAD_FROM_TAB';

-- 7. parse the subquery using sys.utl_xml.parsequery
SELECT full_text, parse_util.parse_query(s.owner, parse_util.get_insert_subquery(s.full_text)) 
  FROM all_statements s
 WHERE s.type = 'INSERT'
   AND s.object_name = 'LOAD_FROM_TAB'
   AND type = 'INSERT';
   
-- 8. where-linage of column salary
SELECT schema_name,
       table_name,
       column_name
  FROM all_statements s,
       xmltable(q'{
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
                     }; (: avoid premature statement termination in SQL*Plus et al. :)
                     
                     for $col in //SELECT/SELECT_LIST/SELECT_LIST_ITEM[not(ancestor::SELECT_LIST_ITEM)][$columnPos]//COLUMN_REF
                     let $res := local:analyze-col($col)
                     return $res
                  }'
          PASSING parse_util.parse_query(s.owner, parse_util.get_insert_subquery(s.full_text)), 3 AS "columnPos" 
          COLUMNS schema_name VARCHAR2(128 CHAR) PATH 'schemaName',
                  table_name  VARCHAR2(128 CHAR) PATH 'tableName',
                  column_name VARCHAR2(128 CHAR) PATH 'columnName'
       )
 WHERE s.type = 'INSERT'
   AND s.object_name = 'LOAD_FROM_TAB'
   AND type = 'INSERT';
   
-- 9. where-linage of column salary via function hiding XQuery complexity
SELECT l.owner,
       l.object_type,
       l.object_name,
       l.column_name
  FROM all_statements s,
       TABLE(lineage_util.get_dep_cols_from_query(s.owner, parse_util.get_insert_subquery(s.full_text), 3)) l
 WHERE s.type = 'INSERT'
   AND s.object_name = 'LOAD_FROM_TAB'
   AND type = 'INSERT';

-- 10. where-lineage of all columns via function
SELECT ids.line, ids.col, 
       l.from_owner, l.from_object_type, l.from_object_name, l.from_column_name,
       l.to_owner, l.to_object_type, l.to_object_name, l.to_column_name
  FROM plscope_identifiers ids,
       TABLE(lineage_util.get_dep_cols_from_insert(ids.signature, 1)) l 
 WHERE ids.type = 'INSERT'
   AND ids.object_name = 'LOAD_FROM_TAB'
 ORDER BY to_column_name;
 
-- 11. where-lineage of all columns via view
SELECT line, col, 
       from_owner, from_object_type, from_object_name, from_column_name,
       to_owner, to_object_type, to_object_name, to_column_name
  FROM plscope_ins_lineage
 WHERE object_name = 'LOAD_FROM_TAB'
 ORDER BY to_column_name;
 
-- 12. where-lineage of all insert statements collected by PL/Scope (default behaviour)
SELECT *
  FROM plscope_ins_lineage
 WHERE owner = USER
 ORDER BY owner, object_type, object_name, line, col, 
       to_object_name, to_column_name, 
       from_owner, from_object_type, from_object_name, from_column_name;

-- 13. where-linage of all insert statements without recursive column analysis
EXEC lineage_util.set_recursive(0);
SELECT *
  FROM plscope_ins_lineage
 WHERE owner = USER
 ORDER BY owner, object_type, object_name, line, col, 
       to_object_name, to_column_name, 
       from_owner, from_object_type, from_object_name, from_column_name;

-- 14. where-linage of all insert statements with recursive column analysis, but show table source only
EXEC lineage_util.set_recursive(1);
SELECT *
  FROM plscope_ins_lineage
 WHERE owner = USER
   AND from_object_type = 'TABLE' 
 ORDER BY owner, object_type, object_name, line, col, 
       to_object_name, to_column_name, 
       from_owner, from_object_type, from_object_name, from_column_name;
