-- 1. parse the insert statement using sys.utl_xml.parsequery
select full_text, parse_util.parse_query(in_parse_user => user, in_query => full_text)
  from user_statements
 where type = 'INSERT'
   and object_name = 'LOAD_FROM_TAB'
   and type = 'INSERT';

-- 2. get taget tables via XQuery
select t.schema_name,
       t.table_name
  from user_statements s
 cross join xmltable(q'{
                     for $tar in /QUERY/FROM/FROM_ITEM
                     return
                        <target>
                           <schemaName>{$tar/SCHEMA/text()}</schemaName>
                           <tableName>{$tar/TABLE/text()}</tableName>
                        </target>
                  }'
          passing parse_util.parse_query(in_parse_user => user, in_query => s.full_text)
          columns schema_name varchar2(128 char) path '/target/schemaName',
                  table_name  varchar2(128 char) path '/target/tableName'
       ) t
 where s.type = 'INSERT'
   and s.object_name = 'LOAD_FROM_TAB'
   and type = 'INSERT';

-- 3. get target tables from table function
select t.*
  from user_statements s
 cross join table(parse_util.get_insert_targets(in_parse_user => user, in_sql => s.full_text)) t
 where s.type = 'INSERT'
   and s.object_name = 'LOAD_FROM_TAB';
         
-- 4. get fully qualified target tables from table functions
select t.*
  from user_statements s
 cross join table(
          dd_util.get_objects(
             in_parse_user => user,
             in_t_obj      => parse_util.get_insert_targets(
                                 in_parse_user => user,
                                 in_sql        => s.full_text
                              )
          )
       ) t
 where s.type = 'INSERT'
   and s.object_name = 'LOAD_FROM_TAB';

-- 5. get subquery from insert statement
select s.full_text,
       regexp_substr(s.full_text, '(\s|\()+SELECT\s+(.+)', 1, 1, 'i') as subquery
  from user_statements s
 cross join table(
          dd_util.get_objects(
             in_parse_user => user,
             in_t_obj      => parse_util.get_insert_targets(
                                 in_parse_user => user,
                                 in_sql        => s.full_text
                              )
          )
       ) t
 where s.type = 'INSERT'
   and s.object_name = 'LOAD_FROM_TAB';
   
-- 6. get subquery from function, handling more cases (e.g. with_clause, error_logging_clause)    
select s.full_text,
       parse_util.get_insert_subquery(in_sql => s.full_text) as subquery
  from user_statements s
 cross join table(
          dd_util.get_objects(
             in_parse_user => user,
             in_t_obj      => parse_util.get_insert_targets(
                                 in_parse_user => user,
                                 in_sql        => s.full_text
                              )
          )
       ) t
 where s.type = 'INSERT'
   and s.object_name = 'LOAD_FROM_TAB';

-- 7. parse the subquery using sys.utl_xml.parsequery
select full_text,
       parse_util.parse_query(
          in_parse_user => user,
          in_query      => parse_util.get_insert_subquery(in_sql => s.full_text)
       )
  from user_statements s
 where s.type = 'INSERT'
   and s.object_name = 'LOAD_FROM_TAB'
   and type = 'INSERT';
   
-- 8. where-linage of column salary
select t.schema_name,
       t.table_name,
       t.column_name
  from user_statements s
 cross join xmltable(q'{
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
          passing parse_util.parse_query(
             in_parse_user => user,
             in_query      => parse_util.get_insert_subquery(in_sql => s.full_text)
          ),
          3 as "columnPos"
          columns schema_name varchar2(128 char) path 'schemaName',
                  table_name  varchar2(128 char) path 'tableName',
                  column_name varchar2(128 char) path 'columnName'
       ) t
 where s.type = 'INSERT'
   and s.object_name = 'LOAD_FROM_TAB';
   
-- 9. where-linage of column salary via function hiding XQuery complexity
select l.owner,
       l.object_type,
       l.object_name,
       l.column_name
  from all_statements s
 cross join table(
          lineage_util.get_dep_cols_from_query(
             in_parse_user => user,
             in_query      => parse_util.get_insert_subquery(in_sql => s.full_text),
             in_column_pos => 3
          )
       ) l
 where s.type = 'INSERT'
   and s.object_name = 'LOAD_FROM_TAB'
   and type = 'INSERT';

-- 10. where-lineage of all columns via function
select ids.line,
       ids.col,
       l.from_owner,
       l.from_object_type,
       l.from_object_name,
       l.from_column_name,
       l.to_owner,
       l.to_object_type,
       l.to_object_name,
       l.to_column_name
  from plscope_identifiers ids
 cross join table(
          lineage_util.get_dep_cols_from_insert(
             in_signature => ids.signature,
             in_recursive => 1
          )
       ) l
 where ids.type = 'INSERT'
   and ids.object_name = 'LOAD_FROM_TAB'
 order by to_column_name;
 
-- 11. where-lineage of all columns via view
select line,
       col,
       from_owner,
       from_object_type,
       from_object_name,
       from_column_name,
       to_owner,
       to_object_type,
       to_object_name,
       to_column_name
  from plscope_ins_lineage
 where object_name = 'LOAD_FROM_TAB'
 order by to_column_name;
 
-- 12. where-lineage of all insert statements collected by PL/Scope (default behaviour)
select *
  from plscope_ins_lineage
 order by owner,
       object_type,
       object_name,
       line,
       col,
       to_object_name,
       to_column_name,
       from_owner,
       from_object_type,
       from_object_name,
       from_column_name;

-- 13. where-linage of all insert statements without recursive column analysis
exec lineage_util.set_recursive(0);
select *
  from plscope_ins_lineage
 order by owner,
       object_type,
       object_name,
       line,
       col,
       to_object_name,
       to_column_name,
       from_owner,
       from_object_type,
       from_object_name,
       from_column_name;

-- 14. where-linage of all insert statements with recursive column analysis, but show table source only
exec lineage_util.set_recursive(1);
select *
  from plscope_ins_lineage
 where from_object_type = 'TABLE'
 order by owner,
       object_type,
       object_name,
       line,
       col,
       to_object_name,
       to_column_name,
       from_owner,
       from_object_type,
       from_object_name,
       from_column_name;
