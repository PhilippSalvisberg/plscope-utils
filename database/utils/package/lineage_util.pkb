CREATE OR REPLACE PACKAGE BODY lineage_util IS
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
   -- global variable recursive, used by get_dep_cols_from_insert
   --
   g_recursive INTEGER DEFAULT 1;

   --
   -- set_recursive
   --
   PROCEDURE set_recursive (in_recursive IN INTEGER) IS
   BEGIN
      IF in_recursive = 0 THEN
         g_recursive := in_recursive;
      ELSE
         g_recursive := 1; -- the default value anyway
      END IF;
   END set_recursive;

   --
   -- get_recursive
   --
   FUNCTION get_recursive RETURN INTEGER IS
   BEGIN
      RETURN g_recursive;
   END get_recursive;
   
   --
   -- get_dep_cols_from_query
   --
   FUNCTION get_dep_cols_from_query(
      in_parse_user  IN VARCHAR2,
      in_query       IN CLOB,
      in_column_pos  IN INTEGER,
      in_recursive   IN INTEGER DEFAULT 1
   ) RETURN t_col_type IS
      l_parse_tree XMLTYPE;
      l_dep_cols   XMLTYPE;
      o_obj        obj_type;
      t_col        t_col_type := t_col_type();
   BEGIN
      -- parse query
      l_parse_tree := parse_util.parse_query(
                         in_parse_user => in_parse_user, 
                         in_query      => in_query
                      );

      IF l_parse_tree IS NOT NULL THEN
         l_dep_cols := parse_util.get_dep_cols(
                          in_parse_tree => l_parse_tree, 
                          in_column_pos => in_column_pos
                       );
         IF l_dep_cols IS NOT NULL THEN
            <<first_level_dependencies>>
            FOR r_dep IN (
               SELECT schema_name,
                      table_name,
                      column_name
                 FROM xmltable('/column'
                         PASSING l_dep_cols
                         COLUMNS schema_name VARCHAR2(128 CHAR) PATH 'schemaName',
                                 table_name  VARCHAR2(128 CHAR) PATH 'tableName',
                                 column_name VARCHAR2(128 CHAR) PATH 'columnName'
                      )
            ) LOOP
               o_obj := dd_util.resolve_synonym(
                           in_parse_user => in_parse_user,
                           in_obj        => obj_type(
                                               owner       => r_dep.schema_name,
                                               object_type => NULL,
                                               object_name => r_dep.table_name
                                            )
                        );
               t_col.extend;
               t_col(t_col.count) := col_type(
                                        owner       => o_obj.owner,
                                        object_type => o_obj.object_type,
                                        object_name => o_obj.object_name,
                                        column_name => r_dep.column_name
                                     );
               IF in_recursive = 1 THEN
                  <<second_level_dependencies>>
                  FOR r_dep2 IN (
                     SELECT value(p) AS col
                       FROM TABLE(
                               lineage_util.get_dep_cols_from_view(
                                  in_owner       => o_obj.owner,
                                  in_object_name => o_obj.object_name,
                                  in_column_name => r_dep.column_name,
                                  in_recursive   => in_recursive
                               )
                            ) p
                  ) LOOP
                     t_col.extend;
                     t_col(t_col.count) := r_dep2.col;
                  END LOOP second_level_dependencies;
               END IF;
            END LOOP first_level_dependencies;
         END IF;
      END IF;

      RETURN type_util.dedup(in_t_col => t_col);      
   END get_dep_cols_from_query;

   --
   -- get_dep_cols_from_view
   --
   FUNCTION get_dep_cols_from_view(
      in_owner       IN VARCHAR2,
      in_object_name IN VARCHAR2,
      in_column_name IN VARCHAR2,
      in_recursive   IN INTEGER DEFAULT 1
   ) RETURN t_col_type IS
      o_obj        obj_type;
      l_column_id  INTEGER;
      l_query      CLOB;
      t_col        t_col_type := t_col_type();
   BEGIN
      -- resolve synonym into view
      o_obj := dd_util.resolve_synonym(
                  in_parse_user => in_owner,
                  in_obj        => obj_type (
                                      owner       => null,
                                      object_type => null,
                                      object_name => in_object_name
                                   )
               );
      
      IF o_obj.object_type = 'VIEW' THEN
         l_column_id := dd_util.get_column_id(
                           in_owner       => o_obj.owner,
                           in_object_name => o_obj.object_name,
                           in_column_name => in_column_name
                        );
         IF l_column_id IS NOT NULL THEN
            l_query := dd_util.get_view_source(in_obj => o_obj);
            IF l_query IS NOT NULL THEN
               <<column_dendencies>>
               FOR r_col IN (
                  SELECT value(p) AS col
                    FROM TABLE(
                            lineage_util.get_dep_cols_from_query(
                               in_parse_user => in_owner,
                               in_query      => l_query,
                               in_column_pos => l_column_id,
                               in_recursive  => in_recursive
                            )
                         ) p
               ) LOOP
                  t_col.extend;
                  t_col(t_col.count) := r_col.col;
               END LOOP column_dendencies;
         
            END IF;
         END IF;
      END IF;
      -- return the final dependencies 
      RETURN type_util.dedup(in_t_col => t_col);
   END get_dep_cols_from_view;

   --
   -- get_dep_cols_from_insert
   --
   FUNCTION get_dep_cols_from_insert(
      in_signature IN VARCHAR2,
      in_recursive IN INTEGER DEFAULT get_recursive()
   ) RETURN t_col_lineage_type IS
      l_query     CLOB;
      l_column_id INTEGER;
      l_prev_obj  VARCHAR2(512 CHAR) := '.';
      t_col       t_col_type := t_col_type();
      t_result    t_col_lineage_type := t_col_lineage_type();
      CURSOR c_insert IS
         SELECT full_text, owner
           FROM dba_statements
          WHERE signature = in_signature;
      r_insert c_insert%ROWTYPE;
   BEGIN
      OPEN c_insert;
      FETCH c_insert into r_insert;
      CLOSE c_insert;
      l_query := parse_util.get_insert_subquery(in_sql => r_insert.full_text);
      <<cols>>
      FOR r_col IN (
         SELECT owner, 
                object_type,
                object_name,
                column_name
           FROM TABLE(
                   get_target_cols_from_insert(
                      in_signature => in_signature
                   )
                ) 
      ) LOOP
         IF l_prev_obj != r_col.owner || '.' || r_col.object_type || '.' || r_col.object_name THEN
            l_column_id := 1;
            l_prev_obj := r_col.owner || '.' || r_col.object_type || '.' || r_col.object_name;
         ELSE
            l_column_id := l_column_id + 1;
         END IF;
         IF l_column_id IS NOT NULL THEN
            t_col.DELETE;
            <<column_dendencies>>
            FOR r_col2 IN (
               SELECT value(p) AS col
                 FROM TABLE(
                         lineage_util.get_dep_cols_from_query(
                            in_parse_user => r_insert.owner,
                            in_query      => l_query,
                            in_column_pos => l_column_id,
                            in_recursive  => in_recursive
                         )
                      ) p
            ) LOOP
               t_col.extend;
               t_col(t_col.count) := r_col2.col;
            END LOOP column_dendencies;
            IF t_col.count > 0 THEN
               <<populate_result>>
               FOR i IN 1 .. t_col.count LOOP
                  t_result.extend;
                  t_result(t_result.count) := col_lineage_type (
                                                 from_owner       => t_col(i).owner,
                                                 from_object_type => t_col(i).object_type,
                                                 from_object_name => t_col(i).object_name,
                                                 from_column_name => t_col(i).column_name,
                                                 to_owner         => r_col.owner,
                                                 to_object_type   => r_col.object_type,
                                                 to_object_name   => r_col.object_name,
                                                 to_column_name   => r_col.column_name
                                              );
               END LOOP populate_result;
            END IF;
         END IF;
      END LOOP cols;

      -- return the final dependencies 
      RETURN type_util.dedup(in_t_col_lineage => t_result);
   END get_dep_cols_from_insert;

   --
   -- get_target_cols_from_insert
   --
   FUNCTION get_target_cols_from_insert(
      in_signature IN VARCHAR2
   ) RETURN t_col_type IS
      l_prev_count INTEGER := 0;
      t_result     t_col_type := t_col_type();
      t_targets    t_obj_type;
      CURSOR c_stmt IS
         SELECT owner, object_type, object_name, type, usage_id, full_text
           FROM dba_statements
          WHERE signature = in_signature;
      r_stmt    c_stmt%ROWTYPE;
      CURSOR c_table IS
         SELECT t.owner,
                t.object_type,
                t.object_name,
                t.signature
           FROM dba_identifiers t
           JOIN TABLE(t_targets) o
             ON o.owner           = t.owner
                AND o.object_type = t.object_type
                AND o.object_name = t.object_name
                AND o.object_type = t.type
                AND 'DECLARATION' = t.usage;
      CURSOR c_col (
         p_owner       IN VARCHAR2, 
         p_object_type IN VARCHAR2, 
         p_object_name IN VARCHAR2
      ) IS
         SELECT col.name
           FROM dba_identifiers cu
           JOIN dba_identifiers col
             ON col.signature = cu.signature
                AND col.usage = 'DECLARATION'
          WHERE cu.owner            = r_stmt.owner
            AND cu.object_type      = r_stmt.object_type
            AND cu.object_name      = r_stmt.object_name
            AND cu.usage_context_id = r_stmt.usage_id
            AND cu.type             = 'COLUMN'
            AND col.owner           = p_owner
            AND col.object_type     = p_object_type
            AND col.object_name     = p_object_name;
      CURSOR c_all_col (
         p_owner       IN VARCHAR2,
         p_object_name IN VARCHAR2
      ) IS
         SELECT column_name
           FROM dba_tab_columns
          WHERE owner       = p_owner
            AND table_name  = p_object_name;
   BEGIN
      OPEN c_stmt;
      FETCH c_stmt INTO r_stmt;
      CLOSE c_stmt;
      IF r_stmt.type = 'INSERT' THEN
          t_targets := dd_util.get_objects(
                          in_parse_user => r_stmt.owner,
                          in_t_obj      => parse_util.get_insert_targets(
                                              in_parse_user => r_stmt.owner,
                                              in_sql        => r_stmt.full_text
                                           )
                       );
          <<targets>>
          FOR r_target IN c_table LOOP
             <<cols>>
             FOR r_col IN c_col (
                p_owner       => r_target.owner, 
                p_object_type => r_target.object_type, 
                p_object_name => r_target.object_name
             ) LOOP
                t_result.extend;
                t_result(t_result.count) := col_type (
                                               owner => r_target.owner,
                                               object_type => r_target.object_type,
                                               object_name => r_target.object_name,
                                               column_name => r_col.name
                                            );
             END LOOP cols;
             IF t_result.count = l_prev_count THEN
                -- no columns found, all-column wildcard expression
                <<all_cols>>
                FOR r_col IN c_all_col (
                   p_owner       => r_target.owner,
                   p_object_name => r_target.object_name
                ) LOOP
                   t_result.extend;
                   t_result(t_result.count) := col_type (
                                                  owner => r_target.owner,
                                                  object_type => r_target.object_type,
                                                  object_name => r_target.object_name,
                                                  column_name => r_col.column_name
                                               );
                  END LOOP all_cols;
             END IF;
             l_prev_count := t_result.count;
          END LOOP targets;
      END IF;
      RETURN t_result;
   END get_target_cols_from_insert;

END lineage_util;
/
