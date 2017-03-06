CREATE OR REPLACE PACKAGE BODY coldep IS
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

   --
   -- parse_query
   --
   FUNCTION parse_query(
      in_owner IN VARCHAR2, 
      in_query IN VARCHAR2
   ) RETURN xmltype IS
      l_clob CLOB;
      l_xml  xmltype;
   BEGIN
      dbms_lob.createtemporary(l_clob, TRUE);
      -- parse query and get XML as CLOB
      sys.utl_xml.parsequery(in_owner, in_query, l_clob);
      -- create XMLTYPE from CLOB 
      l_xml := xmltype.createxml(l_clob);
      dbms_lob.freetemporary(l_clob);
      RETURN l_xml;
   END parse_query;
   
   --
   -- dissolve
   --
   FUNCTION dissolve (
      in_column_pos IN INTEGER,
      in_owner      IN VARCHAR2,
      in_query      IN CLOB
   ) RETURN t_coldep_type IS
      l_xml     XMLTYPE;
      t_coldep  t_coldep_type := t_coldep_type();
   BEGIN
      -- parse query
      l_xml := parse_query(in_owner => in_owner, in_query => in_query);

      <<first_level_dependencies>>
      FOR r_dep IN (
         WITH
            dep AS (
               SELECT o.owner,
                      o.object_type,
                      o.object_name,
                      d.column_name
                 FROM xmltable(q'{
                                    declare function local:analyze-col($col as element()) as element()* {
                                       let $tableAlias := $col/ancestor::QUERY[1]//FROM_ITEM//TABLE_ALIAS[local-name(..) != 'COLUMN_REF' 
                                                                                                          and text() = $col/TABLE_ALIAS/text()]
                                       let $tableAliasTable := if ($tableAlias) then (
                                                                  $tableAlias/preceding::TABLE[1]
                                                               ) else (
                                                               )
                                       let $queryAlias := $col/ancestor::QUERY[1]//FROM_ITEM//QUERY_ALIAS[local-name(..) != 'COLUMN_REF' 
                                                                                                          and text() = $col/TABLE_ALIAS/text()]
                                       let $column := $col/COLUMN
                                       let $ret := if ($queryAlias) then (
                                                      for $rcol in $col/ancestor::QUERY//WITH_ITEM[QUERY_ALIAS/text() = $queryAlias/text()]
                                                                   //SELECT_LIST_ITEM//COLUMN_REF[ancestor::SELECT_LIST_ITEM/COLUMN_ALIAS/text() = $column/text() 
                                                                                                  or COLUMN/text = $column/text()]
                                                      let $rret := if ($rcol) then (
                                                                      local:analyze-col($rcol)
                                                                   ) else (
                                                                   )
                                                      return $rret
                                                   ) else (
                                                      let $tables := if ($tableAliasTable) then (
                                                                        $tableAliasTable
                                                                     ) else (
                                                                        for $tab in $col/ancestor::QUERY[1]//FROM_ITEM//*[self::TABLE or self::QUERY_ALIAS]
                                                                        return $tab
                                                                     )
                                                      for $tab in $tables
                                                      return
                                                         typeswitch($tab)
                                                         case element(QUERY_ALIAS)
                                                            return
                                                               let $rcol := $col/ancestor::QUERY//WITH_ITEM[QUERY_ALIAS/text() = $tab/text()]
                                                                            //SELECT_LIST_ITEM//COLUMN_REF[ancestor::SELECT_LIST_ITEM/COLUMN_ALIAS/text() = $column/text() 
                                                                                                           or COLUMN/text = $column/text()]
                                                               let $rret := if ($rcol) then (
                                                                               local:analyze-col($rcol) 
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
                                    
                                    for $col in //SELECT_LIST_ITEM[not (ancestor::FROM) and not (ancestor::WITH)][$columnPos]//COLUMN_REF
                                    let $res := local:analyze-col($col)
                                    return $res
                                 }'
                         PASSING l_xml, in_column_pos AS "columnPos"
                         COLUMNS schema_name VARCHAR2(128) PATH '/column/schemaName',
                                 table_name  VARCHAR2(128) PATH '/column/tableName',
                                 column_name VARCHAR2(128) PATH '/column/columnName'
                      ) d
                 JOIN dba_objects o
                   ON o.object_name = d.table_name
                      AND o.object_type IN ('SYNONYM', 'VIEW', 'TABLE', 'MATERIALIZED VIEW')
                      AND (o.owner = d.schema_name OR d.schema_name IS NULL)
            )
         SELECT DISTINCT
                LAST_VALUE(owner) OVER (
                   PARTITION BY object_name, column_name 
                   ORDER BY CASE object_type
                               WHEN 'SYNONYM' THEN 
                                  1
                               ELSE
                                  2
                               END
                   ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
                ) AS owner,
                LAST_VALUE(object_type) OVER (
                   PARTITION BY object_name, column_name 
                   ORDER BY CASE object_type
                               WHEN 'SYNONYM' THEN 
                                  1
                               ELSE
                                  2
                               END
                   ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
                ) AS object_type,
                object_name,
                column_name
           FROM dep
      ) LOOP
         t_coldep.extend;
         t_coldep(t_coldep.count) := coldep_type(
                                       r_dep.owner,
                                       r_dep.object_type,
                                       r_dep.object_name,
                                       r_dep.column_name
                                    );
         <<second_level_dependencies>>
         FOR r_dep2 IN (
            SELECT value(p) AS coldep
              FROM coldep.dissolve(
                      in_owner       => r_dep.owner,
                      in_object_name => r_dep.object_name,
                      in_column_name => r_dep.column_name
                   ) p
         ) LOOP
            t_coldep.extend;
            t_coldep(t_coldep.count) := r_dep2.coldep;
         END LOOP second_level_dependencies;
      END LOOP first_level_dependencies;

      RETURN t_coldep;      
   END dissolve;
   
   --
   -- resolve_synonym
   --
   PROCEDURE resolve_synonym (
      io_owner       IN OUT VARCHAR2,
      io_object_name IN OUT VARCHAR2
   ) IS
   BEGIN
      SELECT table_owner,
             table_name
        INTO io_owner,
             io_object_name
        FROM dba_synonyms
       WHERE owner = io_owner
         AND synonym_name = io_object_name;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         NULL;
   END resolve_synonym;

   --
   -- dissolve
   --
   FUNCTION dissolve(
      in_owner       IN VARCHAR2,
      in_object_name IN VARCHAR2,
      in_column_name IN VARCHAR2
   ) RETURN t_coldep_type IS
      l_view_owner   VARCHAR2(128) := in_owner;
      l_view_name    VARCHAR2(128) := in_object_name;
      t_coldep       t_coldep_type := t_coldep_type();
      t_final_coldep t_coldep_type := t_coldep_type();
   BEGIN
      -- resolve synonym into view
      resolve_synonym(io_owner => l_view_owner, io_object_name => l_view_name);
      
      IF l_view_owner IS NULL THEN
         t_coldep.extend;
         t_coldep(t_coldep.count) := coldep_type (
                                        in_owner,
                                        'TABLE',
                                        in_object_name,
                                        in_column_name
                                     );
      ELSE
         <<view_columns>>
         FOR r_view_col IN (
            SELECT vc.column_id, 
                   v.owner,
                   v.text
              FROM dba_views v
              JOIN dba_tab_columns vc
                ON vc.owner = v.owner
                   AND vc.table_name = v.view_name
             WHERE v.owner = l_view_owner
               AND v.view_name = l_view_name
               AND vc.column_name = in_column_name
         ) LOOP
            IF r_view_col.text IS NOT NULL THEN
               <<column_dendencies>>
               FOR r_coldep IN (
                  SELECT value(p) AS coldep
                    FROM coldep.dissolve(
                            in_column_pos => r_view_col.column_id,
                            in_owner => r_view_col.owner,
                            in_query => r_view_col.text
                         ) p
               ) LOOP
                  t_coldep.extend;
                  t_coldep(t_coldep.count) := r_coldep.coldep;
               END LOOP column_dendencies;
            END IF;
         END LOOP view_columns;
      END IF;

      -- TODO: bulk collect, implement map/order member function
      <<eliminate_duplicates>>
      FOR r_dup IN (
         SELECT DISTINCT
                owner,
                object_type,
                object_name,
                column_name
           FROM TABLE(t_coldep)
      ) LOOP
        t_final_coldep.extend();
        t_final_coldep(t_final_coldep.count) := coldep_type (
                                                   r_dup.owner,
                                                   r_dup.object_type,
                                                   r_dup.object_name,
                                                   r_dup.column_name
                                                );
      END LOOP eliminate_duplicates;

      -- return the final dependencies 
      RETURN t_final_coldep;
   END dissolve;

END coldep;
/
