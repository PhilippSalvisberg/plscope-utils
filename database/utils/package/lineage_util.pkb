create or replace package body lineage_util is
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
   g_recursive integer default 1;

   --
   -- set_recursive
   --
   procedure set_recursive(in_recursive in integer) is
   begin
      if in_recursive = 0 then
         g_recursive := in_recursive;
      else
         g_recursive := 1; -- the default value anyway
      end if;
   end set_recursive;

   --
   -- get_recursive
   --
   function get_recursive return integer is
   begin
      return g_recursive;
   end get_recursive;
   
   --
   -- get_dep_cols_from_query
   --
   function get_dep_cols_from_query(
      in_parse_user in varchar2,
      in_query      in clob,
      in_column_pos in integer,
      in_recursive  in integer default 1
   ) return t_col_type is
      l_parse_tree sys.xmltype;
      l_dep_cols   sys.xmltype;
      o_obj        obj_type;
      t_col        t_col_type := t_col_type();
   begin
      -- parse query
      l_parse_tree := parse_util.parse_query(
                         in_parse_user => in_parse_user,
                         in_query      => in_query
                      );

      if l_parse_tree is not null then
         l_dep_cols := parse_util.get_dep_cols(
                          in_parse_tree => l_parse_tree,
                          in_column_pos => in_column_pos
                       );
         if l_dep_cols is not null then
            <<first_level_dependencies>>
            for r_dep in (
               select schema_name,
                      table_name,
                      column_name
                 from xmltable('/column'
                         passing l_dep_cols
                         columns schema_name varchar2(128 char) path 'schemaName',
                                 table_name  varchar2(128 char) path 'tableName',
                                 column_name varchar2(128 char) path 'columnName'
                      )
            )
            loop
               o_obj              := dd_util.resolve_synonym(
                                        in_parse_user => in_parse_user,
                                        in_obj        => obj_type(
                                                            owner       => r_dep.schema_name,
                                                            object_type => null,
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
               if in_recursive = 1 then
                  <<second_level_dependencies>>
                  for r_dep2 in ( -- NOSONAR: false positive of plsql:UseNativeSqlJoinsInsteadOfEmbeddedCursorLoopsCheck
                     select value(p) as col
                       from table(
                               lineage_util.get_dep_cols_from_view(
                                  in_owner       => o_obj.owner,
                                  in_object_name => o_obj.object_name,
                                  in_column_name => r_dep.column_name,
                                  in_recursive   => in_recursive
                               )
                            ) p
                  )
                  loop
                     t_col.extend;
                     t_col(t_col.count) := r_dep2.col;
                  end loop second_level_dependencies;
               end if;
            end loop first_level_dependencies;
         end if;
      end if;

      return type_util.dedup(in_t_col => t_col);
   end get_dep_cols_from_query;

   --
   -- get_dep_cols_from_view
   --
   function get_dep_cols_from_view(
      in_owner       in varchar2,
      in_object_name in varchar2,
      in_column_name in varchar2,
      in_recursive   in integer default 1
   ) return t_col_type is
      o_obj       obj_type;
      l_column_id integer;
      l_query     clob;
      t_col       t_col_type := t_col_type();
   begin
      -- resolve synonym into view
      o_obj := dd_util.resolve_synonym(
                  in_parse_user => in_owner,
                  in_obj        => obj_type(
                                      owner       => null,
                                      object_type => null,
                                      object_name => in_object_name
                                   )
               );

      if o_obj.object_type = 'VIEW' then
         l_column_id := dd_util.get_column_id(
                           in_owner       => o_obj.owner,
                           in_object_name => o_obj.object_name,
                           in_column_name => in_column_name
                        );
         if l_column_id is not null then
            l_query := dd_util.get_view_source(in_obj => o_obj);
            if l_query is not null then
               <<column_dendencies>>
               for r_col in (
                  select value(p) as col
                    from table(
                            lineage_util.get_dep_cols_from_query(
                               in_parse_user => in_owner,
                               in_query      => l_query,
                               in_column_pos => l_column_id,
                               in_recursive  => in_recursive
                            )
                         ) p
               )
               loop
                  t_col.extend;
                  t_col(t_col.count) := r_col.col;
               end loop column_dendencies;

            end if;
         end if;
      end if;
      -- return the final dependencies 
      return type_util.dedup(in_t_col => t_col);
   end get_dep_cols_from_view;

   --
   -- get_dep_cols_from_insert
   --
   function get_dep_cols_from_insert(
      in_signature in varchar2,
      in_recursive in integer default get_recursive()
   ) return t_col_lineage_type is
      l_query     clob;
      l_column_id integer;
      l_prev_obj  varchar2(512 char) := '.'; -- NOSONAR G-2130
      t_col       t_col_type         := t_col_type();
      t_result    t_col_lineage_type := t_col_lineage_type();
      cursor c_insert is
         select full_text, owner
           from sys.dba_statements -- NOSONAR: avoid public synonym
          where signature = in_signature;
      r_insert    c_insert%rowtype;
   begin
      open c_insert;
      fetch c_insert into r_insert;
      close c_insert;
      l_query := parse_util.get_insert_subquery(in_sql => r_insert.full_text);
      <<cols>>
      for r_col in (
         select owner,
                object_type,
                object_name,
                column_name
           from table(
                   get_target_cols_from_insert(
                      in_signature => in_signature
                   )
                )
      )
      loop
         if l_prev_obj != r_col.owner
            || '.'
            || r_col.object_type
            || '.'
            || r_col.object_name
         then
            l_column_id := 1;
            l_prev_obj  := r_col.owner
                           || '.'
                           || r_col.object_type
                           || '.'
                           || r_col.object_name;
         else
            l_column_id := l_column_id + 1;
         end if;
         if l_column_id is not null then
            t_col.delete;
            <<column_dendencies>>
            for r_col2 in ( -- NOSONAR: false positive of plsql:UseNativeSqlJoinsInsteadOfEmbeddedCursorLoopsCheck
               select value(p) as col
                 from table(
                         lineage_util.get_dep_cols_from_query(
                            in_parse_user => r_insert.owner,
                            in_query      => l_query,
                            in_column_pos => l_column_id,
                            in_recursive  => in_recursive
                         )
                      ) p
            )
            loop
               t_col.extend;
               t_col(t_col.count) := r_col2.col;
            end loop column_dendencies;
            if t_col.count > 0 then
               <<populate_result>>
               for i in 1..t_col.count -- NOSONAR: t_col is always dense
               loop
                  t_result.extend;
                  t_result(t_result.count) := col_lineage_type(
                                                 from_owner       => t_col(i).owner,
                                                 from_object_type => t_col(i).object_type,
                                                 from_object_name => t_col(i).object_name,
                                                 from_column_name => t_col(i).column_name,
                                                 to_owner         => r_col.owner,
                                                 to_object_type   => r_col.object_type,
                                                 to_object_name   => r_col.object_name,
                                                 to_column_name   => r_col.column_name
                                              );
               end loop populate_result;
            end if;
         end if;
      end loop cols;

      -- return the final dependencies 
      return type_util.dedup(in_t_col_lineage => t_result);
   end get_dep_cols_from_insert;

   --
   -- get_target_cols_from_insert
   --
   function get_target_cols_from_insert(
      in_signature in varchar2
   ) return t_col_type is
      l_prev_count integer    := 0;
      t_result     t_col_type := t_col_type();
      t_targets    t_obj_type;
      cursor c_stmt is
         select owner, object_type, object_name, type, usage_id, full_text
           from sys.dba_statements -- NOSONAR: avoid public synonym
          where signature = in_signature;
      r_stmt       c_stmt%rowtype;
      cursor c_table is
         select t.owner,
                t.object_type,
                t.object_name,
                t.signature
           from sys.dba_identifiers t -- NOSONAR: avoid public synonym
           join table(t_targets) o
             on o.owner = t.owner
            and o.object_type = t.object_type
            and o.object_name = t.object_name
            and o.object_type = t.type
            and 'DECLARATION' = t.usage;
      cursor c_col(
         p_owner       in varchar2,
         p_object_type in varchar2,
         p_object_name in varchar2
      ) is
         select col.name
           from sys.dba_identifiers cu  -- NOSONAR: avoid public synonym
           join sys.dba_identifiers col -- NOSONAR: avoid public synonym
             on col.signature = cu.signature
            and col.usage = 'DECLARATION'
          where cu.owner = r_stmt.owner
            and cu.object_type = r_stmt.object_type
            and cu.object_name = r_stmt.object_name
            and cu.usage_context_id = r_stmt.usage_id
            and cu.type = 'COLUMN'
            and col.owner = p_owner
            and col.object_type = p_object_type
            and col.object_name = p_object_name
          order by cu.line, cu.col;
      cursor c_all_col(
         p_owner       in varchar2,
         p_object_name in varchar2
      ) is
         select column_name
           from sys.dba_tab_columns -- NOSONAR: avoid public synonym
          where owner = p_owner
            and table_name = p_object_name;
   begin
      open c_stmt;
      fetch c_stmt into r_stmt;
      close c_stmt;
      if r_stmt.type = 'INSERT' then
         t_targets := dd_util.get_objects( -- NOSONAR: G-2135 false positive t_target used in c_stmt
                         in_parse_user => r_stmt.owner,
                         in_t_obj      => parse_util.get_insert_targets(
                                             in_parse_user => r_stmt.owner,
                                             in_sql        => r_stmt.full_text
                                          )
                      );
         <<targets>>
         for r_target in c_table
         loop
            <<cols>>
            for r_col in c_col( -- NOSONAR: false positive of plsql:UseNativeSqlJoinsInsteadOfEmbeddedCursorLoopsCheck
               p_owner       => r_target.owner,
               p_object_type => r_target.object_type,
               p_object_name => r_target.object_name
            )
            loop
               t_result.extend;
               t_result(t_result.count) := col_type(
                                              owner       => r_target.owner,
                                              object_type => r_target.object_type,
                                              object_name => r_target.object_name,
                                              column_name => r_col.name
                                           );
            end loop cols;
            if t_result.count = l_prev_count then
               -- no columns found, all-column wildcard expression
               <<all_cols>>
               for r_col in c_all_col( -- NOSONAR: false positive of plsql:UseNativeSqlJoinsInsteadOfEmbeddedCursorLoopsCheck
                  p_owner       => r_target.owner,
                  p_object_name => r_target.object_name
               )
               loop
                  t_result.extend;
                  t_result(t_result.count) := col_type(
                                                 owner       => r_target.owner,
                                                 object_type => r_target.object_type,
                                                 object_name => r_target.object_name,
                                                 column_name => r_col.column_name
                                              );
               end loop all_cols;
            end if;
            l_prev_count := t_result.count;
         end loop targets;
      end if;
      return t_result;
   end get_target_cols_from_insert;

end lineage_util;
/
